-- Migration 010: Add indexes for wardrobe grid filtering (Story 2.5)
--
-- B-tree indexes for scalar filter columns (equality lookups).
-- GIN indexes for array columns (ANY() lookups).
-- Category index may already exist from Story 2.3; CREATE INDEX IF NOT EXISTS is used.

CREATE INDEX IF NOT EXISTS idx_items_category ON app_public.items(category);
CREATE INDEX IF NOT EXISTS idx_items_color ON app_public.items(color);
CREATE INDEX IF NOT EXISTS idx_items_brand ON app_public.items(brand);
CREATE INDEX IF NOT EXISTS idx_items_season ON app_public.items USING gin(season);
CREATE INDEX IF NOT EXISTS idx_items_occasion ON app_public.items USING gin(occasion);
