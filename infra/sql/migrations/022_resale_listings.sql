-- Migration 022: Resale Listings table and resale_status column on items
-- Story 7.3: AI Resale Listing Generation
-- FR-RSL-02, FR-RSL-03, FR-RSL-04

-- 1. Create resale_listings table
CREATE TABLE IF NOT EXISTS app_public.resale_listings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  condition_estimate TEXT NOT NULL CHECK (condition_estimate IN ('New', 'Like New', 'Good', 'Fair')),
  hashtags TEXT[] DEFAULT '{}',
  platform TEXT DEFAULT 'general',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE app_public.resale_listings ENABLE ROW LEVEL SECURITY;

-- RLS policy: users can only access their own resale listings
CREATE POLICY resale_listings_user_policy ON app_public.resale_listings
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Indexes for resale_listings
CREATE INDEX idx_resale_listings_profile ON app_public.resale_listings(profile_id, created_at DESC);
CREATE INDEX idx_resale_listings_item ON app_public.resale_listings(item_id);

-- 2. Add resale_status column to items table
-- Tracks resale lifecycle: NULL (not for sale), listed (generated listing), sold (item sold), donated (item donated). FR-RSL-04
ALTER TABLE app_public.items ADD COLUMN IF NOT EXISTS resale_status TEXT CHECK (resale_status IN ('listed', 'sold', 'donated')) DEFAULT NULL;

-- 3. Index on resale_status for future filtering
CREATE INDEX idx_items_resale_status ON app_public.items(resale_status) WHERE resale_status IS NOT NULL;
