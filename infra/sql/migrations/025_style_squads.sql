-- Migration 025: Style Squads & Squad Memberships
-- Story 9.1: Squad Creation & Management (FR-SOC-01 through FR-SOC-05)
--
-- Creates the social infrastructure tables for Style Squads.

BEGIN;

-- ============================================================
-- style_squads: Private groups for sharing outfits
-- ============================================================
CREATE TABLE app_public.style_squads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  description VARCHAR(200),
  invite_code VARCHAR(8) NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

COMMENT ON TABLE app_public.style_squads IS 'Private style groups where users share outfits (OOTD).';
COMMENT ON COLUMN app_public.style_squads.id IS 'Primary key, auto-generated UUID.';
COMMENT ON COLUMN app_public.style_squads.name IS 'Squad display name (1-50 characters, required).';
COMMENT ON COLUMN app_public.style_squads.description IS 'Optional squad description (max 200 characters).';
COMMENT ON COLUMN app_public.style_squads.invite_code IS 'Unique 8-character alphanumeric code for joining the squad.';
COMMENT ON COLUMN app_public.style_squads.created_by IS 'References the profile of the user who created (and initially admins) the squad.';
COMMENT ON COLUMN app_public.style_squads.created_at IS 'Timestamp when the squad was created.';
COMMENT ON COLUMN app_public.style_squads.updated_at IS 'Timestamp of last update to the squad.';
COMMENT ON COLUMN app_public.style_squads.deleted_at IS 'Soft-delete timestamp. Non-null means the squad is deleted and excluded from queries.';

-- ============================================================
-- squad_memberships: Links users to squads with roles
-- ============================================================
CREATE TABLE app_public.squad_memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  role VARCHAR(10) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (squad_id, user_id)
);

COMMENT ON TABLE app_public.squad_memberships IS 'Squad membership records linking users to squads with role-based access.';
COMMENT ON COLUMN app_public.squad_memberships.id IS 'Primary key, auto-generated UUID.';
COMMENT ON COLUMN app_public.squad_memberships.squad_id IS 'References the squad this membership belongs to.';
COMMENT ON COLUMN app_public.squad_memberships.user_id IS 'References the profile of the member.';
COMMENT ON COLUMN app_public.squad_memberships.role IS 'Member role: admin (squad creator/owner) or member.';
COMMENT ON COLUMN app_public.squad_memberships.joined_at IS 'Timestamp when the user joined the squad.';

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX idx_squad_memberships_user_id ON app_public.squad_memberships(user_id);
CREATE INDEX idx_squad_memberships_squad_id ON app_public.squad_memberships(squad_id);
CREATE INDEX idx_style_squads_invite_code ON app_public.style_squads(invite_code);
CREATE INDEX idx_style_squads_deleted_at ON app_public.style_squads(deleted_at);

COMMIT;
