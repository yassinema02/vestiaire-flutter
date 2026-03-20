begin;

create table if not exists app_public.items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references app_public.profiles(id) on delete cascade,
  photo_url text not null,
  name text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists items_profile_id_idx
  on app_public.items (profile_id);

create index if not exists items_created_at_idx
  on app_public.items (created_at desc);

drop trigger if exists set_items_updated_at on app_public.items;
create trigger set_items_updated_at
before update on app_public.items
for each row
execute function app_private.set_updated_at();

commit;
