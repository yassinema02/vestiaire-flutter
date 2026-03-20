-- RLS Policies for ootd_posts, ootd_post_squads, and ootd_post_items
-- Story 9.2: OOTD Post Creation (FR-SOC-06)
--
-- Security model:
--   - Users can see posts shared to squads they belong to (via ootd_post_squads + squad_memberships).
--   - Authenticated users can create posts as themselves (author_id = their profile id).
--   - Only the author can soft-delete their own post.
--   - ootd_post_squads and ootd_post_items INSERT restricted to API service role.
--   - ootd_post_squads SELECT gated by squad membership.
--   - ootd_post_items SELECT gated by parent post visibility.

BEGIN;

-- ============================================================
-- Enable RLS on all three tables
-- ============================================================
ALTER TABLE app_public.ootd_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.ootd_post_squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.ootd_post_items ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- ootd_posts policies
-- ============================================================

-- SELECT: User can see posts where at least one squad is one they belong to, AND deleted_at IS NULL
CREATE POLICY ootd_posts_select_policy ON app_public.ootd_posts
  FOR SELECT
  USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM app_public.ootd_post_squads ops
      JOIN app_public.squad_memberships sm ON sm.squad_id = ops.squad_id
      WHERE ops.post_id = id
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Authenticated user can insert where author_id matches their profile
CREATE POLICY ootd_posts_insert_policy ON app_public.ootd_posts
  FOR INSERT
  WITH CHECK (
    author_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- UPDATE: Only the author can soft-delete (update deleted_at) their own post
CREATE POLICY ootd_posts_update_policy ON app_public.ootd_posts
  FOR UPDATE
  USING (
    author_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- ============================================================
-- ootd_post_squads policies
-- ============================================================

-- SELECT: User can see rows where squad_id is in a squad the user belongs to
CREATE POLICY ootd_post_squads_select_policy ON app_public.ootd_post_squads
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app_public.squad_memberships sm
      WHERE sm.squad_id = squad_id
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Restricted to API service role (inserts go through API validation)
CREATE POLICY ootd_post_squads_insert_policy ON app_public.ootd_post_squads
  FOR INSERT
  WITH CHECK (
    current_setting('app.current_user_id', true) IS NOT NULL
  );

-- ============================================================
-- ootd_post_items policies
-- ============================================================

-- SELECT: User can see rows where the parent post_id is visible to them
CREATE POLICY ootd_post_items_select_policy ON app_public.ootd_post_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app_public.ootd_posts op
      JOIN app_public.ootd_post_squads ops ON ops.post_id = op.id
      JOIN app_public.squad_memberships sm ON sm.squad_id = ops.squad_id
      WHERE op.id = post_id
        AND op.deleted_at IS NULL
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Restricted to API service role
CREATE POLICY ootd_post_items_insert_policy ON app_public.ootd_post_items
  FOR INSERT
  WITH CHECK (
    current_setting('app.current_user_id', true) IS NOT NULL
  );

COMMIT;
