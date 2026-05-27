-- Push notification support

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS device_token          TEXT,
    ADD COLUMN IF NOT EXISTS notifications_enabled  BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS notification_radius_km INTEGER NOT NULL DEFAULT 50;

-- Track each user's approximate location (updated when they post a sighting)
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS last_latitude  DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS last_longitude DOUBLE PRECISION;

-- Keep last_latitude/longitude up to date automatically when a sighting is posted
CREATE OR REPLACE FUNCTION sync_profile_location()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        UPDATE profiles
           SET last_latitude = NEW.latitude, last_longitude = NEW.longitude
         WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_location ON sightings;
CREATE TRIGGER trg_sync_profile_location
    AFTER INSERT ON sightings
    FOR EACH ROW EXECUTE FUNCTION sync_profile_location();

-- Find profiles with device tokens within a given radius of (lat, lon).
-- Used by the notify-nearby-users Edge Function.
CREATE OR REPLACE FUNCTION profiles_within_radius(lat float, lon float, radius_km float)
RETURNS SETOF profiles
LANGUAGE sql STABLE AS $$
    SELECT p.*
    FROM profiles p
    WHERE p.device_token IS NOT NULL
      AND p.notifications_enabled = true
      AND p.last_latitude IS NOT NULL
      AND p.last_longitude IS NOT NULL
      AND (
        6371 * acos(
          LEAST(1.0,
            cos(radians(lat))  * cos(radians(p.last_latitude)) *
            cos(radians(p.last_longitude) - radians(lon)) +
            sin(radians(lat))  * sin(radians(p.last_latitude))
          )
        )
      ) < radius_km;
$$;

-- Index so the haversine query above is fast
CREATE INDEX IF NOT EXISTS idx_profiles_location
    ON profiles (last_latitude, last_longitude)
    WHERE last_latitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sightings_location
    ON sightings (latitude, longitude)
    WHERE latitude IS NOT NULL;
