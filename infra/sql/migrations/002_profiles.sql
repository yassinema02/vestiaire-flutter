begin;

create table if not exists app_public.profiles (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null unique,
  email text,
  auth_provider text not null,
  email_verified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_auth_provider_check check (char_length(auth_provider) > 0)
);

create index if not exists profiles_created_at_idx
  on app_public.profiles (created_at desc);

commit;
