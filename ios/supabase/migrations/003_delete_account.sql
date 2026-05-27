-- Production additions
-- Run after 001_initial.sql and 002_push_notifications.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- Content reporting (for moderation)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sighting_reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sighting_id UUID NOT NULL REFERENCES sightings(id) ON DELETE CASCADE,
    reported_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    resolved    BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (sighting_id, reported_by)
);

ALTER TABLE sighting_reports ENABLE ROW LEVEL SECURITY;

-- Reporters can submit but not read others' reports (prevents targeted harassment)
CREATE POLICY "reports_insert_own" ON sighting_reports
    FOR INSERT WITH CHECK (auth.uid() = reported_by);

-- ─────────────────────────────────────────────────────────────────────────────
-- Auto-create profile on sign-up
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO profiles (id, username)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'username',
            split_part(NEW.email, '@', 1)
        )
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- Account deletion
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    -- Sightings cascade to sighting_likes and sighting_reports
    DELETE FROM sightings WHERE user_id = auth.uid();
    DELETE FROM profiles   WHERE id = auth.uid();
    -- The auth.users row is deleted by the delete-account Edge Function
END;
$$;
