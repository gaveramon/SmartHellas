======
001_core_types.sql
======

create extension if not exists pgcrypto;
create extension if not exists citext;

create type user_role as enum ('admin','owner','manager','viewer');
create type property_role as enum ('owner','manager','operator','viewer');

create type subscription_plan as enum ('startup_service','managed_service');
create type subscription_status as enum ('trialing','active','past_due','cancelled','expired');

create type billing_status as enum ('pending','paid','failed','refunded','void');

create type integration_provider as enum (
  'aqara','ttlock','shelly','beds24','stripe','zoho','generic'
);

create type actor_type as enum ('user','system','ai','service');

create type operation_status as enum ('pending','queued','running','succeeded','failed','cancelled');

create type device_status as enum ('online','offline','unknown');

create type reservation_source as enum ('airbnb','booking_com','beds24','manual');

create type reservation_status as enum ('confirmed','cancelled','checked_in','checked_out','blocked');

create type lock_access_status as enum ('pending','active','expired','revoked','failed');

create type sync_status as enum ('pending','running','succeeded','failed','retrying','cancelled');

create type integration_health_status as enum ('healthy','warning','degraded','offline');

create type webhook_status as enum ('received','processed','failed');

====
002_core_saas.sql (HARDENED)
====

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================
-- ORGANIZATIONS
-- =========================

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text,
  timezone text not null default 'UTC',
  language text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create unique index idx_org_name_active
on organizations (lower(name))
where deleted_at is null;

create trigger trg_org_updated
before update on organizations
for each row execute function set_updated_at();

-- =========================
-- USERS
-- =========================

create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email citext not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create unique index idx_user_email_active
on user_profiles (email)
where deleted_at is null;

create trigger trg_user_updated
before update on user_profiles
for each row execute function set_updated_at();

-- =========================
-- MEMBERSHIPS
-- =========================

create table memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role user_role not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (organization_id, user_id)
);

create index idx_memberships_org on memberships(organization_id);
create index idx_memberships_user on memberships(user_id);

create trigger trg_memberships_updated
before update on memberships
for each row execute function set_updated_at();

-- =========================
-- HELPERS
-- =========================

create or replace function is_org_member(p_org uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from memberships m
    where m.organization_id = p_org
      and m.user_id = auth.uid()
      and m.deleted_at is null
  );
$$;

create or replace function has_org_role(p_org uuid, p_roles user_role[])
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from memberships m
    where m.organization_id = p_org
      and m.user_id = auth.uid()
      and m.deleted_at is null
      and m.role = any(p_roles)
  );
$$;

-- =========================
-- SUBSCRIPTIONS
-- =========================

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  plan subscription_plan not null,
  status subscription_status not null default 'trialing',
  starts_at timestamptz default now(),
  ends_at timestamptz,
  external_subscription_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz
);

create unique index idx_sub_ext
on subscriptions(organization_id, external_subscription_id)
where external_subscription_id is not null;

create trigger trg_sub_updated
before update on subscriptions
for each row execute function set_updated_at();

-- =========================
-- BILLING
-- =========================

create table billing_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  provider integration_provider not null default 'stripe',
  external_customer_id text not null,
  billing_email citext,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_billing_ext
on billing_accounts(provider, external_customer_id);

create trigger trg_billing_updated
before update on billing_accounts
for each row execute function set_updated_at();

create table billing_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  billing_account_id uuid,
  subscription_id uuid,
  provider integration_provider not null default 'stripe',
  external_event_id text not null,
  status billing_status default 'pending',
  amount numeric,
  currency text default 'EUR',
  payload jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  foreign key (billing_account_id)
    references billing_accounts(id) on delete set null,

  foreign key (subscription_id)
    references subscriptions(id) on delete set null
);

create unique index idx_billing_event_unique
on billing_events(provider, external_event_id);

create trigger trg_billing_events_updated
before update on billing_events
for each row execute function set_updated_at();

===========
 003_property_device_engine.sql (HARDENED)
===========

create table properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  address text,
  city text,
  country text,
  timezone text default 'UTC',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz
);

create index idx_properties_org on properties(organization_id);

create trigger trg_properties_updated
before update on properties
for each row execute function set_updated_at();

-- =========================
-- ROOMS
-- =========================

create table rooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,
  name text not null,
  type text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz
);

create index idx_rooms_property on rooms(property_id);

create trigger trg_rooms_updated
before update on rooms
for each row execute function set_updated_at();

-- =========================
-- DEVICE MODELS
-- =========================

create table device_models (
  id uuid primary key default gen_random_uuid(),
  provider integration_provider not null,
  model_key text not null,
  display_name text not null,
  category text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(provider, model_key)
);

create trigger trg_models_updated
before update on device_models
for each row execute function set_updated_at();

-- =========================
-- DEVICES
-- =========================

create table devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,
  room_id uuid,
  provider integration_provider not null,
  model_key text not null,
  external_device_id text not null,
  name text not null,
  status device_status default 'unknown',
  last_seen_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  foreign key (room_id)
    references rooms(id) on delete set null,

  foreign key (provider, model_key)
    references device_models(provider, model_key),

  unique(provider, external_device_id)
);

create index idx_devices_property on devices(property_id);

create trigger trg_devices_updated
before update on devices
for each row execute function set_updated_at();

-- =========================
-- DEVICE STATE / CONFIG
-- =========================

create table device_states (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  state jsonb default '{}'::jsonb,
  observed_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(device_id)
);

create table device_configs (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references devices(id) on delete cascade,
  config jsonb default '{}'::jsonb,
  version int default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(device_id)
);

============
004_booking_lock_engine.sql (HARDENED)
============
create table reservations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,
  room_id uuid,
  external_reservation_id text,
  source reservation_source not null,
  guest_name text,
  guest_email text,
  guest_phone text,
  check_in_at timestamptz not null,
  check_out_at timestamptz not null,
  status reservation_status default 'confirmed',
  number_of_guests int default 1,
  raw_payload jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  foreign key (room_id)
    references rooms(id) on delete set null
);

create index idx_res_dates on reservations(check_in_at, check_out_at);

create unique index idx_res_external
on reservations(organization_id, source, external_reservation_id)
where external_reservation_id is not null;

create trigger trg_res_updated
before update on reservations
for each row execute function set_updated_at();

-- guests
create table reservation_guests (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references reservations(id) on delete cascade,
  name text,
  email text,
  phone text,
  is_primary boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- lock codes
create table lock_access_codes (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid references reservations(id) on delete cascade,
  device_id uuid not null references devices(id) on delete cascade,
  code_hash text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status lock_access_status default 'pending',
  external_code_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

=================
 005_integration_engine.sql (HARDENED + 006 READY)
=================

create table integrations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  provider integration_provider not null,
  name text not null,
  status integration_health_status default 'healthy',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table integration_credentials (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references integrations(id) on delete cascade,
  secret_ref text not null,
  expires_at timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(integration_id)
);

create table integration_device_links (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references integrations(id) on delete cascade,
  device_id uuid not null references devices(id) on delete cascade,
  external_device_id text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(integration_id, device_id)
);

create table integration_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references integrations(id) on delete cascade,
  device_id uuid,
  sync_type text not null,
  status sync_status default 'pending',
  attempts int default 0,
  request_payload jsonb default '{}'::jsonb,
  response_payload jsonb,
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table integration_health (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references integrations(id) on delete cascade,
  status integration_health_status default 'healthy',
  last_success_at timestamptz,
  last_failure_at timestamptz,
  consecutive_failures int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(integration_id)
);

create table webhooks (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid references integrations(id),
  event_type text not null,
  headers jsonb default '{}'::jsonb,
  payload jsonb default '{}'::jsonb,
  status webhook_status default 'received',
  received_at timestamptz default now(),
  processed_at timestamptz,
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table integration_state (
  id uuid primary key default gen_random_uuid(),
  integration_id uuid not null references integrations(id) on delete cascade,
  state_key text not null,
  state_value jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(integration_id, state_key)
);

=====================================================
006_operations_engine.sql (FIXED REV18.3)
=====================================================

create extension if not exists pgcrypto;
create extension if not exists citext;

-- =====================================================
-- ACTION TYPES
-- =====================================================

create type operation_action_type as enum (
  'device_command',
  'device_state_change',
  'automation_change',
  'reservation_change',
  'lock_access_change',
  'integration_sync',
  'billing_change',
  'admin_action'
);

-- =====================================================
-- OPERATION ACTIONS
-- =====================================================

create table operation_actions (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,

  device_id uuid,
  integration_id uuid,

  action_type operation_action_type not null,
  action_name text not null,

  actor_type actor_type not null,
  actor_user_id uuid references auth.users(id),

  parameters jsonb not null default '{}'::jsonb,
  status operation_status not null default 'pending',

  correlation_id uuid not null default gen_random_uuid(),

  scheduled_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,

  error_message text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,

  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade,

  foreign key (device_id, property_id, organization_id)
    references devices(id, property_id, organization_id) on delete set null,

  foreign key (integration_id, organization_id)
    references integrations(id, organization_id) on delete set null
);

create index idx_operation_actions_org on operation_actions(organization_id);
create index idx_operation_actions_property on operation_actions(property_id);
create index idx_operation_actions_device on operation_actions(device_id);
create index idx_operation_actions_actor on operation_actions(actor_user_id);
create index idx_operation_actions_status on operation_actions(status);
create index idx_operation_actions_correlation on operation_actions(correlation_id);

create trigger trg_operation_actions_updated_at
before update on operation_actions
for each row execute function set_updated_at();

-- =====================================================
-- OPERATION LOGS (IMMUTABLE)
-- =====================================================

create table operation_logs (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  device_id uuid,

  operation_action_id uuid,

  actor_type actor_type not null,
  actor_user_id uuid,

  entity_type text not null,
  entity_id uuid not null,
  action text not null,

  before_state jsonb,
  after_state jsonb,
  metadata jsonb not null default '{}'::jsonb,

  correlation_id uuid not null default gen_random_uuid(),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade,

  foreign key (device_id, property_id, organization_id)
    references devices(id, property_id, organization_id) on delete set null,

  foreign key (operation_action_id, organization_id)
    references operation_actions(id, organization_id) on delete set null
);

create index idx_operation_logs_org on operation_logs(organization_id);
create index idx_operation_logs_property on operation_logs(property_id);
create index idx_operation_logs_device on operation_logs(device_id);
create index idx_operation_logs_actor on operation_logs(actor_user_id);
create index idx_operation_logs_entity on operation_logs(entity_type, entity_id);
create index idx_operation_logs_correlation on operation_logs(correlation_id, created_at);

-- =====================================================
-- OPERATION ATTEMPTS
-- =====================================================

create table operation_attempts (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,

  operation_action_id uuid not null references operation_actions(id) on delete cascade,

  attempt_number int not null,
  status operation_status not null,

  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb,
  error_message text,

  started_at timestamptz not null default now(),
  finished_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(operation_action_id, attempt_number),

  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade
);

create index idx_operation_attempts_org on operation_attempts(organization_id);
create index idx_operation_attempts_property on operation_attempts(property_id);
create index idx_operation_attempts_action on operation_attempts(operation_action_id);
create index idx_operation_attempts_status on operation_attempts(status);

-- =====================================================
-- AI ACTION LOGS
-- =====================================================

create table ai_action_logs (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,

  operation_action_id uuid,

  actor_user_id uuid references auth.users(id),

  prompt_hash text,
  function_name text not null,

  parameters jsonb not null default '{}'::jsonb,
  before_state jsonb,
  after_state jsonb,

  status operation_status not null,
  error_message text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  foreign key (operation_action_id, organization_id)
    references operation_actions(id, organization_id) on delete set null,

  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade
);

create index idx_ai_logs_org on ai_action_logs(organization_id);
create index idx_ai_logs_property on ai_action_logs(property_id);
create index idx_ai_logs_actor on ai_action_logs(actor_user_id);
create index idx_ai_logs_action on ai_action_logs(operation_action_id);

-- =====================================================
-- IMMUTABILITY GUARD
-- =====================================================

create or replace function prevent_operation_log_mutation()
returns trigger as $$
begin
  raise exception 'operation audit tables are immutable';
end;
$$ language plpgsql;

create trigger trg_operation_logs_immutable
before update or delete on operation_logs
for each row execute function prevent_operation_log_mutation();

create trigger trg_ai_action_logs_immutable
before update or delete on ai_action_logs
for each row execute function prevent_operation_log_mutation();

-- =====================================================
-- LOG FUNCTION
-- =====================================================

create or replace function log_operation_action(
  p_organization_id uuid,
  p_property_id uuid,
  p_device_id uuid,
  p_operation_action_id uuid,
  p_actor_type actor_type,
  p_actor_user_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_before_state jsonb default null,
  p_after_state jsonb default null,
  p_metadata jsonb default '{}'::jsonb,
  p_correlation_id uuid default gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_log_id uuid;
begin
  insert into operation_logs (
    organization_id, property_id, device_id,
    operation_action_id, actor_type, actor_user_id,
    entity_type, entity_id, action,
    before_state, after_state, metadata, correlation_id
  )
  values (
    p_organization_id, p_property_id, p_device_id,
    p_operation_action_id, p_actor_type, p_actor_user_id,
    p_entity_type, p_entity_id, p_action,
    p_before_state, p_after_state, p_metadata, p_correlation_id
  )
  returning id into v_log_id;

  return v_log_id;
end;
$$;

=====================================================
007_preconfig_engine.sql (FIXED)
=====================================================

create table if not exists property_preconfiguration (
  id uuid primary key default gen_random_uuid(),

  property_id uuid not null references properties(id) on delete cascade,

  status text default 'draft',
  config jsonb default '{}'::jsonb,

  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(property_id)
);

-- ROOM DEVICES (FIXED MULTI-TENANT)
create table if not exists room_devices (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,

  room_id uuid not null references rooms(id) on delete cascade,
  device_id uuid references devices(id) on delete set null,

  intent text,
  label text,
  qr_code text,

  status text default 'planned',

  created_at timestamptz default now(),

  foreign key (property_id, organization_id)
    references properties(id, organization_id) on delete cascade
);

create index if not exists idx_room_devices_property on room_devices(property_id);

-- DEVICE CONFIG EXTENSION
alter table device_configs
add column if not exists intent text,
add column if not exists priority int default 1;

-- WORKFLOW
create table if not exists preconfig_workflow (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,

  step text not null,
  status text default 'pending',

  metadata jsonb default '{}'::jsonb,

  updated_at timestamptz default now(),

  unique(property_id, step)
);

create index if not exists idx_preconfig_workflow_property on preconfig_workflow(property_id);

=====================================================
008_logistics_engine.sql (FIXED)
=====================================================

create table if not exists shipments (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,

  status text default 'preparing',

  tracking_number text,
  carrier text,

  shipped_at timestamptz,
  delivered_at timestamptz,

  created_at timestamptz default now()
);

create table if not exists shipment_items (
  id uuid primary key default gen_random_uuid(),

  shipment_id uuid references shipments(id) on delete cascade,

  device_id uuid references devices(id),
  room_id uuid references rooms(id),

  label text,
  qr_code text,

  created_at timestamptz default now()
);

create table if not exists preconfig_event_log (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null references properties(id) on delete cascade,

  event_type text not null,
  source text,
  payload jsonb default '{}'::jsonb,

  created_at timestamptz default now()
);

create index if not exists idx_preconfig_event_property on preconfig_event_log(property_id);

=====================================================
009_commerce_engine.sql (FIXED SCOPING)
=====================================================

create table tax_rules (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id),

  country text default 'GR',
  tax_name text default 'VAT Greece',
  tax_rate numeric default 0.24,

  applies_to text not null,

  created_at timestamptz default now()
);

create table discount_rules (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id),

  name text,
  rule_type text not null,

  condition jsonb not null,

  discount_type text not null,
  value numeric not null,

  priority int default 1,
  is_active boolean default true,

  created_at timestamptz default now()
);

=====================================================
010_service_portal_engine.sql (FIXED CONSISTENCY)
=====================================================

create table portal_users (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,

  role user_role not null,

  last_login_at timestamptz,

  created_at timestamptz default now(),
  updated_at timestamptz default now(),

  unique(organization_id, user_id)
);

create table subscription_features (
  id uuid primary key default gen_random_uuid(),

  plan subscription_plan not null,
  feature_key text not null,

  enabled boolean default true,
  metadata jsonb default '{}'::jsonb,

  unique(plan, feature_key)
);

create table property_entitlements (
  id uuid primary key default gen_random_uuid(),

  property_id uuid not null references properties(id) on delete cascade,

  feature_key text not null,
  enabled boolean default false,

  source subscription_plan,

  created_at timestamptz default now(),

  unique(property_id, feature_key)
);

=====================================================
REV18.3 PRODUCTION HARDENED (FIXED)
011 EXECUTION ENGINE
=====================================================

create type execution_status as enum (
'pending',
'queued',
'running',
'succeeded',
'failed',
'retrying',
'cancelled'
);

-- =====================================================
-- 1. EXECUTION WORKERS
-- =====================================================

create table execution_workers (
id uuid primary key default gen_random_uuid(),
worker_name text not null,
worker_type text not null,
-- command_router | device_worker | ai_worker | reconciliation_worker

status text not null default 'active',
last_heartbeat_at timestamptz,
metadata jsonb default '{}'::jsonb,
created_at timestamptz default now()

);

create index idx_execution_workers_status on execution_workers(status);

-- =====================================================
-- 2. EXECUTION QUEUE (IDEMPOTENT + SCALABLE)
-- =====================================================

create table execution_queue (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

operation_action_id uuid not null references operation_actions(id) on delete cascade,

correlation_id uuid not null,

device_id uuid references devices(id) on delete set null,
integration_id uuid references integrations(id) on delete set null,

execution_domain text not null,
-- device | integration | ai | hybrid

provider integration_provider,

action_type operation_action_type not null,

status execution_status not null default 'pending',

priority int default 1,

attempt int default 0,
max_attempts int default 5,

idempotency_key text not null,

scheduled_at timestamptz default now(),
started_at timestamptz,
finished_at timestamptz,

worker_id uuid references execution_workers(id),

created_at timestamptz default now(),

unique (idempotency_key)

);

create index idx_execution_queue_status on execution_queue(status);
create index idx_execution_queue_corr on execution_queue(correlation_id);
create index idx_execution_queue_device on execution_queue(device_id);

-- =====================================================
-- 3. DEVICE EXECUTION MAP (BOUND TO DEVICE MODEL 003)
-- =====================================================

create table device_execution_map (
id uuid primary key default gen_random_uuid(),

provider integration_provider not null,

device_model_id uuid not null,
-- FK to 003 device model layer

action_type operation_action_type not null,

handler_name text not null,
-- aqara_hub_handler | ttlock_gateway_handler | shelly_http_handler

execution_mode text not null default 'sync',
-- sync | async | webhook

config jsonb default '{}'::jsonb,

created_at timestamptz default now(),

unique(provider, device_model_id, action_type)

);

-- =====================================================
-- 4. PROVIDER EXECUTION LOGS
-- =====================================================

create table provider_execution_logs (
id uuid primary key default gen_random_uuid(),

execution_queue_id uuid references execution_queue(id) on delete cascade,

provider integration_provider not null,

request_payload jsonb,
response_payload jsonb,

http_status int,
success boolean default false,

latency_ms int,
error_message text,

created_at timestamptz default now()

);

create index idx_provider_logs_queue on provider_execution_logs(execution_queue_id);

-- =====================================================
-- 5. EXECUTION FAILOVER EVENTS
-- =====================================================

create table execution_failover_events (
id uuid primary key default gen_random_uuid(),
execution_queue_id uuid references execution_queue(id) on delete cascade,

failure_type text,
error_message text,

retry_scheduled_at timestamptz,
resolved boolean default false,

created_at timestamptz default now()

);

-- =====================================================
-- 6. RECONCILIATION ENGINE
-- =====================================================

create table state_reconciliation_jobs (
id uuid primary key default gen_random_uuid(),

device_id uuid not null references devices(id) on delete cascade,

desired_state jsonb,
actual_state jsonb,

drift_detected boolean default false,

status execution_status not null default 'pending',

last_checked_at timestamptz default now(),
created_at timestamptz default now()

);

-- =====================================================
-- 7. AI EXECUTION DECISIONS
-- =====================================================

create table ai_execution_decisions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

operation_action_id uuid references operation_actions(id) on delete cascade,

input_context jsonb,
decision jsonb,

confidence numeric,

approved boolean default false,
executed boolean default false,

correlation_id uuid,

created_at timestamptz default now()

);

-- =====================================================
-- 8. SYSTEM EVENT BUS (SECURED + SERVICE ROLE)
-- =====================================================

create table system_event_bus (
id uuid primary key default gen_random_uuid(),

event_type text not null,
source text not null,

payload jsonb,

status execution_status not null default 'pending',

retry_count int default 0,
max_retries int default 5,

next_retry_at timestamptz,
processed_at timestamptz,

created_at timestamptz default now()

);

alter table system_event_bus enable row level security;

create policy event_bus_service_only on system_event_bus
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

-- =====================================================
-- 9. EXECUTION TRACE
-- =====================================================

create table execution_trace (
id uuid primary key default gen_random_uuid(),

correlation_id uuid not null,

step text not null,
component text not null,
-- queue | router | provider | worker | ai | reconciliation

payload jsonb,

success boolean default false,
error text,

created_at timestamptz default now()

);

create index idx_execution_trace_corr on execution_trace(correlation_id);

-- =====================================================
-- 10. RLS (CORE EXECUTION TABLES)
-- =====================================================

alter table execution_queue enable row level security;
alter table provider_execution_logs enable row level security;
alter table ai_execution_decisions enable row level security;

create policy execution_queue_access on execution_queue
for all
using (
exists (
select 1 from memberships m
where m.organization_id = execution_queue.organization_id
and m.user_id = auth.uid()
and m.deleted_at is null
)
);

create policy provider_logs_access on provider_execution_logs
for select
using (
exists (
select 1
from execution_queue q
join memberships m on m.organization_id = q.organization_id
where q.id = provider_execution_logs.execution_queue_id
and m.user_id = auth.uid()
and m.deleted_at is null
)
);

create policy ai_exec_access on ai_execution_decisions
for all
using (
exists (
select 1 from memberships m
where m.organization_id = ai_execution_decisions.organization_id
and m.user_id = auth.uid()
and m.deleted_at is null
)
);

=====================================================
012 OPTIMIZATION ENGINE (FIXED INTEGRATION)
=====================================================

create table optimization_insights (
id uuid primary key default gen_random_uuid(),
organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

domain text not null,
insight_type text not null,

title text not null,
description text,

severity int default 1,
confidence numeric default 0.0,

dedup_key text not null,
cooldown_minutes int default 60,

status text not null default 'active',

expires_at timestamptz,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now(),
updated_at timestamptz default now(),
deleted_at timestamptz,

unique (organization_id, dedup_key)

);

-- =====================================================

create table optimization_proposals (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

insight_id uuid references optimization_insights(id) on delete set null,

external_proposal_id uuid,

proposal_origin_type text not null,
-- optimization | customer | system

title text not null,
description text,
domain text not null,

status text not null default 'proposed',

proposal_version int default 1,
previous_proposal_id uuid references optimization_proposals(id),

impact_score numeric default 0.0,
estimated_savings numeric default 0.0,

priority int default 1,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now(),
updated_at timestamptz default now(),
deleted_at timestamptz

);

-- =====================================================

create table optimization_proposal_actions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

proposal_id uuid not null references optimization_proposals(id) on delete cascade,
operation_action_id uuid references operation_actions(id),

action_type text not null,
parameters jsonb default '{}'::jsonb,

execution_queue_id uuid,
-- 🔥 direct bridge to execution engine

status text default 'pending',

created_at timestamptz default now(),
updated_at timestamptz default now(),
deleted_at timestamptz

);

-- =====================================================

create table optimization_ai_runs (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

insight_id uuid references optimization_insights(id),
proposal_id uuid references optimization_proposals(id),

trigger_type text not null,

model_name text,
model_version text,
prompt_version text,

input jsonb,
output jsonb,

token_usage int default 0,
cost_estimate numeric default 0.0,

status text default 'completed',

correlation_id uuid,

created_at timestamptz default now(),
deleted_at timestamptz

);

-- =====================================================

create table optimization_proposal_decisions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

proposal_id uuid not null references optimization_proposals(id),

user_id uuid references auth.users(id),

decision text not null,

reason text,

created_at timestamptz default now(),
deleted_at timestamptz

);

-- =====================================================

create table optimization_rate_limits (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

domain text not null,

cooldown_minutes int default 60,
last_triggered_at timestamptz,

unique (organization_id, property_id, domain)

);

=====================================================
013 CUSTOMER PROPOSAL & MONETIZATION (FIXED SOURCE OF TRUTH)
=====================================================

create table customer_proposals (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

source text not null,
-- configurator | ai | manual | onboarding | upsell | optimization

external_optimization_proposal_id uuid,

title text not null,
description text,

proposal_type text not null,

status text default 'draft',
-- draft | presented | accepted | rejected | expired

total_price numeric default 0.0,
currency text default 'EUR',

valid_until timestamptz,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now(),
updated_at timestamptz default now(),
deleted_at timestamptz

);

-- =====================================================

create table customer_proposal_items (
id uuid primary key default gen_random_uuid(),

proposal_id uuid not null references customer_proposals(id),

product_type text not null,
product_code text,
name text not null,

quantity int default 1,
unit_price numeric default 0.0,

is_optional boolean default false,
is_selected boolean default true,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);

-- FIXED SECURITY (was wide open before)
alter table customer_proposal_items enable row level security;

create policy proposal_items_secure on customer_proposal_items
for all
using (
exists (
select 1
from customer_proposals p
where p.id = proposal_id
and is_org_member(p.organization_id)
)
);

-- =====================================================

create table customer_proposal_approvals (
id uuid primary key default gen_random_uuid(),
proposal_id uuid references customer_proposals(id),
user_id uuid references auth.users(id),
decision text not null,
comment text,
created_at timestamptz default now()
);

-- =====================================================

create table subscription_offers (
id uuid primary key default gen_random_uuid(),
organization_id uuid not null references organizations(id),

property_id uuid,

trigger_source text not null,
name text not null,

plan_type text not null,
monthly_price numeric not null,
setup_fee numeric default 0.0,

features jsonb default '{}'::jsonb,

priority int default 1,
is_active boolean default true,

created_at timestamptz default now()

);

-- =====================================================

create table customer_subscriptions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

offer_id uuid references subscription_offers(id),

status text default 'trialing',
provider text not null,

external_subscription_id text,

current_price numeric default 0.0,
currency text default 'EUR',

started_at timestamptz default now(),
ends_at timestamptz,

metadata jsonb default '{}'::jsonb

);

-- =====================================================

create table payment_transactions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

subscription_id uuid references customer_subscriptions(id),

provider text not null,
external_payment_id text,

amount numeric not null,
currency text default 'EUR',

status text default 'pending',
source text,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);

-- =====================================================

create table checkout_sessions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

session_source text not null,

proposal_id uuid references customer_proposals(id),

status text default 'active',
-- active | completed | abandoned | expired | converted

cart_snapshot jsonb default '{}'::jsonb,

total_amount numeric default 0.0,
currency text default 'EUR',

created_at timestamptz default now(),
updated_at timestamptz default now()

);

-- =====================================================

create table conversion_events (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id),
property_id uuid,

checkout_session_id uuid,
proposal_id uuid,

event_type text not null,

source text not null,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);