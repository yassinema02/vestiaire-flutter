-- Migration 024: Shopping Scans table
-- Story 8.1: Product URL Scraping
--
-- Stores shopping scan results from URL scraping and screenshot analysis.
-- This table serves the entire Epic 8 Shopping Assistant lifecycle:
-- - Story 8.1: URL scraping populates core product fields + AI vision metadata
-- - Story 8.2: Screenshot upload populates the same fields via image analysis
-- - Story 8.3: User review/edit of extracted data
-- - Story 8.4: compatibility_score populated by wardrobe matching
-- - Story 8.5: insights populated by AI analysis, wishlisted by user action

CREATE TABLE IF NOT EXISTS app_public.shopping_scans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Owner reference (CASCADE on profile deletion)
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,

  -- Source URL (NULL for screenshot-based scans)
  url TEXT,

  -- Scan type: 'url' (Story 8.1) or 'screenshot' (Story 8.2)
  scan_type TEXT NOT NULL CHECK (scan_type IN ('url', 'screenshot')) DEFAULT 'url',

  -- Core product metadata (extracted from OG tags, JSON-LD, or AI)
  product_name TEXT,
  brand TEXT,
  price NUMERIC(10,2),
  currency TEXT DEFAULT 'GBP',
  image_url TEXT,

  -- Wardrobe-compatible taxonomy fields (same as items table)
  -- Populated by Gemini vision analysis on the product image
  category TEXT,
  color TEXT,
  secondary_colors TEXT[],
  pattern TEXT,
  material TEXT,
  style TEXT,
  season TEXT[],
  occasion TEXT[],
  formality_score INTEGER CHECK (formality_score BETWEEN 1 AND 10),

  -- Extraction provenance: 'og_tags', 'json_ld', 'ai_fallback', or combination
  extraction_method TEXT,

  -- Compatibility score (0-100), populated by Story 8.4
  compatibility_score INTEGER CHECK (compatibility_score BETWEEN 0 AND 100),

  -- AI insights JSONB, populated by Story 8.5
  insights JSONB,

  -- Wishlist flag, managed by Story 8.5
  wishlisted BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policy: users can only access their own scans
ALTER TABLE app_public.shopping_scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY shopping_scans_user_policy
  ON app_public.shopping_scans
  FOR ALL
  USING (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

-- Performance index for listing scans by user, newest first
CREATE INDEX idx_shopping_scans_profile
  ON app_public.shopping_scans(profile_id, created_at DESC);
