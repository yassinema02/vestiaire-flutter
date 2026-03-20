-- Migration 013: Create outfits and outfit_items tables
-- Epic 4: AI Outfit Engine
-- Story 4.1: Daily AI Outfit Generation
--
-- These tables store saved outfits. Story 4.1 creates the tables but does NOT
-- persist generated suggestions (they are returned in-memory). Story 4.2 will
-- persist accepted outfits when the user swipes right.

-- 1. outfits table
CREATE TABLE IF NOT EXISTS app_public.outfits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  name TEXT,
  explanation TEXT,
  occasion TEXT,
  source TEXT NOT NULL DEFAULT 'ai' CHECK (source IN ('ai', 'manual')),
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policy for outfits
ALTER TABLE app_public.outfits ENABLE ROW LEVEL SECURITY;

CREATE POLICY outfits_user_policy ON app_public.outfits
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Index for efficient user-scoped queries ordered by date
CREATE INDEX idx_outfits_profile ON app_public.outfits(profile_id, created_at DESC);

-- Reuse set_updated_at() trigger
CREATE TRIGGER set_outfits_updated_at
  BEFORE UPDATE ON app_public.outfits
  FOR EACH ROW
  EXECUTE FUNCTION app_private.set_updated_at();

-- 2. outfit_items join table
CREATE TABLE IF NOT EXISTS app_public.outfit_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  outfit_id UUID NOT NULL REFERENCES app_public.outfits(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (outfit_id, item_id)
);

-- RLS policy for outfit_items (join through outfits to profiles)
ALTER TABLE app_public.outfit_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY outfit_items_user_policy ON app_public.outfit_items
  FOR ALL
  USING (outfit_id IN (
    SELECT o.id FROM app_public.outfits o
    JOIN app_public.profiles p ON p.id = o.profile_id
    WHERE p.firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Index for efficient outfit item lookups
CREATE INDEX idx_outfit_items_outfit ON app_public.outfit_items(outfit_id);
