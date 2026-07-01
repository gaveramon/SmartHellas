-- =====================================================
-- REV18.2.1 PRODUCTION PATCH
-- 004_booking_lock_engine.sql
-- BOOKINGS + LOCK ENGINE (FIXED)
-- =====================================================

create table reservations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  room_id uuid,
  external_reservation_id text,
  source reservation_source not null,
  guest_name text,
  guest_email text,
  guest_phone text,
  check_in_at timestamptz not null,
  check_out_at timestamptz not null,
  status reservation_status not null default 'confirmed',
  number_of_guests int not null default 1,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (organization_id, source, external_reservation_id),
  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade,
  foreign key (room_id, property_id, organization_id)
    references rooms(id, property_id, organization_id) on delete set null
);

create index idx_reservations_property_id on reservations (property_id);

create trigger trg_reservations_updated_at
before update on reservations
for each row execute function set_updated_at();

create table reservation_guests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  reservation_id uuid not null references reservations(id) on delete cascade,
  name text,
  email text,
  phone text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create table lock_access_codes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  room_id uuid,
  reservation_id uuid,
  device_id uuid not null references devices(id) on delete cascade,
  code_hash text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status lock_access_status not null default 'pending',
  external_code_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_lock_access_codes_time on lock_access_codes (starts_at, ends_at);

create table lock_access_code_secrets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  lock_access_code_id uuid not null references lock_access_codes(id) on delete cascade,
  encrypted_code text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lock_access_code_id)
);

create table reservation_lock_access (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  reservation_id uuid not null references reservations(id) on delete cascade,
  lock_access_code_id uuid not null references lock_access_codes(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reservation_id, lock_access_code_id)
);

alter table reservations enable row level security;
alter table reservation_guests enable row level security;
alter table lock_access_codes enable row level security;
alter table lock_access_code_secrets enable row level security;
alter table reservation_lock_access enable row level security;

create policy reservations_access on reservations
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy reservation_guests_access on reservation_guests
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy lock_access_codes_access on lock_access_codes
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy lock_access_code_secrets_block
for all
using (false)
with check (false);

create policy reservation_lock_access_access on reservation_lock_access
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));