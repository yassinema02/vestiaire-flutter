-- Migration 032: Extraction job items table
--
-- Stores individual clothing items detected within extraction job photos.
-- Each photo can produce 0-5 items via Gemini multi-item detection.
-- Items are staged here for user review before promotion to the main items table.
--
-- Story 10.2: Bulk Extraction Processing (FR-EXT-02, FR-EXT-09)

CREATE TABLE app_public.extraction_job_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES app_public.wardrobe_extraction_jobs(id) ON DELETE CASCADE,
  photo_id UUID NOT NULL REFERENCES app_public.extraction_job_photos(id) ON DELETE CASCADE,
  item_index INTEGER NOT NULL CHECK (item_index >= 0 AND item_index <= 4),
  photo_url TEXT NOT NULL,
  original_crop_url TEXT,
  category TEXT,
  color TEXT,
  secondary_colors TEXT[],
  pattern TEXT,
  material TEXT,
  style TEXT,
  season TEXT[],
  occasion TEXT[],
  bg_removal_status TEXT CHECK (bg_removal_status IN ('pending', 'completed', 'failed')) DEFAULT 'pending',
  categorization_status TEXT CHECK (categorization_status IN ('pending', 'completed', 'failed')) DEFAULT 'pending',
  detection_confidence REAL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_extraction_job_items_job_id
  ON app_public.extraction_job_items (job_id);

CREATE INDEX idx_extraction_job_items_photo_id
  ON app_public.extraction_job_items (photo_id);
