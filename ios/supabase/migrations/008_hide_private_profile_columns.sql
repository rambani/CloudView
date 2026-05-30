-- Lock down which profile columns other authenticated users can read.
--
-- The RLS policy on profiles ("Public profiles are viewable by everyone")
-- does not restrict columns — it grants row visibility. By default,
-- the SELECT privilege on the table covers every column.
--
-- This means any authenticated client today can pull:
--
--     client.from("profiles").select("device_token, last_latitude, last_longitude")
--
-- ...and harvest every user's APNs token + last known coordinates.
-- The token alone isn't pushable without the APNs auth key, but it's
-- still PII tied to a device, and the coordinates are an obvious
-- privacy leak.
--
-- The iOS client today only ever reads PUBLIC columns of OTHER users
-- (username, avatar_url, city, total_sightings, streak_days). It
-- never reads its own device_token / last_latitude / last_longitude
-- from the row (NotificationService keeps the token locally and
-- WRITES it up; LocationService keeps coordinates locally and the
-- sync_profile_location trigger WRITES them up). So revoking SELECT
-- on the private columns is backwards-compatible with the client.
--
-- Column-level grants are the right Supabase-idiomatic fix for this:
-- revoke the blanket SELECT, then grant only the public columns.

REVOKE SELECT ON profiles FROM authenticated;
REVOKE SELECT ON profiles FROM anon;

-- Public columns — visible to everyone (auth + anon)
GRANT SELECT (
    id,
    username,
    avatar_url,
    city,
    total_sightings,
    streak_days,
    last_active_at,
    created_at
) ON profiles TO authenticated;

GRANT SELECT (
    id,
    username,
    avatar_url,
    city,
    total_sightings,
    streak_days,
    last_active_at,
    created_at
) ON profiles TO anon;

-- service_role keeps full SELECT (notify-nearby-users Edge Function
-- needs device_token + last_lat/lon). It bypasses RLS and these
-- grants don't apply to it anyway, but documenting intent:
--   GRANT SELECT ON profiles TO service_role;  -- implicit

-- UPDATE and INSERT permissions on the table are unchanged; the
-- existing "Users can update their own profile" RLS policy continues
-- to govern who can write what.
