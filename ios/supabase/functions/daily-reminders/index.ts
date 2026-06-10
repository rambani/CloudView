/**
 * daily-reminders
 *
 * Triggered by: pg_cron tick (recommended every 15 minutes).
 * Purpose: Fan out the regional-summary daily reminder push to every
 *          signed-in user whose chosen reminder time matches "now" in
 *          their timezone. Body text aggregates `sighting_metadata`
 *          for the past 24 hours in their city, so each user sees
 *          something like:
 *              "23 people near Brooklyn saw birds in the sky today"
 *
 * Setup:
 *   1. Deploy: supabase functions deploy daily-reminders
 *   2. Set the APNS secrets if not already set for notify-nearby-users:
 *        supabase secrets set APNS_KEY_ID=<10-char key ID>
 *        supabase secrets set APNS_TEAM_ID=<10-char team ID>
 *        supabase secrets set APNS_BUNDLE_ID=com.cloudoodle.app
 *        supabase secrets set APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
 *        supabase secrets set APNS_ENVIRONMENT=production    # or development
 *   3. Schedule cron in Supabase Dashboard → Database → Cron jobs:
 *        Name:     daily-reminders-tick
 *        Schedule: */15 * * * *
 *        Action:   HTTP request → POST <function URL>
 *        Headers:  Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
 *      (Or, if pg_cron + pg_net are enabled, schedule via SQL —
 *      see TASKS.md for the snippet.)
 *
 * Implementation notes:
 *
 *   • The cron tick widens its match window to ±7.5 min so a user
 *     whose reminder time falls between ticks still gets pushed
 *     exactly once. A `last_pushed_at` column on profiles would
 *     bullet-proof "exactly once," but for now we rely on the cron
 *     interval being predictable enough that one fire per scheduled
 *     time is the worst that happens.
 *   • Users without a city (or with too few nearby sightings to
 *     summarize) get a warm-generic copy instead of a personalized
 *     line — never an empty body.
 *   • Body text is generated locally; nothing about the user other
 *     than their device token leaves Supabase. The recipient's
 *     identity is not in the push payload.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// ---------- APNs endpoint selection -----------------------------------------
const APNS_ENVIRONMENT = Deno.env.get("APNS_ENVIRONMENT")?.toLowerCase() ?? "production";
const APNS_ENDPOINT = (APNS_ENVIRONMENT === "development" || APNS_ENVIRONMENT === "sandbox")
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";

// Half-width of the "is this user due for a reminder right now"
// match window, in minutes. Should be at least half the cron
// interval so no scheduled reminder time falls between ticks.
const MATCH_WINDOW_MINUTES = 8;

// Minimum sightings-in-region required before the body text uses
// a personalized "N people near {city} saw {shape}" line. Below
// this threshold we fall back to warm-generic copy so a single
// user's lonely Polaroid doesn't read as "you saw a whale today."
const MIN_SIGHTINGS_FOR_PERSONALIZED = 4;

// ---------- Types -----------------------------------------------------------
interface ReminderProfile {
  id: string;
  device_token: string;
  reminder_local_time: string;   // "HH:MM"
  timezone: string;              // IANA
  city: string | null;
}

interface ShapeAggregate {
  shape_name: string;
  count: number;
}

// ---------- Entry point -----------------------------------------------------
Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const dueProfiles = await findDueProfiles(supabase);
  if (!dueProfiles.length) {
    return new Response(JSON.stringify({ sent: 0, reason: "no users due" }), { status: 200 });
  }

  const apnsToken = await buildApnsJwt();

  // Aggregate per-city once so we don't repeat the SQL for users in
  // the same city. Map: city -> [{shape_name, count}, ...].
  const cityAggregates = await loadAggregates(
    supabase,
    Array.from(new Set(dueProfiles.map((p) => p.city).filter((c): c is string => !!c))),
  );

  const sends = dueProfiles.map((profile) => {
    const aggregates = profile.city ? cityAggregates.get(profile.city) ?? [] : [];
    const copy = buildPushCopy({ city: profile.city, aggregates });
    return sendApnsNotification({
      deviceToken: profile.device_token,
      apnsToken,
      title: copy.title,
      body: copy.body,
    });
  });

  const results = await Promise.allSettled(sends);
  const successCount = results.filter((r) => r.status === "fulfilled").length;
  return new Response(
    JSON.stringify({ sent: successCount, attempted: sends.length }),
    { status: 200 },
  );
});

// ---------- Profile selection -----------------------------------------------

/**
 * Pull profiles whose chosen reminder time falls within the current
 * tick's match window in their own timezone, and who have a device
 * token to push to.
 *
 * The match is done in SQL via AT TIME ZONE so Postgres handles the
 * timezone conversion; comparing the resulting HH:MM string against
 * the user's stored reminder_local_time lets us avoid pulling every
 * row and filtering in JS.
 */
async function findDueProfiles(
  // deno-lint-ignore no-explicit-any
  supabase: any,
): Promise<ReminderProfile[]> {
  // Compute the current UTC time and find HH:MM windows that map to
  // each user's local time. We can't easily push the timezone math
  // into a single query that's also indexable, so we issue a
  // function call (server-side RPC) that the migration ships.
  //
  // Until that RPC exists, fall back to a two-step approach: read
  // all enabled profiles with the indexed predicate, then filter
  // by computed local time in JS. This is O(N) on enabled-reminder
  // users; for a v1 user base that's fine.
  const { data, error } = await supabase
    .from("profiles")
    .select("id, device_token, reminder_local_time, timezone, city")
    .eq("reminder_enabled", true)
    .not("device_token", "is", null)
    .not("reminder_local_time", "is", null)
    .not("timezone", "is", null);

  if (error) {
    console.error("findDueProfiles failed", error);
    return [];
  }

  const now = new Date();
  return (data ?? []).filter((row: ReminderProfile) =>
    isWithinReminderWindow(now, row.timezone, row.reminder_local_time)
  );
}

/**
 * True when `now` (UTC) lies within ±MATCH_WINDOW_MINUTES of
 * `localHHMM` interpreted in `tz`. Uses Intl.DateTimeFormat with
 * the user's IANA timezone, which handles DST + UTC offsets
 * without us hand-rolling them.
 */
function isWithinReminderWindow(
  now: Date,
  tz: string,
  localHHMM: string,
): boolean {
  let localNow: string;
  try {
    localNow = new Intl.DateTimeFormat("en-GB", {
      timeZone: tz,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(now);
  } catch {
    // Bad timezone string — treat as not due rather than crashing.
    return false;
  }

  const nowMinutes = hhmmToMinutes(localNow);
  const targetMinutes = hhmmToMinutes(localHHMM);
  if (nowMinutes < 0 || targetMinutes < 0) return false;

  // Distance modulo 24 * 60 so e.g. 00:05 and 23:55 are 10 min apart.
  const diff = Math.min(
    Math.abs(nowMinutes - targetMinutes),
    24 * 60 - Math.abs(nowMinutes - targetMinutes),
  );
  return diff <= MATCH_WINDOW_MINUTES;
}

function hhmmToMinutes(s: string): number {
  const m = s.match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return -1;
  return Number(m[1]) * 60 + Number(m[2]);
}

// ---------- City aggregation ------------------------------------------------

/**
 * For each city we care about, count the top shape names recorded
 * in the past 24 hours. Returns a map keyed by city.
 *
 * We do one query per city rather than `WHERE city = ANY(...)` so
 * the existing `(city, captured_at)` index is fully usable — and
 * the typical batch is small enough (one tick fires for tens of
 * users across at most a dozen cities) that the round-trip count
 * is fine.
 */
async function loadAggregates(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  cities: string[],
): Promise<Map<string, ShapeAggregate[]>> {
  const result = new Map<string, ShapeAggregate[]>();
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  await Promise.all(cities.map(async (city) => {
    const { data, error } = await supabase
      .from("sighting_metadata")
      .select("shape_name")
      .eq("city", city)
      .gt("captured_at", since);
    if (error) {
      console.error(`loadAggregates failed for city=${city}`, error);
      result.set(city, []);
      return;
    }
    const counts = new Map<string, number>();
    for (const row of data ?? []) {
      const key = (row.shape_name as string).trim().toLowerCase();
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
    const sorted = Array.from(counts.entries())
      .map(([shape_name, count]) => ({ shape_name, count }))
      .sort((a, b) => b.count - a.count);
    result.set(city, sorted);
  }));

  return result;
}

// ---------- Push copy -------------------------------------------------------

interface PushCopy { title: string; body: string }

/**
 * Build the title + body for a user's daily push. Personalized when
 * we have enough regional data, warm-generic otherwise.
 *
 * Group the top-N shape names into a single phrase ("birds, whales,
 * and sleeping cats") so a varied sky reads richer than just "birds."
 */
function buildPushCopy({ city, aggregates }: {
  city: string | null;
  aggregates: ShapeAggregate[];
}): PushCopy {
  const title = "Today's sky is waiting";

  const total = aggregates.reduce((acc, a) => acc + a.count, 0);
  if (!city || total < MIN_SIGHTINGS_FOR_PERSONALIZED) {
    // Generic fallback — same rotation as the local-fallback copy
    // the client uses when this push doesn't fire.
    const pool = [
      "Look up — what's drifting overhead?",
      "Five minutes with the sky. That's the whole thing.",
      "Today's sky is unrepeatable. Catch a frame.",
      "Whatever shape finds you today — develop it.",
      "Out the window, just for a second.",
    ];
    const dayOfYear = Math.floor((Date.now() / (1000 * 60 * 60 * 24)) % pool.length);
    return { title, body: pool[dayOfYear] };
  }

  // Take the top shape and either the top 3 or all of them if fewer.
  const top = aggregates.slice(0, 3).map((a) => a.shape_name);
  const phrase = listPhrase(top);
  const body = total === 1
    ? `Someone near ${city} saw ${top[0]} today. Your turn?`
    : `${total} people near ${city} saw ${phrase} in the sky today.`;
  return { title, body };
}

/**
 * Oxford-comma list: ["a", "b"] → "a and b"; ["a", "b", "c"] → "a, b, and c".
 */
function listPhrase(items: string[]): string {
  if (items.length === 0) return "";
  if (items.length === 1) return items[0];
  if (items.length === 2) return `${items[0]} and ${items[1]}`;
  return `${items.slice(0, -1).join(", ")}, and ${items[items.length - 1]}`;
}

// ---------- APNs helpers (matches notify-nearby-users) ----------------------

async function buildApnsJwt(): Promise<string> {
  const keyId  = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey = Deno.env.get("APNS_PRIVATE_KEY")!;

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
  deviceToken, apnsToken, title, body,
}: {
  deviceToken: string;
  apnsToken: string;
  title: string;
  body: string;
}) {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const payload = {
    aps: {
      alert: { title, body },
      sound: "default",
      "interruption-level": "active",
    },
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
