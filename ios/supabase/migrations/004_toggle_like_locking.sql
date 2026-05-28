-- Fix toggle_like to use row-level locking, preventing like-count divergence
-- under concurrent requests for the same sighting.
--
-- Without FOR UPDATE, two simultaneous unlikes can both observe the row as
-- "liked", both delete the like, and both decrement — ending at likes - 2
-- instead of likes - 1.

CREATE OR REPLACE FUNCTION toggle_like(p_sighting_id uuid, p_user_id uuid)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_liked boolean;
BEGIN
    -- Lock the sightings row for the duration of this transaction so that
    -- concurrent calls serialize rather than interleave their read-modify-write.
    PERFORM id FROM sightings WHERE id = p_sighting_id FOR UPDATE;

    IF EXISTS (
        SELECT 1 FROM sighting_likes
        WHERE sighting_id = p_sighting_id AND user_id = p_user_id
    ) THEN
        DELETE FROM sighting_likes
        WHERE sighting_id = p_sighting_id AND user_id = p_user_id;
        UPDATE sightings SET likes = GREATEST(0, likes - 1) WHERE id = p_sighting_id;
        v_liked := false;
    ELSE
        INSERT INTO sighting_likes (sighting_id, user_id) VALUES (p_sighting_id, p_user_id);
        UPDATE sightings SET likes = likes + 1 WHERE id = p_sighting_id;
        v_liked := true;
    END IF;

    RETURN json_build_object('liked', v_liked);
END;
$$;
