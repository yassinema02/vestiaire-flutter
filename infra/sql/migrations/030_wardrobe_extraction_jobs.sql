-- Migration 030: Wardrobe extraction jobs table
--
-- Tracks bulk photo extraction jobs for AI wardrobe import.
-- Each job represents a batch of photos submitted for item extraction.
--
-- Story 10.1: Bulk Photo Gallery Selection (FR-EXT-01, FR-EXT-08)

CREATE TABLE app_public.wardrobe_extraction_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('uploading', 'processing', 'completed', 'failed', 'partial')) DEFAULT 'uploading',
  total_photos INTEGER NOT NULL,
  uploaded_photos INTEGER NOT NULL DEFAULT 0,
  processed_photos INTEGER NOT NULL DEFAULT 0,
  total_items_found INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_extraction_jobs_profile_created
  ON app_public.wardrobe_extraction_jobs (profile_id, created_at DESC);
