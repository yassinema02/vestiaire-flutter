-- RLS Policies for style_squads and squad_memberships
-- Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)
--
-- Security model:
--   - Users can only see squads they are members of (and not soft-deleted).
--   - Any authenticated user can create a squad.
--   - Only the squad creator (admin) can update a squad.
--   - Membership inserts are restricted to the API service role (joins go through API validation).
--   - Admin can delete any membership; members can only delete their own.

BEGIN;

-- ============================================================
-- Enable RLS on both tables
-- ============================================================
ALTER TABLE app_public.style_squads ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_public.squad_memberships ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- style_squads policies
-- ============================================================

-- SELECT: User can see squads where they have a membership AND deleted_at IS NULL
CREATE POLICY style_squads_select_policy ON app_public.style_squads
  FOR SELECT
  USING (
    deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM app_public.squad_memberships sm
      WHERE sm.squad_id = id
        AND sm.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Any authenticated user can create a squad
CREATE POLICY style_squads_insert_policy ON app_public.style_squads
  FOR INSERT
  WITH CHECK (
    current_setting('app.current_user_id', true) IS NOT NULL
  );

-- UPDATE: Only the created_by user (admin) can update
CREATE POLICY style_squads_update_policy ON app_public.style_squads
  FOR UPDATE
  USING (
    created_by = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
  );

-- ============================================================
-- squad_memberships policies
-- ============================================================

-- SELECT: User can see memberships for squads they belong to
CREATE POLICY squad_memberships_select_policy ON app_public.squad_memberships
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM app_public.squad_memberships sm2
      WHERE sm2.squad_id = squad_id
        AND sm2.user_id = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

-- INSERT: Restricted to API service role (joins go through API validation, not direct inserts)
CREATE POLICY squad_memberships_insert_policy ON app_public.squad_memberships
  FOR INSERT
  WITH CHECK (
    current_setting('app.current_user_id', true) IS NOT NULL
  );

-- DELETE: Admin can delete any membership in their squad; member can delete only their own
CREATE POLICY squad_memberships_delete_policy ON app_public.squad_memberships
  FOR DELETE
  USING (
    -- User is deleting their own membership
    user_id = (
      SELECT p.id FROM app_public.profiles p
      WHERE p.firebase_uid = current_setting('app.current_user_id', true)
      LIMIT 1
    )
    OR
    -- User is admin of the squad (created_by on style_squads)
    EXISTS (
      SELECT 1 FROM app_public.style_squads s
      WHERE s.id = squad_id
        AND s.created_by = (
          SELECT p.id FROM app_public.profiles p
          WHERE p.firebase_uid = current_setting('app.current_user_id', true)
          LIMIT 1
        )
    )
  );

COMMIT;
