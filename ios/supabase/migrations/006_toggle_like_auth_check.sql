-- Security fix: toggle_like was accepting p_user_id from the client and
-- using it verbatim, but the function is SECURITY DEFINER and so bypasses
-- the "auth.uid() = user_id" RLS check on sighting_likes. A malicious
-- client could call:
--
--     client.rpc("toggle_like", {p_sighting_id: ..., p_user_id: <other>})
--
-- ...and like or unlike any sighting on behalf of any user. The likes
-- counter on the target sighting moves either way, so they can also
-- spam the count.
--
-- The simplest robust fix is to ignore the parameter entirely and use
-- auth.uid() inside the function. We keep the parameter in the
-- signature for backward compatibility with already-shipped iOS
-- clients that pass it (they currently pass the right id), but verify
-- it matches the JWT subject. The parameter doesn't get used for any
-- DB write — auth.uid() is the source of truth.

CREATE OR REPLACE FUNCTION toggle_like(p_sighting_id uuid, p_user_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_caller uuid := auth.uid();
    v_liked  boolean;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- If the client passed a user id at all, it must match the caller.
    -- Drop-in compatible with the existing client that already passes
    -- its own id; rejects any attempt to act on someone else's behalf.
    IF p_user_id IS NOT NULL AND p_user_id <> v_caller THEN
        RAISE EXCEPTION 'p_user_id does not match authenticated user';
    END IF;

    -- Same row-locking behaviour as migration 004 so concurrent
    -- (un)likes don't divergence the counter.
    PERFORM id FROM sightings WHERE id = p_sighting_id FOR UPDATE;

    IF EXISTS (
        SELECT 1 FROM sighting_likes
        WHERE sighting_id = p_sighting_id AND user_id = v_caller
    ) THEN
        DELETE FROM sighting_likes
        WHERE sighting_id = p_sighting_id AND user_id = v_caller;
        UPDATE sightings SET likes = GREATEST(0, likes - 1) WHERE id = p_sighting_id;
        v_liked := false;
    ELSE
        INSERT INTO sighting_likes (sighting_id, user_id) VALUES (p_sighting_id, v_caller);
        UPDATE sightings SET likes = likes + 1 WHERE id = p_sighting_id;
        v_liked := true;
    END IF;

    RETURN json_build_object('liked', v_liked);
END;
$$;

-- Same class of bug in increment_sightings: SECURITY DEFINER + accepts
-- user_id_input from the client without verification, so a malicious
-- client can inflate any user's total_sightings counter. The iOS app
-- always passes its own currentUser.id, so this is a server-side
-- hardening rather than a behaviour change.
CREATE OR REPLACE FUNCTION increment_sightings(user_id_input text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_caller uuid := auth.uid();
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF user_id_input IS NOT NULL AND user_id_input::uuid <> v_caller THEN
        RAISE EXCEPTION 'user_id_input does not match authenticated user';
    END IF;

    UPDATE profiles
       SET total_sightings = total_sightings + 1,
           last_active_at = now()
     WHERE id = v_caller;
END;
$$;
