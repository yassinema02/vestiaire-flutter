-- Migration 009: Add optional metadata columns to items table
-- Story 2.4: Manual Metadata Editing & Item Creation
--
-- Adds brand, purchase_price, purchase_date, and currency columns.
-- All fields are nullable for backward compatibility.

-- Brand: the clothing brand/label
ALTER TABLE app_public.items
  ADD COLUMN brand TEXT DEFAULT NULL;

COMMENT ON COLUMN app_public.items.brand IS
  'Brand/label name for the clothing item. Max 100 characters, enforced at application level.';

-- Purchase price: how much the item cost
ALTER TABLE app_public.items
  ADD COLUMN purchase_price NUMERIC(10,2) DEFAULT NULL;

COMMENT ON COLUMN app_public.items.purchase_price IS
  'Purchase price of the item. Must be >= 0 when not null.';

ALTER TABLE app_public.items
  ADD CONSTRAINT items_purchase_price_check
  CHECK (purchase_price IS NULL OR purchase_price >= 0);

-- Purchase date: when the item was purchased
ALTER TABLE app_public.items
  ADD COLUMN purchase_date DATE DEFAULT NULL;

COMMENT ON COLUMN app_public.items.purchase_date IS
  'Date when the item was purchased.';

-- Currency: the currency for the purchase price
ALTER TABLE app_public.items
  ADD COLUMN currency TEXT DEFAULT 'GBP';

COMMENT ON COLUMN app_public.items.currency IS
  'Currency for the purchase price. Valid: GBP, EUR, USD. Defaults to GBP.';

ALTER TABLE app_public.items
  ADD CONSTRAINT items_currency_check
  CHECK (currency IS NULL OR currency IN ('GBP', 'EUR', 'USD'));
