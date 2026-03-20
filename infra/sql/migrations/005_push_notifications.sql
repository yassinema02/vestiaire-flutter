begin;

-- Add push notification fields to profiles table.
-- push_token: stores the FCM device token for sending push notifications.
-- notification_preferences: JSONB with per-category boolean toggles.

alter table app_public.profiles
  add column if not exists push_token text,
  add column if not exists notification_preferences jsonb not null
    default '{"outfit_reminders":true,"wear_logging":true,"analytics":true,"social":true}'::jsonb;

comment on column app_public.profiles.push_token is
  'FCM device token for push notification delivery. Null when user has not granted permission or has signed out.';

comment on column app_public.profiles.notification_preferences is
  'Per-category notification toggles as JSONB. Keys: outfit_reminders, wear_logging, analytics, social. Values: boolean.';

commit;
