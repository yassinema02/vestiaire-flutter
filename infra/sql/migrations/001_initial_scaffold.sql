begin;

create extension if not exists pgcrypto;

create schema if not exists app_public;
create schema if not exists app_private;

create table if not exists app_public.bootstrap_state (
  id integer primary key check (id = 1),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  notes text not null default 'Bootstrap baseline created by Story 1.1'
);

insert into app_public.bootstrap_state (id)
values (1)
on conflict (id) do nothing;

commit;
