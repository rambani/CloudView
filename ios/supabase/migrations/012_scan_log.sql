-- Per-user scan bookkeeping for the develop-polaroid rate limit.
--
-- The edge function proxies a paid AI pipeline, and anonymous
-- sign-ins make a valid JWT free to obtain — so the function caps
-- each user at MAX_SCANS_PER_USER_PER_DAY (counted over a trailing
-- 24h window in this table) before any Gemini call runs. Rows are
-- inserted at request START, so failed pipelines still count
-- against an abuser hammering the proxy.
--
-- This is abuse protection, not the product quota: the free tier's
-- one-Polaroid-per-day remains client-enforced and is far below
-- the server cap.

CREATE TABLE IF NOT EXISTS public.scan_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The rate-limit check is "count rows for this user since now-24h"
-- on every scan; the compound index makes that a range scan.
CREATE INDEX IF NOT EXISTS idx_scan_log_user_time
    ON public.scan_log (user_id, created_at DESC);

-- Service-role only: the edge function writes and counts; clients
-- never touch this table. RLS enabled with NO policies denies all
-- access to anon/authenticated roles.
ALTER TABLE public.scan_log ENABLE ROW LEVEL SECURITY;
