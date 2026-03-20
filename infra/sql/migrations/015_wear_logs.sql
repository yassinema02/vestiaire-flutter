-- Migration 015: Create wear_logs, wear_log_items tables, add wear tracking columns to items
-- Epic 5: Wardrobe Analytics & Wear Logging
-- Story 5.1: Log Today's Outfit & Wear Counts
--
-- Creates the wear logging infrastructure: wear_logs for audit trail,
-- wear_log_items for item associations, wear_count/last_worn_date columns
-- on items for efficient display, and increment_wear_counts RPC for atomicity.

-- 1. wear_logs table
CREATE TABLE IF NOT EXISTS app_public.wear_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  logged_date DATE NOT NULL DEFAULT CURRENT_DATE,
  outfit_id UUID REFERENCES app_public.outfits(id) ON DELETE SET NULL,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policy for wear_logs
ALTER TABLE app_public.wear_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY wear_logs_user_policy ON app_public.wear_logs
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Index for efficient user-scoped date-ordered queries
CREATE INDEX idx_wear_logs_profile_date ON app_public.wear_logs(profile_id, logged_date DESC);

-- 2. wear_log_items join table
CREATE TABLE IF NOT EXISTS app_public.wear_log_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wear_log_id UUID NOT NULL REFERENCES app_public.wear_logs(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(wear_log_id, item_id)
);

-- RLS policy for wear_log_items (join through wear_logs to profiles)
ALTER TABLE app_public.wear_log_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY wear_log_items_user_policy ON app_public.wear_log_items
  FOR ALL
  USING (wear_log_id IN (
    SELECT wl.id FROM app_public.wear_logs wl
    JOIN app_public.profiles p ON p.id = wl.profile_id
    WHERE p.firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Index for efficient wear log item lookups
CREATE INDEX idx_wear_log_items_wear_log ON app_public.wear_log_items(wear_log_id);

-- Index for per-item wear history lookups
CREATE INDEX idx_wear_log_items_item ON app_public.wear_log_items(item_id);

-- 3. Add wear_count and last_worn_date columns to items table
ALTER TABLE app_public.items
  ADD COLUMN IF NOT EXISTS wear_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_worn_date DATE;

-- 4. Atomic RPC function to increment wear counts
CREATE OR REPLACE FUNCTION app_public.increment_wear_counts(p_item_ids UUID[], p_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE app_public.items
  SET wear_count = wear_count + 1,
      last_worn_date = p_date,
      updated_at = NOW()
  WHERE id = ANY(p_item_ids);

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$;
