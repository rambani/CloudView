-- Daily-reminder preferences on profiles.
--
-- Feeds the `daily-reminders` edge function: when its cron tick
-- runs, it scans for profiles whose `reminder_enabled = true` and
-- whose `reminder_local_time` matches "now" in their `timezone`,
-- aggregates `sighting_metadata` by city, and sends an APNS push.
--
-- The client (DailyReminderService + SupabaseService.updateReminderPrefs)
-- writes these columns whenever the user toggles the reminder or
-- changes the time in Settings; the existing RLS policy on
-- profiles ("update own row") covers the access pattern.
--
-- timezone is the IANA name (e.g. "America/New_York"). We store it
-- per-user (rather than computing on the server) because Supabase
-- Postgres can't reliably resolve a device's timezone from request
-- metadata, and pg has limited TZ-arithmetic surface area outside
-- AT TIME ZONE.

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS reminder_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS reminder_local_time TEXT
        CHECK (reminder_local_time IS NULL OR reminder_local_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS timezone TEXT
        CHECK (timezone IS NULL OR char_length(timezone) <= 64);

-- The cron tick needs a fast scan over "who's due for a reminder
-- right now." Compound index covers the WHERE clauses the edge
-- function will run.
CREATE INDEX IF NOT EXISTS idx_profiles_reminder_due
    ON public.profiles (reminder_enabled, timezone, reminder_local_time)
    WHERE reminder_enabled = TRUE;
