-- =====================================================
-- REV18.1.1 PRODUCTION MASTER
-- DEEL 2 - PROPERTY & DEVICE ENGINE
-- =====================================================

-- =====================================================
-- ENUMS
-- =====================================================

create type device_status as enum (
  'online',
  'offline',
  'unknown'
);

create type device_command_status as enum (
  'pending',
  'queued',
  'sent',
  'acknowledged',
  'failed',
  'cancelled'
);

create type automation_status as enum (
  'active',
  'paused',
  'disabled'
);

create type automation_trigger_type as enum (
  'device_event',
  'schedule',
  'reservation',
  'manual'
);

-- =====================================================
-- ACCOMMODATIONS (PROPERTIES)
-- =====================================================

create table accommodations (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  name text not null,
  address text,
  city text,
  country text,

  timezone text not null default 'UTC',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_accommodations_org on accommodations(organization_id);

create trigger trg_accommodations_updated_at
before update on accommodations
for each row execute function set_updated_at();

-- =====================================================
-- ROOMS
-- =====================================================

create table rooms (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid not null references accommodations(id) on delete cascade,

  name text not null,
  type text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_rooms_org on rooms(organization_id);
create index idx_rooms_property on rooms(accommodation_id);

create trigger trg_rooms_updated_at
before update on rooms
for each row execute function set_updated_at();

-- =====================================================
-- DEVICES (Aqara / Shelly / TTLock / P100 / M3 / M2)
-- =====================================================

create table devices (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid not null references accommodations(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,

  provider integration_provider not null,
  external_device_id text not null,

  name text not null,
  device_type text not null,

  status device_status not null default 'unknown',

  last_seen_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (provider, external_device_id)
);

create index idx_devices_org on devices(organization_id);
create index idx_devices_property on devices(accommodation_id);
create index idx_devices_room on devices(room_id);
create index idx_devices_provider on devices(provider);

create trigger trg_devices_updated_at
before update on devices
for each row execute function set_updated_at();

-- =====================================================
-- DEVICE STATES (CACHE LAYER)
-- =====================================================

create table device_states (
  id uuid primary key default gen_random_uuid(),

  device_id uuid not null references devices(id) on delete cascade,

  state jsonb not null default '{}'::jsonb,
  battery_level int,
  signal_strength int,

  updated_at timestamptz not null default now()
);

create index idx_device_states_device on device_states(device_id);

-- =====================================================
-- DEVICE COMMANDS (QUEUE SYSTEM)
-- =====================================================

create table device_commands (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  device_id uuid not null references devices(id) on delete cascade,

  command text not null,
  payload jsonb not null default '{}'::jsonb,

  status device_command_status not null default 'pending',

  retry_count int not null default 0,
  max_retries int not null default 3,

  last_attempt_at timestamptz,
  response_payload jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_device_commands_device on device_commands(device_id);
create index idx_device_commands_status on device_commands(status);
create index idx_device_commands_org on device_commands(organization_id);

create trigger trg_device_commands_updated_at
before update on device_commands
for each row execute function set_updated_at();

-- =====================================================
-- AUTOMATIONS
-- =====================================================

create table automations (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid references accommodations(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,

  name text not null,

  trigger_type automation_trigger_type not null,
  trigger_config jsonb not null default '{}'::jsonb,

  action_config jsonb not null default '{}'::jsonb,

  status automation_status not null default 'active',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_automations_org on automations(organization_id);
create index idx_automations_property on automations(accommodation_id);

create trigger trg_automations_updated_at
before update on automations
for each row execute function set_updated_at();

-- =====================================================
-- AUTOMATION RUNS (DEBUG + SUPPORT)
-- =====================================================

create table automation_runs (
  id uuid primary key default gen_random_uuid(),

  automation_id uuid not null references automations(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  started_at timestamptz not null default now(),
  finished_at timestamptz,
  duration_ms int,

  status text not null, -- success / failed / skipped

  trigger_source text,
  error_message text,

  execution_log jsonb not null default '{}'::jsonb
);

create index idx_automation_runs_automation on automation_runs(automation_id);
create index idx_automation_runs_org on automation_runs(organization_id);

-- =====================================================
-- DEVICE EVENTS (EVENT STREAM)
-- =====================================================

create table device_events (
  id uuid primary key default gen_random_uuid(),

  device_id uuid not null references devices(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  event_type text not null,
  payload jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index idx_device_events_device on device_events(device_id);
create index idx_device_events_org on device_events(organization_id);
create index idx_device_events_created on device_events(created_at);

-- =====================================================
-- EVENT BUS (SYSTEM WIDE)
-- =====================================================

create table event_bus (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id) on delete cascade,

  event_type text not null,
  source text not null,

  payload jsonb not null default '{}'::jsonb,

  processed boolean not null default false,

  created_at timestamptz not null default now()
);

create index idx_event_bus_org on event_bus(organization_id);
create index idx_event_bus_type on event_bus(event_type);
create index idx_event_bus_processed on event_bus(processed);

-- =====================================================
-- INTEGRATION ENGINE BASE (minimal in part 2)
-- =====================================================

create table integrations (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  provider integration_provider not null,
  name text not null,

  status text not null default 'active',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_integrations_org on integrations(organization_id);

create trigger trg_integrations_updated_at
before update on integrations
for each row execute function set_updated_at();

-- =====================================================
-- RLS ENABLEMENT
-- =====================================================

alter table accommodations enable row level security;
alter table rooms enable row level security;
alter table devices enable row level security;
alter table device_states enable row level security;
alter table device_commands enable row level security;
alter table automations enable row level security;
alter table automation_runs enable row level security;
alter table device_events enable row level security;
alter table event_bus enable row level security;
alter table integrations enable row level security;

-- =====================================================
-- RLS: ORGANIZATION ISOLATION PATTERN
-- =====================================================

create policy "accommodations_org"
on accommodations
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = accommodations.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "rooms_org"
on rooms
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = rooms.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "devices_org"
on devices
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = devices.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "automations_org"
on automations
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = automations.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "integrations_org"
on integrations
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = integrations.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- STRICT SYSTEM TABLES (WRITE ONLY VIA SERVICE ROLE)

create policy "device_commands_service_only"
on device_commands
for all
using (false);

create policy "event_bus_service_only"
on event_bus
for all
using (false);

create policy "device_events_service_only"
on device_events
for all
using (false);