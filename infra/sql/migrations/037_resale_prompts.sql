-- Migration 037: Resale prompts table and notification_preferences update.
-- Story 13.2: Monthly Resale Prompts. FR-RSL-01, FR-RSL-05, FR-RSL-06

-- Create resale_prompts table
CREATE TABLE app_public.resale_prompts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  estimated_price NUMERIC(10,2) NOT NULL DEFAULT 10,
  estimated_currency TEXT NOT NULL DEFAULT 'GBP',
  action TEXT CHECK (action IN ('accepted', 'dismissed')),
  dismissed_until DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS policy
ALTER TABLE app_public.resale_prompts ENABLE ROW LEVEL SECURITY;

CREATE POLICY resale_prompts_user_policy ON app_public.resale_prompts
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Indexes
CREATE INDEX idx_resale_prompts_profile ON app_public.resale_prompts(profile_id, created_at DESC);
CREATE INDEX idx_resale_prompts_item ON app_public.resale_prompts(item_id);
CREATE INDEX idx_resale_prompts_pending ON app_public.resale_prompts(profile_id) WHERE action IS NULL;

-- Update notification_preferences default to include resale_prompts
ALTER TABLE app_public.profiles
  ALTER COLUMN notification_preferences
  SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all","resale_prompts":true}'::jsonb;

-- Data migration: add resale_prompts key to existing profiles
UPDATE app_public.profiles
  SET notification_preferences = notification_preferences || '{"resale_prompts": true}'::jsonb
  WHERE NOT (notification_preferences ? 'resale_prompts');
