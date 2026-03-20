-- Migration 033: Add creation_method and extraction_job_id to items table
--
-- Tracks how items were created (manual upload vs AI extraction)
-- and links extraction-created items back to their source extraction job.
--
-- Story 10.3: Extraction Progress & Review Flow (FR-EXT-09)

ALTER TABLE app_public.items
  ADD COLUMN IF NOT EXISTS creation_method TEXT
    CHECK (creation_method IN ('manual', 'ai_extraction'))
    DEFAULT 'manual';

ALTER TABLE app_public.items
  ADD COLUMN IF NOT EXISTS extraction_job_id UUID
    REFERENCES app_public.wardrobe_extraction_jobs(id)
    ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_items_extraction_job_id
  ON app_public.items (extraction_job_id)
  WHERE extraction_job_id IS NOT NULL;
