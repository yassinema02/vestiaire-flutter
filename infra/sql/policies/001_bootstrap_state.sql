begin;

alter table app_public.bootstrap_state enable row level security;

drop policy if exists bootstrap_state_no_access_select on app_public.bootstrap_state;
create policy bootstrap_state_no_access_select
  on app_public.bootstrap_state
  for select
  using (false);

drop policy if exists bootstrap_state_no_access_insert on app_public.bootstrap_state;
create policy bootstrap_state_no_access_insert
  on app_public.bootstrap_state
  for insert
  with check (false);

drop policy if exists bootstrap_state_no_access_update on app_public.bootstrap_state;
create policy bootstrap_state_no_access_update
  on app_public.bootstrap_state
  for update
  using (false)
  with check (false);

drop policy if exists bootstrap_state_no_access_delete on app_public.bootstrap_state;
create policy bootstrap_state_no_access_delete
  on app_public.bootstrap_state
  for delete
  using (false);

drop trigger if exists set_bootstrap_state_updated_at on app_public.bootstrap_state;
create trigger set_bootstrap_state_updated_at
before update on app_public.bootstrap_state
for each row
execute function app_private.set_updated_at();

commit;
