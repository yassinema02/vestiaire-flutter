begin;

alter table app_public.items enable row level security;
alter table app_public.items force row level security;

drop policy if exists items_self_select on app_public.items;
create policy items_self_select
  on app_public.items
  for select
  using (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  );

drop policy if exists items_self_insert on app_public.items;
create policy items_self_insert
  on app_public.items
  for insert
  with check (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  );

drop policy if exists items_self_update on app_public.items;
create policy items_self_update
  on app_public.items
  for update
  using (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  )
  with check (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  );

drop policy if exists items_self_delete on app_public.items;
create policy items_self_delete
  on app_public.items
  for delete
  using (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  );

commit;
