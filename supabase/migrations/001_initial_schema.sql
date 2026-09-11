-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- Trips table
create table trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  destination text not null,
  start_date date not null,
  end_date date not null,
  mode text not null check (mode in ('structured', 'unstructured')),
  home_base_name text,
  home_base_address text,
  home_base_lat float8,
  home_base_lng float8,
  preferences jsonb,
  status text not null default 'active' check (status in ('active', 'archived')),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Trip days table (structured mode)
create table trip_days (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  date date not null,
  day_number int not null,
  notes text,
  unique (trip_id, date),
  unique (trip_id, day_number)
);

-- Activities table
create table activities (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips(id) on delete cascade,
  trip_day_id uuid references trip_days(id) on delete set null,
  name text not null,
  description text,
  category text not null check (category in ('restaurant', 'attraction', 'shopping', 'museum', 'nightlife', 'other')),
  area text,
  latitude float8,
  longitude float8,
  address text,
  start_time time,
  end_time time,
  duration_min int,
  sort_order int not null default 0,
  source text not null default 'manual' check (source in ('manual', 'ai_generated', 'places_api')),
  place_id text,
  status text not null default 'planned' check (status in ('planned', 'visited', 'skipped')),
  notes text,
  created_at timestamptz not null default now()
);

-- Auto-update updated_at on trips
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trips_updated_at
  before update on trips
  for each row execute function update_updated_at();

-- Row Level Security
alter table trips enable row level security;
alter table trip_days enable row level security;
alter table activities enable row level security;

-- Trips: users can only access their own
create policy "Users can view own trips"
  on trips for select using (auth.uid() = user_id);
create policy "Users can create own trips"
  on trips for insert with check (auth.uid() = user_id);
create policy "Users can update own trips"
  on trips for update using (auth.uid() = user_id);
create policy "Users can delete own trips"
  on trips for delete using (auth.uid() = user_id);

-- Trip days: access through trip ownership
create policy "Users can view own trip days"
  on trip_days for select using (
    exists (select 1 from trips where trips.id = trip_days.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can create own trip days"
  on trip_days for insert with check (
    exists (select 1 from trips where trips.id = trip_days.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can update own trip days"
  on trip_days for update using (
    exists (select 1 from trips where trips.id = trip_days.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can delete own trip days"
  on trip_days for delete using (
    exists (select 1 from trips where trips.id = trip_days.trip_id and trips.user_id = auth.uid())
  );

-- Activities: access through trip ownership
create policy "Users can view own activities"
  on activities for select using (
    exists (select 1 from trips where trips.id = activities.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can create own activities"
  on activities for insert with check (
    exists (select 1 from trips where trips.id = activities.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can update own activities"
  on activities for update using (
    exists (select 1 from trips where trips.id = activities.trip_id and trips.user_id = auth.uid())
  );
create policy "Users can delete own activities"
  on activities for delete using (
    exists (select 1 from trips where trips.id = activities.trip_id and trips.user_id = auth.uid())
  );

-- Indexes for common queries
create index idx_trips_user_id on trips(user_id);
create index idx_trips_status on trips(user_id, status);
create index idx_trip_days_trip_id on trip_days(trip_id);
create index idx_activities_trip_id on activities(trip_id);
create index idx_activities_trip_day_id on activities(trip_day_id);
