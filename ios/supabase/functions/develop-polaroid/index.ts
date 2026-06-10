/**
 * develop-polaroid
 *
 * Triggered by: client POST after every shutter press.
 * Purpose: The canonical server-side replacement for the
 *          previously client-side direct calls to Gemini and
 *          OpenAI's image-edit. Holds both API keys as Supabase
 *          secrets so end users never have to bring their own.
 *
 * Auth: required. The function verifies the Supabase JWT on
 *       Authorization: Bearer <token>. Anonymous Supabase users
 *       (signInAnonymously) work fine here — they have a stable
 *       user_id we can attribute metadata to.
 *
 * Flow:
 *   1. Verify JWT, extract user_id.
 *   2. In parallel: Gemini analyzes the cropped image for shape
 *      metadata; OpenAI gpt-image-1 returns a developed PNG
 *      with delicate white ink lines tracing the shape.
 *   3. Insert sighting_metadata for the user.
 *   4. Update profiles.city if a city was sent.
 *   5. Return { shape_name, cloud_type, weather_mood,
 *      watchability_score, developed_image_base64 }.
 *
 * Setup:
 *   1. Deploy: supabase functions deploy develop-polaroid
 *   2. Set secrets:
 *        supabase secrets set GEMINI_API_KEY=<key>
 *        supabase secrets set OPENAI_API_KEY=sk-...
 *   3. Enable Anonymous Sign-Ins in the Supabase Dashboard
 *      under Authentication → Providers → Anonymous (so the
 *      client doesn't have to force users through an account
 *      flow to make a single Polaroid).
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const GEMINI_MODEL = "gemini-2.5-flash";
const OPENAI_MODEL = "gpt-image-1";

// ---------- Prompts ---------------------------------------------------------

// Slimmer than the previous client-side Gemini prompt — we ask
// only for the four scalar fields the Polaroid actually uses.
// The stroke geometry the old prompt asked for is gone; OpenAI's
// image-edit handles the drawing entirely.
const GEMINI_PROMPT = `You are a cloud-watcher. Look at this sky photo and decide what creature or object the clouds suggest. Pick something concrete and a little playful — a whale, a sleeping dragon, a sailboat, a rabbit, a slice of cake. If nothing leaps out, "Soft cumulus" is the honest fallback.

Respond with ONLY valid JSON, no markdown:
{
  "shape_name": "short concrete phrase, max 6 words",
  "cloud_type": "Cumulus|Stratus|Cirrus|Cumulonimbus|Altocumulus|Stratocumulus",
  "weather_mood": "one word, evocative",
  "watchability_score": 1-10
}

Lower watchability_score for plain blue sky (1-3), middle for soft cumulus (4-7), high for clouds that clearly look like a recognizable creature (8-10).`;

// Same OpenAI prompt as the previous client-side ImageGenerationService.
const OPENAI_PROMPT = `Look at this cloud photo carefully. Find shapes the clouds ALREADY suggest on their own — a bump that already reads as a head, a curve that already reads as a wing, a vertical lobe that already reads as a castle turret. Not what you'd like to draw on them, but what the cloud forms genuinely look like.

Add minimal white ink line-art that TRACES those existing patterns. Every line follows a real cloud edge. An eye dot lives on a cloud-bump that already looks like a head. A wing line runs along a cloud-edge that already has a wing-curve. A tail follows an existing cloud wisp.

The viewer should look at the result and say "oh yes — I see it now", as if you helped them notice what was already there. Not "someone drew that on top."

Style:
   • Delicate single-weight white ink. Like a careful architectural pencil sketch in white.
   • No fills, no cross-hatching, no shading.
   • Use as FEW lines as possible. Less is more.
   • Keep the photo's clouds, sky, colors entirely intact. The ink is the only addition.
   • Pick 1-3 creatures or structures, no more. A cluttered sky kills the illusion.

Return the photo with the ink overlay applied. Do not change anything else about the image.`;

// ---------- Types -----------------------------------------------------------

interface RequestBody {
  image_base64: string;
  city?: string;
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

  // 3. Parallel: Gemini analyze + OpenAI develop.
  let gemini: GeminiAnalysis;
  let developedPng: string;
  try {
    [gemini, developedPng] = await Promise.all([
      callGemini(body.image_base64),
      callOpenAI(body.image_base64),
    ]);
  } catch (e) {
    console.error("AI call failed", e);
    const message = e instanceof Error ? e.message : String(e);
    return json({ error: message }, 502);
  }

  // 4. Insert sighting_metadata (fire-and-forget — the AI work is
  //    the user-visible bit; analytics rows aren't worth blocking
  //    the response if the insert errors out).
  const captureTs = new Date().toISOString();
  const cityTrimmed = body.city?.trim().slice(0, 60) || null;
  void supabase.from("sighting_metadata").insert({
    user_id: userId,
    shape_name: gemini.shape_name.slice(0, 80),
    city: cityTrimmed,
    captured_at: captureTs,
  });

  // 5. Update profiles.city so the daily-reminders aggregation has
  //    a current region to summarize for this user.
  if (cityTrimmed) {
    void supabase
      .from("profiles")
      .update({ city: cityTrimmed })
      .eq("id", userId);
  }

  // 6. Respond.
  return json({
    shape_name: gemini.shape_name,
    cloud_type: gemini.cloud_type,
    weather_mood: gemini.weather_mood,
    watchability_score: gemini.watchability_score,
    developed_image_base64: developedPng,
  });
});

// ---------- AI helpers ------------------------------------------------------

async function callGemini(imageBase64: string): Promise<GeminiAnalysis> {
  if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY not configured");

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
  const body = {
    contents: [{
      parts: [
        { inlineData: { mimeType: "image/jpeg", data: imageBase64 } },
        { text: GEMINI_PROMPT },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0.5,
      maxOutputTokens: 500,
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
  const json = await resp.json();
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini returned no text");

  const parsed = JSON.parse(stripCodeFences(text));
  if (!parsed.shape_name || !parsed.cloud_type) {
    throw new Error("Gemini response missing required fields");
  }
  return parsed as GeminiAnalysis;
}

async function callOpenAI(imageBase64: string): Promise<string> {
  if (!OPENAI_API_KEY) throw new Error("OPENAI_API_KEY not configured");

  // OpenAI's images/edits endpoint wants multipart/form-data with
  // a PNG file. We accept JPEG from the client (smaller upload)
  // but OpenAI's PNG-only requirement means we need to send bytes
  // with the .png extension and image/png mime. gpt-image-1 is
  // lenient about the actual encoding — what matters is that the
  // model receives raw bytes it can process.
  const imageBytes = Uint8Array.from(atob(imageBase64), (c) => c.charCodeAt(0));

  const form = new FormData();
  form.append("model", OPENAI_MODEL);
  form.append("prompt", OPENAI_PROMPT);
  form.append("n", "1");
  form.append("size", "1024x1024");
  form.append("input_fidelity", "high");
  form.append(
    "image",
    new Blob([imageBytes], { type: "image/png" }),
    "cloud.png",
  );

  const resp = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_API_KEY}` },
    body: form,
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`OpenAI ${resp.status}: ${text.slice(0, 200)}`);
  }
  const json = await resp.json();
  const b64 = json?.data?.[0]?.b64_json;
  if (!b64) throw new Error("OpenAI returned no image");
  return b64;
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
