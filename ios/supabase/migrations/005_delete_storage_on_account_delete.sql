-- Account deletion should remove the user's uploaded cloud images from
-- storage, not just their DB rows. Storage.objects has no FK to profiles,
-- so the cascade chain in 001+003 leaves the user's HEIC/JPEG files behind.
--
-- Without this, "Delete account" leaves their files in the public
-- sighting-images bucket — the App Store review team flags this, and it
-- breaks the implicit GDPR / privacy-policy promise of comprehensive
-- erasure.

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user uuid := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Storage objects first, so a partial failure after the DB rows are
    -- already gone doesn't leave orphan files we can't trace back. The
    -- prefix matches the upload path used in SupabaseService.uploadSighting:
    --     "<user_id>/<sighting_id>.jpg"
    DELETE FROM storage.objects
     WHERE bucket_id = 'sighting-images'
       AND (storage.foldername(name))[1] = v_user::text;

    -- Sightings cascade to sighting_likes (likes on those sightings)
    -- and sighting_reports (reports on those sightings).
    DELETE FROM sightings WHERE user_id = v_user;

    -- Profile cascade catches the user's likes/reports on OTHER sightings
    -- (where user_id / reported_by = me).
    DELETE FROM profiles WHERE id = v_user;

    -- The auth.users row is deleted by the delete-account Edge Function
    -- using the service role key.
END;
$$;
