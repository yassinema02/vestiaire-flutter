-- Migration 006: Add background removal columns to items table
-- Story 2.2: AI Background Removal & Upload

ALTER TABLE app_public.items
  ADD COLUMN original_photo_url TEXT,
  ADD COLUMN bg_removal_status TEXT CHECK (bg_removal_status IN ('pending', 'completed', 'failed')) DEFAULT NULL;

COMMENT ON COLUMN app_public.items.original_photo_url IS 'Preserves the original uploaded image URL before background removal';
COMMENT ON COLUMN app_public.items.bg_removal_status IS 'Status of AI background removal: pending, completed, failed, or NULL (not attempted)';
