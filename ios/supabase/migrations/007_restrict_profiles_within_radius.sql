-- profiles_within_radius returns SETOF profiles, which includes the
-- per-user device_token column. The function is in the public schema
-- and (by default) EXECUTE is granted to PUBLIC, so any authenticated
-- client can call:
--
--     client.rpc("profiles_within_radius", { lat, lon, radius_km })
--
-- ...and pull every neighbouring user's APNs device token. The RLS
-- policy on profiles is "Public profiles are viewable by everyone",
-- so RLS does not restrict the column — every row comes through.
--
-- The only legitimate caller is the notify-nearby-users Edge Function,
-- which uses the service role key (RLS bypassed by design). Restrict
-- EXECUTE to service_role; authenticated callers get permission denied.

REVOKE EXECUTE ON FUNCTION profiles_within_radius(float, float, float) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION profiles_within_radius(float, float, float) FROM authenticated;
GRANT  EXECUTE ON FUNCTION profiles_within_radius(float, float, float) TO service_role;
