-- Migration 008: Add categorization columns to items table
-- Story 2.3: AI Item Categorization & Tagging
--
-- Adds structured metadata fields for AI-extracted clothing categorization.
-- All fields are nullable for backward compatibility. Categorization is async
-- and fields are populated after Gemini vision analysis completes.

-- Category: primary clothing type
-- Valid values: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other
ALTER TABLE app_public.items
  ADD COLUMN category TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.category IS
  'Primary clothing category. Valid: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other';

-- Color: primary color of the item
-- Valid values: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown
ALTER TABLE app_public.items
  ADD COLUMN color TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.color IS
  'Primary color. Valid: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown';

-- Secondary colors: additional colors present in the item
ALTER TABLE app_public.items
  ADD COLUMN secondary_colors TEXT[] DEFAULT NULL;

COMMENT ON COLUMN app_public.items.secondary_colors IS
  'Additional colors from the same color taxonomy as primary color';

-- Pattern: visual pattern of the item
-- Valid values: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other
ALTER TABLE app_public.items
  ADD COLUMN pattern TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.pattern IS
  'Visual pattern. Valid: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other';

-- Material: fabric/material of the item
-- Valid values: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown
ALTER TABLE app_public.items
  ADD COLUMN material TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.material IS
  'Fabric/material. Valid: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown';

-- Style: fashion style classification
-- Valid values: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other
ALTER TABLE app_public.items
  ADD COLUMN style TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.style IS
  'Fashion style. Valid: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other';

-- Season: suitable seasons (array)
-- Valid values: spring, summer, fall, winter, all
ALTER TABLE app_public.items
  ADD COLUMN season TEXT[] DEFAULT NULL;

COMMENT ON COLUMN app_public.items.season IS
  'Suitable seasons (array). Valid values: spring, summer, fall, winter, all';

-- Occasion: suitable occasions (array)
-- Valid values: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge
ALTER TABLE app_public.items
  ADD COLUMN occasion TEXT[] DEFAULT NULL;

COMMENT ON COLUMN app_public.items.occasion IS
  'Suitable occasions (array). Valid values: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge';

-- Categorization status: tracks the async categorization pipeline state
-- Valid values: pending, completed, failed
ALTER TABLE app_public.items
  ADD COLUMN categorization_status TEXT DEFAULT NULL
  CHECK (categorization_status IN ('pending', 'completed', 'failed'));

COMMENT ON COLUMN app_public.items.categorization_status IS
  'AI categorization pipeline status. Valid: pending, completed, failed. NULL means not yet requested.';

-- Index on category for future filtering (Story 2.5)
CREATE INDEX idx_items_category ON app_public.items (category) WHERE category IS NOT NULL;

-- Check constraints for category and color against taxonomy
ALTER TABLE app_public.items
  ADD CONSTRAINT items_category_check
  CHECK (category IS NULL OR category IN (
    'tops', 'bottoms', 'dresses', 'outerwear', 'shoes', 'bags', 'accessories',
    'activewear', 'swimwear', 'underwear', 'sleepwear', 'suits', 'other'
  ));

ALTER TABLE app_public.items
  ADD CONSTRAINT items_color_check
  CHECK (color IS NULL OR color IN (
    'black', 'white', 'gray', 'navy', 'blue', 'light-blue', 'red', 'burgundy',
    'pink', 'orange', 'yellow', 'green', 'olive', 'teal', 'purple', 'beige',
    'brown', 'tan', 'cream', 'gold', 'silver', 'multicolor', 'unknown'
  ));
