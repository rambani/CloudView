-- Aggregation-only sighting metadata.
--
-- Powers the future "daily reminder with local context" feature:
-- once enough rows are flowing, a daily edge function rolls them up
-- by city and date to produce push payloads like
-- "23 people near Brooklyn saw animals in the sky today."
--
-- Privacy posture (intentional):
--   • SENT:     shape description text, city name, captured timestamp
--   • NOT SENT: image data, image URL, precise lat/lng, the user's
--               private note, any other JournalEntry field
--
-- This is the minimum needed for regional aggregation. The image
-- and note never leave the device. Anonymous (unauthenticated)
-- users contribute nothing — only signed-in users insert rows,
-- which keeps the table free of spam without a captcha.

CREATE TABLE IF NOT EXISTS public.sighting_metadata (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shape_name  TEXT NOT NULL CHECK (char_length(shape_name) BETWEEN 1 AND 80),
    city        TEXT CHECK (char_length(city) <= 60),
    captured_at TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Aggregation queries always filter by (city, day). The composite
-- index covers the rollup edge function's typical scan pattern.
CREATE INDEX IF NOT EXISTS idx_sighting_metadata_city_day
    ON public.sighting_metadata (city, captured_at DESC);

-- Profile-page "your contribution" queries (when/if we add them)
-- would filter by user_id; keep an index ready.
CREATE INDEX IF NOT EXISTS idx_sighting_metadata_user
    ON public.sighting_metadata (user_id);

ALTER TABLE public.sighting_metadata ENABLE ROW LEVEL SECURITY;

-- Authenticated users may insert rows attributed to themselves.
-- WITH CHECK enforces user_id == auth.uid() at insert time.
CREATE POLICY "Insert own metadata"
    ON public.sighting_metadata
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- No client-side SELECT. The aggregation edge function runs with
-- service_role and exposes only roll-ups, never individual rows.
CREATE POLICY "No client read"
    ON public.sighting_metadata
    FOR SELECT
    TO authenticated
    USING (false);
