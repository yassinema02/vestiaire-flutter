-- Migration 011: Add is_favorite column to items table
-- Story 2.6: Item Detail View & Management (FR-WRD-13)

ALTER TABLE app_public.items
  ADD COLUMN is_favorite BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN app_public.items.is_favorite IS
  'User-toggled favorite status for quick access filtering';

-- Partial index for efficient "show favorites" filtering (future story).
-- Only indexes rows where is_favorite = TRUE, optimal for sparse favorites.
CREATE INDEX idx_items_is_favorite
  ON app_public.items(is_favorite)
  WHERE is_favorite = TRUE;
