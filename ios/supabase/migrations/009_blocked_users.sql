-- App Review Guideline 1.2 (UGC apps) requires a way for users to
-- block other accounts. Once blocked, the blocker should not see any
-- of the blocked user's content in their feed.

CREATE TABLE IF NOT EXISTS blocked_users (
    blocker_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS blocked_users_blocker_idx
    ON blocked_users (blocker_id);
CREATE INDEX IF NOT EXISTS blocked_users_blocked_idx
    ON blocked_users (blocked_id);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "blocks_select_own" ON blocked_users
    FOR SELECT USING (auth.uid() = blocker_id);

CREATE POLICY "blocks_insert_own" ON blocked_users
    FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "blocks_delete_own" ON blocked_users
    FOR DELETE USING (auth.uid() = blocker_id);

-- Feed reads now go through visible_sightings, which excludes any
-- content authored by an account the caller has blocked. Defined as
-- a view (not a policy on sightings) because the existing
-- "Sightings are viewable by everyone" policy is the right default
-- for unauthenticated public reads (e.g. share links). The view
-- enforces the per-caller filter without changing the base policy.
CREATE OR REPLACE VIEW visible_sightings AS
SELECT s.*
FROM sightings s
WHERE NOT EXISTS (
    SELECT 1 FROM blocked_users b
    WHERE b.blocker_id = auth.uid()
      AND b.blocked_id = s.user_id
);

-- Equivalent helper for the city stats — recent_shapes shouldn't
-- include any shape names from blocked users either.
CREATE OR REPLACE FUNCTION city_sighting_stats()
RETURNS TABLE (
    city          text,
    country       text,
    count         bigint,
    latitude      double precision,
    longitude     double precision,
    recent_shapes text[]
)
LANGUAGE sql STABLE AS $$
    SELECT
        s.city,
        s.country,
        count(*) AS count,
        avg(s.latitude)  AS latitude,
        avg(s.longitude) AS longitude,
        (array_agg(s.shape_name ORDER BY s.created_at DESC)
            FILTER (WHERE s.shape_name IS NOT NULL))[1:5] AS recent_shapes
    FROM sightings s
    WHERE s.city IS NOT NULL
      AND s.latitude IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid()
          AND b.blocked_id = s.user_id
      )
    GROUP BY s.city, s.country
    ORDER BY count DESC
    LIMIT 100;
$$;

CREATE OR REPLACE FUNCTION sightings_within_radius(
    lat float, lon float, radius_km float
)
RETURNS SETOF sightings
LANGUAGE sql STABLE AS $$
    SELECT s.*
    FROM sightings s
    WHERE s.latitude IS NOT NULL
      AND s.longitude IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid()
          AND b.blocked_id = s.user_id
      )
      AND (
          6371 * acos(
              LEAST(1.0,
                cos(radians(lat)) * cos(radians(s.latitude)) *
                cos(radians(s.longitude) - radians(lon)) +
                sin(radians(lat)) * sin(radians(s.latitude))
              )
          )
      ) <= radius_km
    ORDER BY s.created_at DESC
    LIMIT 50;
$$;
