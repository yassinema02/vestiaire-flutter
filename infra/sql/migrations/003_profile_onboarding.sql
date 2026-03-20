begin;

alter table app_public.profiles
  add column if not exists display_name text,
  add column if not exists photo_url text,
  add column if not exists style_preferences text[] not null default '{}',
  add column if not exists onboarding_completed_at timestamptz;

comment on column app_public.profiles.display_name is
  'User-chosen display name shown in the app UI.';
comment on column app_public.profiles.photo_url is
  'URL to the user profile photo stored in Cloud Storage.';
comment on column app_public.profiles.style_preferences is
  'Array of style tags selected during onboarding (e.g. casual, streetwear, minimalist).';
comment on column app_public.profiles.onboarding_completed_at is
  'Timestamp when the user completed or skipped the onboarding flow. NULL means onboarding not yet done.';

commit;
