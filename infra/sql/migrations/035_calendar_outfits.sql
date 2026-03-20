-- Migration 035: Create calendar_outfits table
-- Story 12.2: Outfit Scheduling (Plan Week)
-- FR-EVT-05: Scheduled outfits stored in calendar_outfits with event association
-- FR-EVT-06: Users can edit or remove scheduled outfits

begin;

-- 1. calendar_outfits table
CREATE TABLE IF NOT EXISTS app_public.calendar_outfits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  outfit_id UUID NOT NULL REFERENCES app_public.outfits(id) ON DELETE CASCADE,
  calendar_event_id UUID REFERENCES app_public.calendar_events(id) ON DELETE SET NULL,
  scheduled_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RLS policy (same pattern as outfits_user_policy)
ALTER TABLE app_public.calendar_outfits ENABLE ROW LEVEL SECURITY;

CREATE POLICY calendar_outfits_user_policy ON app_public.calendar_outfits
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- 3. Unique constraints using partial indexes to handle NULL calendar_event_id
-- One default outfit per day (when no specific event)
CREATE UNIQUE INDEX idx_calendar_outfits_unique_day
  ON app_public.calendar_outfits(profile_id, scheduled_date)
  WHERE calendar_event_id IS NULL;

-- One outfit per event per day
CREATE UNIQUE INDEX idx_calendar_outfits_unique_event
  ON app_public.calendar_outfits(profile_id, scheduled_date, calendar_event_id)
  WHERE calendar_event_id IS NOT NULL;

-- 4. Index for efficient date-range queries
CREATE INDEX idx_calendar_outfits_profile_date
  ON app_public.calendar_outfits(profile_id, scheduled_date);

-- 5. set_updated_at trigger (reuses existing function)
CREATE TRIGGER set_calendar_outfits_updated_at
  BEFORE UPDATE ON app_public.calendar_outfits
  FOR EACH ROW
  EXECUTE FUNCTION app_private.set_updated_at();

commit;
