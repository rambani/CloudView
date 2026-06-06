/**
 * notify-nearby-users
 *
 * Triggered by: INSERT on public.sightings (via Supabase Database Webhook)
 * Purpose: When someone posts a cloud sighting, notify users nearby who have
 *          notifications enabled, telling them what was spotted and where.
 *
 * Setup:
 *   1. Deploy: supabase functions deploy notify-nearby-users
 *   2. Set secrets:
 *        supabase secrets set APNS_KEY_ID=<10-char key ID>
 *        supabase secrets set APNS_TEAM_ID=<10-char team ID>
 *        supabase secrets set APNS_BUNDLE_ID=com.cloudoodle.app
 *        supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
 *   3. Create Database Webhook in Supabase Dashboard:
 *        Table: sightings  |  Event: INSERT  |  URL: <your function URL>
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// Pick the APNs endpoint that matches the build's aps-environment
// entitlement. Debug builds + Simulator + early TestFlight runs use
// development (sandbox) tokens; sending those to the production
// endpoint returns BadDeviceToken from Apple, which then poisons the
// per-token records and silently drops the notification.
//
// Set APNS_ENVIRONMENT=development in Supabase secrets while shooting
// for sandbox tokens; leave it unset (or =production) for App Store
// and most TestFlight builds. Default is production to keep
// real-user-facing pushes working if the secret is missing.
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT")?.toLowerCase() ?? "production";
const APNS_ENDPOINT = (APNS_ENVIRONMENT === "development" || APNS_ENVIRONMENT === "sandbox")
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

interface SightingPayload {
  id: string;
  user_id: string;
  shape_name: string;
  city: string | null;
  latitude: number | null;
  longitude: number | null;
}

interface WebhookBody {
  type: "INSERT";
  record: SightingPayload;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const body: WebhookBody = await req.json();
  const sighting = body.record;

  if (!sighting.latitude || !sighting.longitude) {
    return new Response("No location — skipping", { status: 200 });
  }

  // Don't fan out push notifications for content that doesn't pass a
  // basic objectionable-content screen. App Review specifically checks
  // that UGC apps filter abusive material before broadcasting it. The
  // database row still exists (so the in-app feed renders it for
  // viewers, where the report/block flow can do the rest), but no
  // off-device push will carry the offending text.
  if (isObjectionable(sighting.shape_name) || isObjectionable(sighting.city ?? "")) {
    console.warn("Skipping push fan-out for filtered content", {
      sighting_id: sighting.id,
    });
    return new Response("Filtered", { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Find nearby users (excluding the poster) with notifications enabled and a device token
  const { data: nearbyUsers } = await supabase.rpc("profiles_within_radius", {
    lat: sighting.latitude,
    lon: sighting.longitude,
    radius_km: 80,               // notify users within 80km
  }).neq("id", sighting.user_id)
    .eq("notifications_enabled", true)
    .not("device_token", "is", null)
    .select("id, username, device_token");

  if (!nearbyUsers?.length) return new Response("No nearby users", { status: 200 });

  const apnsToken = await buildApnsJwt();
  const city = sighting.city ?? "your area";

  // Send one APNs request per user. Pick a random title + body
  // template so users seeing multiple pushes in a week don't see the
  // same phrasing every time. Variants are deterministic per sighting
  // (seeded by id hash) so the same sighting reads identically to
  // everyone who gets the push.
  const sends = nearbyUsers.map((user: { username: string; device_token: string }) => {
    const variant = pickVariant(sighting.id, sighting.shape_name, city, user.username.split(" ")[0]);
    return sendApnsNotification({
      deviceToken: user.device_token,
      apnsToken,
      title: variant.title,
      body: variant.body,
      data: { sighting_id: sighting.id, latitude: sighting.latitude, longitude: sighting.longitude },
    });
  });

  await Promise.allSettled(sends);
  return new Response("Notifications sent", { status: 200 });
});

// MARK: - Push copy variants

interface PushVariant { title: string; body: string }

/**
 * Build a randomized title + body for a sighting push. Selection is
 * deterministic per sighting (FNV-1a hash of the id) so all recipients
 * of the same push see identical phrasing — important so two users
 * comparing screenshots don't think their copies came from different
 * apps. Rotation gives the in-product feel some variety without
 * shipping a build for each new template.
 */
function pickVariant(
  sightingId: string,
  shapeName: string,
  city: string,
  firstName: string,
): PushVariant {
  const variants: PushVariant[] = [
    { title: `Look up, ${firstName}`,
      body: `'${shapeName}' spotted near ${city} just now` },
    { title: `Something in the sky over ${city}`,
      body: `Someone just found a ${shapeName.toLowerCase()} overhead — yours might still be drifting` },
    { title: `Skies over ${city} are putting on a show`,
      body: `A ${shapeName.toLowerCase()} just floated by. Worth a look up.` },
    { title: `Heads up, ${firstName}`,
      body: `A ${shapeName.toLowerCase()} is overhead near you right now` },
  ];
  const idx = fnv1a(sightingId) % variants.length;
  return variants[idx];
}

/**
 * Tiny non-cryptographic hash. We only need a stable integer modulo
 * variant count; reaching for crypto.subtle here would be overkill.
 */
function fnv1a(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
  }
  return h;
}

// MARK: - APNs helpers

async function buildApnsJwt(): Promise<string> {
  const keyId   = Deno.env.get("APNS_KEY_ID")!;
  const teamId  = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey  = Deno.env.get("APNS_PRIVATE_KEY")!;

  const pemBody = rawKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"],
  );

  return create(
    { alg: "ES256", kid: keyId },
    { iss: teamId, iat: getNumericDate(0) },
    cryptoKey,
  );
}

async function sendApnsNotification({
  deviceToken, apnsToken, title, body, data,
}: {
  deviceToken: string;
  apnsToken: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
}) {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      "interruption-level": "active",
    },
    ...data,
  };

  return fetch(`${APNS_ENDPOINT}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${apnsToken}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

// MARK: - Content moderation
//
// Tiny built-in keyword filter so we have *something* before integrating
// a real moderation API. Catches the obvious classes — sexual content,
// slurs, gore — but is intentionally conservative; the goal is to keep
// the worst stuff out of the push fan-out, not to be a comprehensive
// moderation system. The in-app feed shows the row regardless; report
// + block do the rest.
//
// Replace this with an OpenAI Moderation API call (or Perspective API,
// or similar) once you have the keys. See TASKS.md item 10.

const DENY_WORDS = new Set([
  // Sexual / explicit
  "porn", "sex", "nude", "naked", "xxx", "nsfw",
  // Slurs and hate (minimal seed list — extend as needed)
  "nigger", "faggot", "retard", "kike", "spic", "chink",
  // Self-harm / violence
  "kill", "murder", "suicide", "rape", "rapist",
  // Substances
  "cocaine", "heroin", "meth",
]);

function isObjectionable(text: string): boolean {
  if (!text) return false;
  const normalised = text
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!normalised) return false;
  for (const word of normalised.split(" ")) {
    if (DENY_WORDS.has(word)) return true;
  }
  return false;
}
