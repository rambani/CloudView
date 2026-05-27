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
 *        supabase secrets set APNS_BUNDLE_ID=com.cloudview.app
 *        supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
 *   3. Create Database Webhook in Supabase Dashboard:
 *        Table: sightings  |  Event: INSERT  |  URL: <your function URL>
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const APNS_ENDPOINT = "https://api.push.apple.com";  // use api.sandbox.push.apple.com for dev

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

  // Send one APNs request per user
  const sends = nearbyUsers.map((user: { username: string; device_token: string }) =>
    sendApnsNotification({
      deviceToken: user.device_token,
      apnsToken,
      title: `Look up, ${user.username.split(" ")[0]}`,
      body: `'${sighting.shape_name}' spotted near ${city} just now`,
      data: { sighting_id: sighting.id, latitude: sighting.latitude, longitude: sighting.longitude },
    })
  );

  await Promise.allSettled(sends);
  return new Response("Notifications sent", { status: 200 });
});

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
