-- Migration 036: Add event_reminders to notification_preferences default and backfill existing profiles
-- Story 12.3: Formal Event Reminders (FR-EVT-07, FR-EVT-08)

-- Update the default for new profiles to include event_reminders: true
ALTER TABLE app_public.profiles
  ALTER COLUMN notification_preferences
  SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all","event_reminders":true}'::jsonb;

-- Backfill existing profiles that don't have the event_reminders key
UPDATE app_public.profiles
  SET notification_preferences = notification_preferences || '{"event_reminders":true}'::jsonb
  WHERE NOT (notification_preferences ? 'event_reminders');
