-- Migration 012: Create calendar_events table
-- Story 3.5: Calendar Event Fetching & Classification (FR-CTX-09, FR-CTX-10, FR-CTX-11)

begin;

create table if not exists app_public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references app_public.profiles(id) on delete cascade,
  source_calendar_id text not null,
  source_event_id text not null,
  title text not null,
  description text,
  location text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  all_day boolean default false,
  event_type text not null default 'casual'
    check (event_type in ('work', 'social', 'active', 'formal', 'casual')),
  formality_score integer not null default 2
    check (formality_score between 1 and 10),
  classification_source text not null default 'keyword'
    check (classification_source in ('keyword', 'ai', 'user')),
  user_override boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  constraint calendar_events_unique_source
    unique (profile_id, source_calendar_id, source_event_id)
);

-- RLS policy: users can only access their own calendar events
alter table app_public.calendar_events enable row level security;

create policy calendar_events_user_policy
  on app_public.calendar_events
  for all
  using (
    profile_id in (
      select id from app_public.profiles
      where firebase_uid = current_setting('app.current_user_id', true)
    )
  );

-- Index for efficient date-range queries
create index idx_calendar_events_profile_start
  on app_public.calendar_events(profile_id, start_time);

-- Reuse existing set_updated_at trigger function
drop trigger if exists set_calendar_events_updated_at on app_public.calendar_events;
create trigger set_calendar_events_updated_at
  before update on app_public.calendar_events
  for each row
  execute function app_private.set_updated_at();

commit;
