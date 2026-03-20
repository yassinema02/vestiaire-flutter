-- Migration 034: Add 'confirmed' to extraction job status constraint
--
-- Allows tracking that the user has reviewed and confirmed extraction results.
-- The 'confirmed' status is set after the user reviews extracted items and
-- taps "Add to Wardrobe" (or discards all items).
--
-- Story 10.3: Extraction Progress & Review Flow (FR-EXT-05)

ALTER TABLE app_public.wardrobe_extraction_jobs
  DROP CONSTRAINT IF EXISTS wardrobe_extraction_jobs_status_check;

ALTER TABLE app_public.wardrobe_extraction_jobs
  ADD CONSTRAINT wardrobe_extraction_jobs_status_check
    CHECK (status IN ('uploading', 'processing', 'completed', 'failed', 'partial', 'confirmed'));
