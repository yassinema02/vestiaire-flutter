-- Add 'steal_look' as a valid outfit source
ALTER TABLE app_public.outfits DROP CONSTRAINT IF EXISTS outfits_source_check;
ALTER TABLE app_public.outfits ADD CONSTRAINT outfits_source_check CHECK (source IN ('ai', 'manual', 'steal_look'));
COMMENT ON COLUMN app_public.outfits.source IS 'How the outfit was created: ai (generated), manual (user-built), steal_look (inspired by friend''s post)';
