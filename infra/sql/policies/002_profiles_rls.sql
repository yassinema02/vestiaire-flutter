begin;

alter table app_public.profiles enable row level security;
alter table app_public.profiles force row level security;

drop policy if exists profiles_self_select on app_public.profiles;
create policy profiles_self_select
  on app_public.profiles
  for select
  using (firebase_uid = current_setting('app.current_user_id', true));

drop policy if exists profiles_self_insert on app_public.profiles;
create policy profiles_self_insert
  on app_public.profiles
  for insert
  with check (firebase_uid = current_setting('app.current_user_id', true));

drop policy if exists profiles_self_update on app_public.profiles;
create policy profiles_self_update
  on app_public.profiles
  for update
  using (firebase_uid = current_setting('app.current_user_id', true))
  with check (firebase_uid = current_setting('app.current_user_id', true));

drop policy if exists profiles_self_delete on app_public.profiles;
create policy profiles_self_delete
  on app_public.profiles
  for delete
  using (firebase_uid = current_setting('app.current_user_id', true));

drop trigger if exists set_profiles_updated_at on app_public.profiles;
create trigger set_profiles_updated_at
before update on app_public.profiles
for each row
execute function app_private.set_updated_at();

commit;
