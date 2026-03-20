-- Migration 029: Social notification preference from boolean to string
--
-- Migrates notification_preferences.social from boolean (true/false)
-- to string ("all"/"morning"/"off") for three-option social notification mode.
--
-- Backward compatibility:
--   true  -> "all"  (receive all post notifications)
--   false -> "off"  (no social notifications)
--   NULL/missing -> "all" (default for new and existing users)
--
-- Story 9.6: Social Notification Preferences (FR-NTF-01, FR-NTF-02)

UPDATE app_public.profiles
SET notification_preferences = notification_preferences ||
  CASE
    WHEN (notification_preferences->>'social')::text = 'true' THEN '{"social":"all"}'::jsonb
    WHEN (notification_preferences->>'social')::text = 'false' THEN '{"social":"off"}'::jsonb
    ELSE '{"social":"all"}'::jsonb
  END
WHERE notification_preferences ? 'social';

ALTER TABLE app_public.profiles
ALTER COLUMN notification_preferences
SET DEFAULT '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":"all"}'::jsonb;
