-- =====================================================
-- REV18.2.1 PRODUCTION PATCH
-- 003_property_device_engine.sql
-- PROPERTY + DEVICE ENGINE (FIXED)
-- =====================================================

create table properties (
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

create index idx_properties_organization_id on properties (organization_id);

create trigger trg_properties_updated_at
before update on properties
for each row execute function set_updated_at();

create table property_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role property_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (property_id, user_id),
  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade
);

create index idx_property_memberships_property_id on property_memberships (property_id);

create trigger trg_property_memberships_updated_at
before update on property_memberships
for each row execute function set_updated_at();

create or replace function can_access_property(p_property_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from properties p
    join memberships m on m.organization_id = p.organization_id
    where p.id = p_property_id
      and p.deleted_at is null
      and m.user_id = auth.uid()
      and m.deleted_at is null
  )
  or exists (
    select 1
    from properties p
    where p.id = p_property_id
      and p.deleted_at is null
      and has_org_role(p.organization_id, array['admin','owner']::user_role[])
  );
$$;

create table rooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  name text not null,
  type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade
);

create index idx_rooms_property_id on rooms (property_id);

create trigger trg_rooms_updated_at
before update on rooms
for each row execute function set_updated_at();

create table device_models (
  id uuid primary key default gen_random_uuid(),
  provider integration_provider not null,
  model_key text not null,
  display_name text not null,
  category text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, model_key)
);

create trigger trg_device_models_updated_at
before update on device_models
for each row execute function set_updated_at();

insert into device_models (provider, model_key, display_name, category) values
  ('aqara', 'hub_m3', 'Aqara Hub M3', 'hub'),
  ('aqara', 'hub_m2', 'Aqara Hub M2', 'hub'),
  ('aqara', 'w100_thermostat', 'Aqara W100 Thermostat', 'thermostat'),
  ('aqara', 'multi_state_sensor_p100', 'Aqara P100 Sensor', 'sensor'),
  ('aqara', 'smart_plug_eu', 'Aqara Smart Plug EU', 'plug'),
  ('aqara', 'p300_sensor', 'Aqara P300 Sensor', 'sensor'),
  ('aqara', 'smoke_detector', 'Aqara Smoke Detector', 'safety_sensor'),
  ('aqara', 'water_leak_sensor_t1', 'Aqara Water Leak Sensor T1', 'safety_sensor'),
  ('ttlock', 'eleksec_d2', 'TTLock Eleksec D2', 'lock'),
  ('ttlock', 'kp1', 'TTLock KP1', 'keypad'),
  ('ttlock', 'g5', 'TTLock G5', 'gateway'),
  ('shelly', 'smart_plug_16a', 'Shelly Smart Plug 16A', 'plug')
on conflict (provider, model_key) do nothing;

create table devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  room_id uuid,
  provider integration_provider not null,
  model_key text not null,
  external_device_id text not null,
  name text not null,
  status device_status not null default 'unknown',
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (provider, external_device_id),
  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade,
  foreign key (room_id, property_id, organization_id)
    references rooms(id, property_id, organization_id) on delete set null,
  foreign key (provider, model_key)
    references device_models(provider, model_key)
);

create index idx_devices_property_id on devices (property_id);

create trigger trg_devices_updated_at
before update on devices
for each row execute function set_updated_at();

create table device_configs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  device_id uuid not null references devices(id) on delete cascade,
  config jsonb not null default '{}'::jsonb,
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (device_id)
);

create table device_states (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  device_id uuid not null references devices(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  battery_level int,
  signal_strength int,
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (device_id)
);

alter table properties enable row level security;
alter table property_memberships enable row level security;
alter table rooms enable row level security;
alter table device_models enable row level security;
alter table devices enable row level security;
alter table device_configs enable row level security;
alter table device_states enable row level security;

create policy properties_access on properties
for all
using (deleted_at is null and can_access_property(id))
with check (can_access_property(id));

create policy property_memberships_access on property_memberships
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy rooms_access on rooms
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy devices_access on devices
for all
using (deleted_at is null and can_access_property(property_id))
with check (can_access_property(property_id));

create policy device_configs_access on device_configs
for all
using (can_access_property(property_id))
with check (can_access_property(property_id));

create policy device_states_access on device_states
for all
using (can_access_property(property_id))
with check (can_access_property(property_id));