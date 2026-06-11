/**
 * develop-polaroid
 *
 * Triggered by: client POST after every shutter press.
 * Purpose: The canonical server-side scan path. Holds the Gemini
 *          API key as a Supabase secret so end users never have
 *          to bring their own.
 *
 * Single-provider pipeline (Gemini only — three steps):
 *
 *   1. IDENTIFY  (gemini-2.5-flash, text out)
 *      Look at the cropped sky photo, decide what the clouds
 *      suggest. Variety pressure from the user's recent shapes.
 *      Produces the watchability score that sets the ink budget.
 *
 *   2. DEVELOP   (gemini-2.5-flash-image, image out)
 *      Instruction-based edit: add delicate white ink tracing the
 *      identified shape, restraint scaled by watchability. Flash
 *      Image preserves the source photo's pixels far better than
 *      a full-regeneration model — important because the product
 *      promise is "your sky, with ink pointing out what's already
 *      there," not a repainted sky.
 *
 *   3. RE-CAPTION (gemini-2.5-flash, text out)
 *      Look at the FINISHED image and name what the ink actually
 *      traces (planned shape passed as a hint). The stored caption
 *      is therefore guaranteed to describe what's on the Polaroid,
 *      even if the edit deviated from the plan.
 *
 * Auth: required. Verifies the Supabase JWT on Authorization:
 *       Bearer <token>. Anonymous Supabase users work fine.
 *
 * Abuse protection: anonymous sign-ins make a valid JWT free to
 * obtain, and every request here costs real money (three Gemini
 * calls, one of them the image model). A per-user daily cap backed
 * by the `scan_log` table (migration 012) bounds the worst case;
 * the product quota (one free Polaroid per day) remains enforced
 * client-side and is intentionally LOWER than this cap so paying
 * subscribers never hit the server limit in normal use.
 *
 * Setup:
 *   1. Deploy: supabase functions deploy develop-polaroid
 *   2. Set secret:
 *        supabase secrets set GEMINI_API_KEY=<key>
 *   3. Enable Anonymous Sign-Ins in the Supabase Dashboard
 *      under Authentication → Providers → Anonymous.
 *   4. Run migration 012_scan_log.sql (rate-limit bookkeeping).
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
const TEXT_MODEL = "gemini-2.5-flash";
const IMAGE_MODEL = "gemini-2.5-flash-image";

// The well-behaved client sends a 1024×1024 JPEG at 0.88 quality —
// well under 1.5 MB of base64. Anything bigger is either a bug or
// someone amplifying our Gemini bill; reject before any AI call.
const MAX_IMAGE_BASE64_LENGTH = 2_000_000;

// Hard per-user daily ceiling, counted in `scan_log`. This is abuse
// protection, NOT the product quota — the free tier's one-per-day
// stays client-enforced, and subscribers capturing enthusiastically
// should never get near this number organically.
const MAX_SCANS_PER_USER_PER_DAY = 25;

// ---------- Prompts ---------------------------------------------------------

// Step 1 — identify. `recentShapes` is soft variety pressure so a
// user doesn't get "whale" four days in a row; never overrides what
// the sky actually shows.
function buildIdentifyPrompt(recentShapes: string[]): string {
  const varietySection = recentShapes.length
    ? `\n\nThe watcher's recent sightings were: ${recentShapes.join(", ")}. ` +
      `Prefer something DIFFERENT from these if the sky plausibly allows it — ` +
      `a fresh eye finds fresh shapes. But never force a bad fit: if the cloud ` +
      `really does look like a recent shape again, honesty wins.`
    : "";

  return `You are a cloud-watcher. Look at this sky photo and decide what creature or object the clouds suggest. Pick something concrete and a little playful — a whale, a sleeping dragon, a sailboat, a rabbit, a slice of cake. Range widely: animals, vehicles, food, mythical beasts, everyday objects. If nothing leaps out, "Soft cumulus" is the honest fallback.${varietySection}

Respond with ONLY valid JSON, no markdown:
{
  "shape_name": "short concrete phrase, max 6 words",
  "cloud_type": "Cumulus|Stratus|Cirrus|Cumulonimbus|Altocumulus|Stratocumulus",
  "weather_mood": "one word, evocative",
  "watchability_score": 1-10
}

Lower watchability_score for plain blue sky (1-3), middle for soft cumulus (4-7), high for clouds that clearly look like a recognizable creature (8-10).`;
}

// Step 2 — develop. Ink budget scales with watchability so a plain
// sky stays honest instead of getting a forced dragon.
function buildDevelopPrompt(shapeName: string, watchability: number): string {
  let restraint: string;
  if (watchability <= 3) {
    restraint = `This sky is sparse (watchability ${watchability}/10). Restraint is everything: ` +
      `add AT MOST one or two whisper-thin lines — or, if the clouds genuinely suggest ` +
      `nothing, add only a single small eye dot on the most cloud-like puff. ` +
      `An almost-empty sky with one knowing mark is the right outcome here.`;
  } else if (watchability <= 6) {
    restraint = `This sky is moderate (watchability ${watchability}/10). Use a light hand: ` +
      `3-6 delicate lines total. Suggest the shape; don't illustrate it.`;
  } else {
    restraint = `This sky clearly suggests the shape (watchability ${watchability}/10). ` +
      `You can be a touch more confident: up to 8-10 delicate lines, but every ` +
      `one must still follow a real cloud edge.`;
  }

  return `A cloud-watcher looked at this photo and saw: "${shapeName}".

Your job is to help everyone else see it too. Add minimal white ink line-art that TRACES the cloud edges that made the watcher see ${shapeName.toLowerCase()} — the bump that reads as its head, the curve that reads as its body. The clouds already contain the shape; your ink just points it out.

${restraint}

The viewer should look at the result and say "oh yes — I see it now", as if you helped them notice what was already there. Not "someone drew that on top."

Style:
   • Delicate single-weight white ink. Like a careful architectural pencil sketch in white.
   • No fills, no cross-hatching, no shading.
   • Every line follows a real cloud edge — never draw across open sky.
   • One eye dot placed on the cloud-bump that reads as the head (if the shape has a head).
   • ONLY ${shapeName.toLowerCase()} — do not add other creatures or shapes.
   • Keep the photo's clouds, sky, colors entirely intact. The ink is the only addition.

Return the photo with the ink overlay applied. Do not change anything else about the image.`;
}

// Step 3 — re-caption + quip from the finished image. The stored
// shape name must describe what's actually drawn, not what was
// planned; the quip ties that shape to the REAL weather at capture
// time, which is what makes each Polaroid feel like it was written
// for this exact moment.
function buildRecaptionPrompt(
  plannedShape: string,
  weatherSummary: string | null,
): string {
  const weatherSection = weatherSummary
    ? `\n\nCurrent weather at the watcher's location: ${weatherSummary}\n\n` +
      `Write a "quip": ONE playful sentence that ties the shape to this real weather. ` +
      `The creature lives in this sky, so the weather is happening TO it. Examples of ` +
      `the energy (don't copy): a dragon + incoming rain → "Better find shelter, ` +
      `dragon — rain rolls in within the hour." A whale + high heat → "Even the whale ` +
      `is looking for somewhere to cool off at 96°." A rabbit + strong wind → "Hold ` +
      `onto your ears — gusts at 25 mph this afternoon." Use the most interesting ` +
      `weather fact available (incoming rain beats temperature; a heat warning beats ` +
      `mild wind). Keep it under 20 words, warm and wry, never mean.`
    : `\n\nWrite a "quip": ONE playful sentence (under 20 words) about the shape ` +
      `drifting in today's sky. Warm and wry, never mean.`;

  return `This sky photo has delicate white ink line-art added by a cloud-watcher. The watcher intended to trace: "${plannedShape}".

Look at the FINAL image. What does the ink actually trace? Usually it matches the intent — confirm it. If the ink clearly reads as something else, name what it actually shows instead.${weatherSection}

Respond with ONLY valid JSON, no markdown:
{"shape_name": "short concrete phrase, max 6 words", "quip": "one sentence, max 20 words"}`;
}

// ---------- Types -----------------------------------------------------------

interface RequestBody {
  image_base64: string;
  city?: string;
  /// The user's most recent shape names (client supplies up to ~7,
  /// newest first). Used as variety pressure in the identify prompt.
  recent_shapes?: string[];
  /// Human-readable summary of the weather at capture time, built
  /// client-side from WeatherKit (e.g. "72°F, feels like 70°, wind
  /// 6 mph SW, rain expected in ~30 min"). Drives the quip — the
  /// one-liner tying the cloud shape to the actual conditions.
  weather_summary?: string;
}

interface GeminiAnalysis {
  shape_name: string;
  cloud_type: string;
  weather_mood: string;
  watchability_score: number;
}

// ---------- Entry point -----------------------------------------------------

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  // Fail fast on a misconfigured deploy — better a clear 500 here
  // than burning an auth round-trip before the pipeline throws.
  if (!GEMINI_API_KEY) {
    return json({ error: "Server not configured" }, 500);
  }

  // 1. Auth — extract the user's JWT and resolve their user_id.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Missing Bearer token" }, 401);
  }
  const token = authHeader.slice(7);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: userResp, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userResp?.user) {
    return json({ error: "Invalid auth token" }, 401);
  }
  const userId = userResp.user.id;

  // 2. Parse body.
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!body.image_base64) {
    return json({ error: "Missing image_base64" }, 400);
  }
  if (body.image_base64.length > MAX_IMAGE_BASE64_LENGTH) {
    return json({ error: "Image too large" }, 413);
  }
  // The client always sends JPEG; "/9j/" is base64 for the JPEG
  // SOI marker (0xFFD8FF). Catches garbage payloads before they
  // burn an upstream call.
  if (!body.image_base64.startsWith("/9j/")) {
    return json({ error: "image_base64 must be a JPEG" }, 400);
  }

  // 3. Rate limit — count this user's scans in the trailing 24h and
  //    record the new attempt BEFORE the AI pipeline runs, so failed
  //    pipelines still count against an abuser hammering the proxy.
  const since24h = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count: recentScans, error: countErr } = await supabase
    .from("scan_log")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gt("created_at", since24h);
  if (countErr) {
    console.error("scan_log count failed", countErr);
    // Fail open: a bookkeeping outage shouldn't take scanning down.
  } else if ((recentScans ?? 0) >= MAX_SCANS_PER_USER_PER_DAY) {
    return json({ error: "Daily scan limit reached. Try again tomorrow." }, 429);
  }
  const { error: logErr } = await supabase
    .from("scan_log")
    .insert({ user_id: userId });
  if (logErr) console.error("scan_log insert failed", logErr);

  // 4. Ensure a profiles row exists. Anonymous users have none (no
  //    handle_new_user trigger fires for them), and without a row
  //    the client's device-token / reminder-pref updates match zero
  //    rows — silently breaking daily reminders. ignoreDuplicates
  //    keeps an existing row (and its chosen username) untouched.
  const { error: profileErr } = await supabase
    .from("profiles")
    .upsert(
      { id: userId, username: `watcher-${userId.slice(0, 8)}` },
      { onConflict: "id", ignoreDuplicates: true },
    );
  if (profileErr) console.error("profiles upsert failed", profileErr);

  const recentShapes = (body.recent_shapes ?? [])
    .filter((s): s is string => typeof s === "string" && s.length > 0)
    .slice(0, 7)
    .map((s) => s.slice(0, 60));

  // 5. The three-step pipeline. Steps are sequential by design:
  //    identify sets the develop instructions; re-caption needs the
  //    developed image. ~1s per text step, the image step dominates.
  const weatherSummary =
    typeof body.weather_summary === "string" && body.weather_summary.length > 0
      ? body.weather_summary.slice(0, 300)
      : null;

  let analysis: GeminiAnalysis;
  let developedPng: string;
  let finalShapeName: string;
  let quip: string;
  try {
    analysis = await identify(body.image_base64, recentShapes);
    developedPng = await develop(
      body.image_base64,
      analysis.shape_name,
      analysis.watchability_score,
    );
    ({ shapeName: finalShapeName, quip } = await recaption(
      developedPng,
      analysis.shape_name,
      weatherSummary,
    ));
  } catch (e) {
    console.error("AI pipeline failed", e);
    const message = e instanceof Error ? e.message : String(e);
    return json({ error: message }, 502);
  }

  // 6. Insert sighting_metadata. Uses the FINAL shape name — the
  //    aggregation should reflect what users actually saw on their
  //    Polaroids. Best-effort (the user already paid the AI cost,
  //    so a bookkeeping failure must not fail the response), but it
  //    MUST be awaited: supabase-js builders are lazy thenables, so
  //    a `void`-dropped insert never sends the request at all.
  const captureTs = new Date().toISOString();
  const cityTrimmed = body.city?.trim().slice(0, 60) || null;
  const { error: metaErr } = await supabase.from("sighting_metadata").insert({
    user_id: userId,
    shape_name: finalShapeName.slice(0, 80),
    city: cityTrimmed,
    captured_at: captureTs,
  });
  if (metaErr) console.error("sighting_metadata insert failed", metaErr);

  // 7. Update profiles.city so the daily-reminders aggregation has
  //    a current region to summarize for this user.
  if (cityTrimmed) {
    const { error: cityErr } = await supabase
      .from("profiles")
      .update({ city: cityTrimmed })
      .eq("id", userId);
    if (cityErr) console.error("profiles.city update failed", cityErr);
  }

  // 8. Respond. cloud_type / weather_mood / watchability describe
  //    the SKY (unchanged by the ink), so they come from step 1;
  //    only the shape name is re-derived from the finished image.
  return json({
    shape_name: finalShapeName,
    quip,
    cloud_type: analysis.cloud_type,
    weather_mood: analysis.weather_mood,
    watchability_score: analysis.watchability_score,
    developed_image_base64: developedPng,
  });
});

// ---------- Pipeline steps --------------------------------------------------

async function identify(
  imageBase64: string,
  recentShapes: string[],
): Promise<GeminiAnalysis> {
  const text = await geminiText({
    imageBase64,
    imageMime: "image/jpeg",
    prompt: buildIdentifyPrompt(recentShapes),
    maxTokens: 500,
  });
  // The prompt's own fallback for an unreadable sky. Also our
  // fallback when the model ignores responseMimeType and returns
  // prose — a degraded-but-honest Polaroid beats a failed scan.
  const fallback: GeminiAnalysis = {
    shape_name: "Soft cumulus",
    cloud_type: "Cumulus",
    weather_mood: "calm",
    watchability_score: 3,
  };
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(stripCodeFences(text));
  } catch {
    console.warn("Identify response was not valid JSON; using fallback");
    return fallback;
  }
  const shapeName = String(parsed.shape_name ?? "").trim();
  const cloudType = String(parsed.cloud_type ?? "").trim();
  if (!shapeName || !cloudType) {
    console.warn("Identify response missing required fields; using fallback");
    return fallback;
  }
  // The model occasionally emits the score as a string, a float, or
  // out of range; the develop prompt and the client's Int decode
  // both need a clean 1–10 integer.
  const rawScore = Number(parsed.watchability_score);
  const watchability = Number.isFinite(rawScore)
    ? Math.min(10, Math.max(1, Math.round(rawScore)))
    : 5;
  return {
    shape_name: shapeName.slice(0, 80),
    cloud_type: cloudType.slice(0, 40),
    weather_mood: String(parsed.weather_mood ?? "").trim().slice(0, 40) || "calm",
    watchability_score: watchability,
  };
}

async function develop(
  imageBase64: string,
  shapeName: string,
  watchability: number,
): Promise<string> {
  if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY not configured");

  const url = `${GEMINI_BASE}/${IMAGE_MODEL}:generateContent`;
  const body = {
    contents: [{
      parts: [
        { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
        { text: buildDevelopPrompt(shapeName, watchability) },
      ],
    }],
    generationConfig: {
      responseModalities: ["IMAGE"],
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API_KEY,
    },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Gemini image edit ${resp.status}: ${text.slice(0, 200)}`);
  }
  const data = await resp.json();
  // The image arrives as an inlineData part. There may also be text
  // parts; scan for the first image.
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    const inline = part?.inlineData;
    if (inline?.data && String(inline?.mimeType ?? "").startsWith("image/")) {
      return inline.data as string;
    }
  }
  throw new Error("Gemini image edit returned no image");
}

async function recaption(
  developedImageBase64: string,
  plannedShape: string,
  weatherSummary: string | null,
): Promise<{ shapeName: string; quip: string }> {
  try {
    const text = await geminiText({
      imageBase64: developedImageBase64,
      imageMime: "image/png",
      prompt: buildRecaptionPrompt(plannedShape, weatherSummary),
      maxTokens: 200,
      // Hotter than the identify pass: quips benefit from spice;
      // the shape confirmation is robust to it (it's mostly an echo).
      temperature: 0.9,
    });
    const parsed = JSON.parse(stripCodeFences(text));
    const name = String(parsed?.shape_name ?? "").trim();
    const quip = String(parsed?.quip ?? "").trim().slice(0, 200);
    return { shapeName: name || plannedShape, quip };
  } catch (e) {
    // Re-caption is a truthfulness upgrade, not a hard dependency —
    // if it fails, the planned shape is still a good caption and
    // the client falls back to its on-device quip generator.
    console.warn("Recaption failed; falling back to planned shape", e);
    return { shapeName: plannedShape, quip: "" };
  }
}

// ---------- Gemini helpers --------------------------------------------------

async function geminiText({ imageBase64, imageMime, prompt, maxTokens, temperature = 0.5 }: {
  imageBase64: string;
  imageMime: string;
  prompt: string;
  maxTokens: number;
  temperature?: number;
}): Promise<string> {
  if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY not configured");

  const url = `${GEMINI_BASE}/${TEXT_MODEL}:generateContent`;
  const body = {
    contents: [{
      parts: [
        { inlineData: { mimeType: imageMime, data: imageBase64 } },
        { text: prompt },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      temperature,
      maxOutputTokens: maxTokens,
    },
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": GEMINI_API_KEY,
    },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`Gemini ${resp.status}: ${text.slice(0, 200)}`);
  }
  const data = await resp.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini returned no text");
  return text;
}

// ---------- Small helpers ---------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Gemini sometimes wraps JSON in ```json fences; strip them. */
function stripCodeFences(s: string): string {
  const t = s.trim();
  if (t.startsWith("```")) {
    const lines = t.split("\n");
    lines.shift();
    if (lines[lines.length - 1]?.startsWith("```")) lines.pop();
    return lines.join("\n").trim();
  }
  return t;
}
