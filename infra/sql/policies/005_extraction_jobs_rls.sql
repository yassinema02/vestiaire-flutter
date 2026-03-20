-- RLS Policy 005: Extraction jobs and photos row-level security
-- Story 10.1: Bulk Photo Gallery Selection (FR-EXT-01, FR-EXT-08)

-- === wardrobe_extraction_jobs RLS ===

ALTER TABLE app_public.wardrobe_extraction_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.wardrobe_extraction_jobs FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS extraction_jobs_self_select ON app_public.wardrobe_extraction_jobs;
CREATE POLICY extraction_jobs_self_select
  ON app_public.wardrobe_extraction_jobs
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_jobs_self_insert ON app_public.wardrobe_extraction_jobs;
CREATE POLICY extraction_jobs_self_insert
  ON app_public.wardrobe_extraction_jobs
  FOR INSERT
  WITH CHECK (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_jobs_self_update ON app_public.wardrobe_extraction_jobs;
CREATE POLICY extraction_jobs_self_update
  ON app_public.wardrobe_extraction_jobs
  FOR UPDATE
  USING (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  )
  WITH CHECK (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_jobs_self_delete ON app_public.wardrobe_extraction_jobs;
CREATE POLICY extraction_jobs_self_delete
  ON app_public.wardrobe_extraction_jobs
  FOR DELETE
  USING (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

-- === extraction_job_photos RLS ===

ALTER TABLE app_public.extraction_job_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.extraction_job_photos FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS extraction_photos_self_select ON app_public.extraction_job_photos;
CREATE POLICY extraction_photos_self_select
  ON app_public.extraction_job_photos
  FOR SELECT
  USING (
    job_id IN (
      SELECT wej.id FROM app_public.wardrobe_extraction_jobs wej
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_photos_self_insert ON app_public.extraction_job_photos;
CREATE POLICY extraction_photos_self_insert
  ON app_public.extraction_job_photos
  FOR INSERT
  WITH CHECK (
    job_id IN (
      SELECT wej.id FROM app_public.wardrobe_extraction_jobs wej
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_photos_self_update ON app_public.extraction_job_photos;
CREATE POLICY extraction_photos_self_update
  ON app_public.extraction_job_photos
  FOR UPDATE
  USING (
    job_id IN (
      SELECT wej.id FROM app_public.wardrobe_extraction_jobs wej
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  )
  WITH CHECK (
    job_id IN (
      SELECT wej.id FROM app_public.wardrobe_extraction_jobs wej
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_photos_self_delete ON app_public.extraction_job_photos;
CREATE POLICY extraction_photos_self_delete
  ON app_public.extraction_job_photos
  FOR DELETE
  USING (
    job_id IN (
      SELECT wej.id FROM app_public.wardrobe_extraction_jobs wej
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

-- === extraction_job_items RLS ===
-- Story 10.2: Bulk Extraction Processing (FR-EXT-02, FR-EXT-09)

ALTER TABLE app_public.extraction_job_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.extraction_job_items FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS extraction_items_self_select ON app_public.extraction_job_items;
CREATE POLICY extraction_items_self_select
  ON app_public.extraction_job_items
  FOR SELECT
  USING (
    photo_id IN (
      SELECT ejp.id FROM app_public.extraction_job_photos ejp
      JOIN app_public.wardrobe_extraction_jobs wej ON wej.id = ejp.job_id
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_items_self_insert ON app_public.extraction_job_items;
CREATE POLICY extraction_items_self_insert
  ON app_public.extraction_job_items
  FOR INSERT
  WITH CHECK (
    photo_id IN (
      SELECT ejp.id FROM app_public.extraction_job_photos ejp
      JOIN app_public.wardrobe_extraction_jobs wej ON wej.id = ejp.job_id
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_items_self_update ON app_public.extraction_job_items;
CREATE POLICY extraction_items_self_update
  ON app_public.extraction_job_items
  FOR UPDATE
  USING (
    photo_id IN (
      SELECT ejp.id FROM app_public.extraction_job_photos ejp
      JOIN app_public.wardrobe_extraction_jobs wej ON wej.id = ejp.job_id
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  )
  WITH CHECK (
    photo_id IN (
      SELECT ejp.id FROM app_public.extraction_job_photos ejp
      JOIN app_public.wardrobe_extraction_jobs wej ON wej.id = ejp.job_id
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );

DROP POLICY IF EXISTS extraction_items_self_delete ON app_public.extraction_job_items;
CREATE POLICY extraction_items_self_delete
  ON app_public.extraction_job_items
  FOR DELETE
  USING (
    photo_id IN (
      SELECT ejp.id FROM app_public.extraction_job_photos ejp
      JOIN app_public.wardrobe_extraction_jobs wej ON wej.id = ejp.job_id
      JOIN app_public.profiles p ON p.id = wej.profile_id
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
    )
  );
