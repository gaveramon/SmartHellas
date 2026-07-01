-- =====================================================
-- REV18.1.1 PRODUCTION MASTER
-- DEEL 4 - BOOKING & LOCK ENGINE
-- =====================================================

-- =====================================================
-- ENUMS
-- =====================================================

create type reservation_source as enum (
  'airbnb',
  'booking_com',
  'beds24',
  'manual'
);

create type reservation_status as enum (
  'confirmed',
  'cancelled',
  'checked_in',
  'checked_out',
  'blocked'
);

create type lock_code_status as enum (
  'active',
  'expired',
  'revoked',
  'pending'
);

-- =====================================================
-- RESERVATIONS
-- =====================================================

create table reservations (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid not null references accommodations(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,

  external_reservation_id text,
  source reservation_source not null,

  guest_name text,
  guest_email text,
  guest_phone text,

  check_in_date date not null,
  check_out_date date not null,

  status reservation_status not null default 'confirmed',

  number_of_guests int default 1,

  raw_payload jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (organization_id, external_reservation_id)
);

create index idx_reservations_org on reservations(organization_id);
create index idx_reservations_property on reservations(accommodation_id);
create index idx_reservations_room on reservations(room_id);
create index idx_reservations_dates on reservations(check_in_date, check_out_date);
create index idx_reservations_status on reservations(status);

create trigger trg_reservations_updated_at
before update on reservations
for each row execute function set_updated_at();

-- =====================================================
-- RESERVATION GUESTS (EXPANSION)
-- =====================================================

create table reservation_guests (
  id uuid primary key default gen_random_uuid(),

  reservation_id uuid not null references reservations(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  name text,
  email text,
  phone text,

  is_primary boolean not null default false,

  created_at timestamptz not null default now()
);

create index idx_reservation_guests_reservation on reservation_guests(reservation_id);
create index idx_reservation_guests_org on reservation_guests(organization_id);

-- =====================================================
-- LOCK DEVICES MAPPING (TTLOCK / SMART LOCK ABSTRACTION)
-- =====================================================

create table lock_devices (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid not null references accommodations(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,

  device_id uuid references devices(id) on delete set null,

  provider integration_provider not null default 'ttlock',

  external_lock_id text not null,

  name text not null,

  keypad_code_length int not null default 6,

  timezone text not null default 'UTC',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (provider, external_lock_id)
);

create index idx_lock_devices_org on lock_devices(organization_id);
create index idx_lock_devices_property on lock_devices(accommodation_id);

create trigger trg_lock_devices_updated_at
before update on lock_devices
for each row execute function set_updated_at();

-- =====================================================
-- LOCK CODES (CORE AUTOMATION OUTPUT)
-- =====================================================

create table lock_codes (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  accommodation_id uuid not null references accommodations(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,

  reservation_id uuid references reservations(id) on delete cascade,
  lock_device_id uuid not null references lock_devices(id) on delete cascade,

  code text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,

  status lock_code_status not null default 'active',

  external_code_id text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_lock_codes_org on lock_codes(organization_id);
create index idx_lock_codes_reservation on lock_codes(reservation_id);
create index idx_lock_codes_lock on lock_codes(lock_device_id);
create index idx_lock_codes_time on lock_codes(start_time, end_time);

create trigger trg_lock_codes_updated_at
before update on lock_codes
for each row execute function set_updated_at();

-- =====================================================
-- KEYPAD DEVICES (KP1 SUPPORT LAYER)
-- =====================================================

create table keypad_devices (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  lock_device_id uuid not null references lock_devices(id) on delete cascade,

  external_keypad_id text not null,

  name text,

  last_sync_at timestamptz,

  created_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (lock_device_id, external_keypad_id)
);

create index idx_keypad_devices_lock on keypad_devices(lock_device_id);

-- =====================================================
-- GATEWAYS (TTLOCK / G5 / HUB BRIDGE LAYER)
-- =====================================================

create table lock_gateways (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  provider integration_provider not null,

  external_gateway_id text not null,

  name text,

  last_seen_at timestamptz,

  status text not null default 'unknown',

  created_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (provider, external_gateway_id)
);

create index idx_gateways_org on lock_gateways(organization_id);

-- =====================================================
-- RESERVATION → LOCK CODE RELATION EVENTS
-- =====================================================

create table reservation_lock_map (
  id uuid primary key default gen_random_uuid(),

  reservation_id uuid not null references reservations(id) on delete cascade,
  lock_code_id uuid not null references lock_codes(id) on delete cascade,

  organization_id uuid not null references organizations(id) on delete cascade,

  created_at timestamptz not null default now(),

  unique (reservation_id, lock_code_id)
);

-- =====================================================
-- CHECK-IN EVENTS (OPERATIONAL TRACKING)
-- =====================================================

create table checkin_events (
  id uuid primary key default gen_random_uuid(),

  reservation_id uuid not null references reservations(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  event_type text not null, -- early_checkin, checkin, checkout

  event_time timestamptz not null default now(),

  source text, -- manual, automation, device

  metadata jsonb not null default '{}'::jsonb
);

create index idx_checkin_events_reservation on checkin_events(reservation_id);

-- =====================================================
-- RLS ENABLEMENT
-- =====================================================

alter table reservations enable row level security;
alter table reservation_guests enable row level security;
alter table lock_devices enable row level security;
alter table lock_codes enable row level security;
alter table keypad_devices enable row level security;
alter table lock_gateways enable row level security;
alter table reservation_lock_map enable row level security;
alter table checkin_events enable row level security;

-- =====================================================
-- RLS: RESERVATIONS
-- =====================================================

create policy "reservations_org"
on reservations
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = reservations.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: LOCK DEVICES
-- =====================================================

create policy "lock_devices_org"
on lock_devices
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = lock_devices.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: LOCK CODES (STRICT VIEW)
-- =====================================================

create policy "lock_codes_org"
on lock_codes
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = lock_codes.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: KEYPADS
-- =====================================================

create policy "keypads_org"
on keypad_devices
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = keypad_devices.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: GATEWAYS
-- =====================================================

create policy "gateways_org"
on lock_gateways
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = lock_gateways.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: SUPPORT TABLES
-- =====================================================

create policy "reservation_guests_org"
on reservation_guests
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = reservation_guests.organization_id
    and m.user_id = auth.uid()
  )
);

create policy "checkin_events_org"
on checkin_events
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = checkin_events.organization_id
    and m.user_id = auth.uid()
  )
);

-- =====================================================
-- SYSTEM TABLE PROTECTION (NO DIRECT ACCESS)
-- =====================================================

create policy "reservation_lock_map_service_only"
on reservation_lock_map
for all
using (false);