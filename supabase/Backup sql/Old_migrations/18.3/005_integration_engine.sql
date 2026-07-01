-- =====================================================
-- REV18.2.1 PRODUCTION PATCH
-- 005_integration_engine.sql
-- INTEGRATIONS + SYNC ENGINE (FIXED)
-- =====================================================

create table integrations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  provider integration_provider not null,
  name text not null,
  status integration_health_status not null default 'healthy',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_integrations_provider on integrations (provider);

create trigger trg_integrations_updated_at
before update on integrations
for each row execute function set_updated_at();

create table integration_credentials (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  integration_id uuid not null references integrations(id) on delete cascade,
  provider integration_provider not null,
  secret_ref bytea not null,
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (integration_id)
);

create table integration_device_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid not null,
  integration_id uuid not null references integrations(id) on delete cascade,
  device_id uuid not null references devices(id) on delete cascade,
  external_device_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (integration_id, device_id),
  unique (integration_id, external_device_id)
);

create table integration_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  integration_id uuid not null references integrations(id) on delete cascade,
  device_id uuid references devices(id) on delete set null,
  provider integration_provider not null,
  sync_type text not null,
  status sync_status not null default 'pending',
  attempts int not null default 0,
  max_attempts int not null default 5,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb,
  error_message text,
  last_attempt_at timestamptz,
  next_retry_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table integration_health (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  integration_id uuid not null references integrations(id) on delete cascade,
  provider integration_provider not null,
  status integration_health_status not null default 'healthy',
  last_success_at timestamptz,
  last_failure_at timestamptz,
  consecutive_failures int not null default 0,
  last_error text,
  response_time_ms int,
  token_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (integration_id)
);

create table webhooks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  integration_id uuid references integrations(id) on delete set null,
  provider integration_provider not null,
  event_type text not null,
  headers jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  status webhook_status not null default 'received',
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table integration_state (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  property_id uuid,
  integration_id uuid not null references integrations(id) on delete cascade,
  provider integration_provider not null,
  state_key text not null,
  state_value jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (integration_id, state_key)
);

alter table integrations enable row level security;
alter table integration_device_links enable row level security;
alter table integration_sync_jobs enable row level security;
alter table integration_health enable row level security;
alter table webhooks enable row level security;
alter table integration_state enable row level security;

create policy integrations_access on integrations
for all
using (
  deleted_at is null
  and (
    (property_id is null and is_org_member(organization_id))
    or (property_id is not null and can_access_property(property_id))
  )
)
with check (
  (property_id is null and is_org_member(organization_id))
  or (property_id is not null and can_access_property(property_id))
);

create policy integration_device_links_access on integration_device_links
for all
using (can_access_property(property_id))
with check (can_access_property(property_id));

create policy integration_sync_jobs_access on integration_sync_jobs
for all
using (
  (property_id is null and is_org_member(organization_id))
  or (property_id is not null and can_access_property(property_id))
)
with check (
  (property_id is null and is_org_member(organization_id))
  or (property_id is not null and can_access_property(property_id))
);

create policy integration_health_select on integration_health
for select
using (
  (property_id is null and is_org_member(organization_id))
  or (property_id is not null and can_access_property(property_id))
);

create policy webhooks_block_all
for all
using (false)
with check (false);

create policy integration_state_access on integration_state
for all
using (
  deleted_at is null
  and (
    (property_id is null and is_org_member(organization_id))
    or (property_id is not null and can_access_property(property_id))
  )
)
with check (
  (property_id is null and is_org_member(organization_id))
  or (property_id is not null and can_access_property(property_id))
);