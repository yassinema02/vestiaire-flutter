-- Migration 031: Extraction job photos table
--
-- Tracks individual photos within a wardrobe extraction job.
-- Each photo is uploaded and later processed for item detection.
--
-- Story 10.1: Bulk Photo Gallery Selection (FR-EXT-01, FR-EXT-08)

CREATE TABLE app_public.extraction_job_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES app_public.wardrobe_extraction_jobs(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  original_filename TEXT,
  status TEXT NOT NULL CHECK (status IN ('uploaded', 'processing', 'completed', 'failed')) DEFAULT 'uploaded',
  items_found INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_extraction_job_photos_job_id
  ON app_public.extraction_job_photos (job_id);
