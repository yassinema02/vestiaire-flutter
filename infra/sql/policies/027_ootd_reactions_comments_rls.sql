-- RLS Policies for ootd_reactions and ootd_comments
-- Story 9.4: Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)
--
-- Security model:
--   - Users can see reactions/comments on posts visible to them (via squad membership).
--   - Authenticated users can create reactions/comments as themselves.
--   - Users can delete their own reactions.
--   - Comment authors can soft-delete their own comments.
--   - Post authors can soft-delete any comment on their post.

BEGIN;

-- ============================================================
-- Enable RLS on both tables
-- ============================================================
ALTER TABLE app_public.ootd_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.ootd_comments ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- ootd_reactions policies
-- ============================================================

-- SELECT: User can see reactions on posts visible to them (squad membership)
CREATE POLICY ootd_reactions_select_policy ON app_public.ootd_reactions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app_public.ootd_post_squads ops
      JOIN app_public.squad_memberships sm ON sm.squad_id = ops.squad_id
      WHERE ops.post_id = post_id
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Authenticated user can insert where user_id matches their profile
CREATE POLICY ootd_reactions_insert_policy ON app_public.ootd_reactions
  FOR INSERT
  WITH CHECK (
    user_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- DELETE: User can delete their own reactions only
CREATE POLICY ootd_reactions_delete_policy ON app_public.ootd_reactions
  FOR DELETE
  USING (
    user_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- ============================================================
-- ootd_comments policies
-- ============================================================

-- SELECT: User can see comments on posts visible to them, WHERE deleted_at IS NULL
CREATE POLICY ootd_comments_select_policy ON app_public.ootd_comments
  FOR SELECT
  USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM app_public.ootd_post_squads ops
      JOIN app_public.squad_memberships sm ON sm.squad_id = ops.squad_id
      WHERE ops.post_id = post_id
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Authenticated user can insert where author_id matches their profile
CREATE POLICY ootd_comments_insert_policy ON app_public.ootd_comments
  FOR INSERT
  WITH CHECK (
    author_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- UPDATE (soft delete): Comment author OR post author can soft-delete
CREATE POLICY ootd_comments_update_policy ON app_public.ootd_comments
  FOR UPDATE
  USING (
    -- Comment author can soft-delete their own comment
    author_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
    OR
    -- Post author can soft-delete any comment on their post
    EXISTS (
      SELECT 1 FROM app_public.ootd_posts op
      WHERE op.id = post_id
        AND op.author_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

COMMIT;
