-- =====================================================
-- REV18.1.1 PRODUCTION MASTER
-- DEEL 4 - INTEGRATION ENGINE + SYNC LAYER
-- =====================================================

-- =====================================================
-- ENUMS
-- =====================================================

create type sync_status as enum (
  'pending',
  'running',
  'success',
  'failed',
  'retrying'
);

create type integration_health_status as enum (
  'healthy',
  'warning',
  'degraded',
  'offline'
);

create type webhook_status as enum (
  'received',
  'processed',
  'failed'
);

-- =====================================================
-- INTEGRATION SYNC JOBS (CORE ORCHESTRATION)
-- =====================================================

create table if not exists integration_sync_jobs (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  integration_id uuid references integrations(id) on delete cascade,

  provider integration_provider not null,

  job_type text not null, -- e.g. devices_sync, reservations_sync, lock_sync

  status sync_status not null default 'pending',

  attempts int not null default 0,
  max_attempts int not null default 5,

  last_attempt_at timestamptz,
  next_retry_at timestamptz,

  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb,

  error_message text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_sync_jobs_org on integration_sync_jobs(organization_id);
create index idx_sync_jobs_status on integration_sync_jobs(status);
create index idx_sync_jobs_provider on integration_sync_jobs(provider);

create trigger trg_sync_jobs_updated_at
before update on integration_sync_jobs
for each row execute function set_updated_at();

-- =====================================================
-- INTEGRATION HEALTH (EXPANDED PRODUCTION VERSION)
-- =====================================================

create table if not exists integration_health (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  integration_id uuid references integrations(id) on delete cascade,

  provider integration_provider not null,

  status integration_health_status not null default 'healthy',

  last_success_at timestamptz,
  last_failure_at timestamptz,

  consecutive_failures int not null default 0,

  last_error text,
  response_time_ms int,

  token_expires_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_health_org on integration_health(organization_id);
create index idx_health_provider on integration_health(provider);

create trigger trg_health_updated_at
before update on integration_health
for each row execute function set_updated_at();

-- =====================================================
-- WEBHOOK INGESTION LAYER
-- =====================================================

create table if not exists webhooks (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id) on delete cascade,
  provider integration_provider not null,

  event_type text not null,

  headers jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,

  status webhook_status not null default 'received',

  received_at timestamptz not null default now(),
  processed_at timestamptz,

  error_message text
);

create index idx_webhooks_org on webhooks(organization_id);
create index idx_webhooks_provider on webhooks(provider);
create index idx_webhooks_status on webhooks(status);

-- =====================================================
-- PROVIDER TOKENS (ENHANCED INTEGRATION CREDENTIALS)
-- =====================================================

create table if not exists integration_credentials (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  provider integration_provider not null,

  access_token text,
  refresh_token text,

  api_key text,
  api_secret text,

  expires_at timestamptz,

  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_credentials_org on integration_credentials(organization_id);
create index idx_credentials_provider on integration_credentials(provider);

create trigger trg_credentials_updated_at
before update on integration_credentials
for each row execute function set_updated_at();

-- =====================================================
-- PROVIDER ROUTING CONFIG
-- =====================================================

create table if not exists integration_routes (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  provider integration_provider not null,

  endpoint text not null,
  method text not null,

  timeout_ms int not null default 10000,

  retry_policy jsonb not null default '{}'::jsonb,

  is_active boolean not null default true,

  created_at timestamptz not null default now()
);

create index idx_routes_org on integration_routes(organization_id);

-- =====================================================
-- STRIPE BILLING SYNC STATE
-- =====================================================

create table if not exists stripe_subscriptions (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  stripe_customer_id text not null,
  stripe_subscription_id text not null,

  plan subscription_plan not null,

  status text not null,

  current_period_start timestamptz,
  current_period_end timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_stripe_org on stripe_subscriptions(organization_id);

create trigger trg_stripe_updated_at
before update on stripe_subscriptions
for each row execute function set_updated_at();

-- =====================================================
-- ZOHO MAIL NOTIFICATION LOG
-- =====================================================

create table if not exists zoho_email_logs (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  to_email text not null,
  subject text not null,

  template_type text,

  status text not null default 'pending',

  error_message text,

  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_zoho_org on zoho_email_logs(organization_id);

-- =====================================================
-- BEDS24 SYNC STATE
-- =====================================================

create table if not exists beds24_sync_state (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  last_sync_at timestamptz,
  last_reservation_sync_at timestamptz,
  last_calendar_sync_at timestamptz,

  sync_cursor text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_beds24_org on beds24_sync_state(organization_id);

create trigger trg_beds24_updated_at
before update on beds24_sync_state
for each row execute function set_updated_at();

-- =====================================================
-- EVENT-DRIVEN DISPATCH QUEUE
-- =====================================================

create table if not exists integration_event_queue (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id) on delete cascade,

  provider integration_provider not null,

  event_type text not null,

  payload jsonb not null default '{}'::jsonb,

  status sync_status not null default 'pending',

  attempts int not null default 0,
  max_attempts int not null default 5,

  next_retry_at timestamptz,

  created_at timestamptz not null default now()
);

create index idx_event_queue_org on integration_event_queue(organization_id);
create index idx_event_queue_status on integration_event_queue(status);

-- =====================================================
-- RLS ENABLEMENT
-- =====================================================

alter table integration_sync_jobs enable row level security;
alter table integration_health enable row level security;
alter table webhooks enable row level security;
alter table integration_credentials enable row level security;
alter table integration_routes enable row level security;
alter table stripe_subscriptions enable row level security;
alter table zoho_email_logs enable row level security;
alter table beds24_sync_state enable row level security;
alter table integration_event_queue enable row level security;

-- =====================================================
-- RLS: STANDARD TENANT ISOLATION
-- =====================================================

create policy "sync_jobs_org"
on integration_sync_jobs
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = integration_sync_jobs.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "integration_health_org"
on integration_health
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = integration_health.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "webhooks_org"
on webhooks
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = webhooks.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "credentials_org"
on integration_credentials
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = integration_credentials.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "routes_org"
on integration_routes
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = integration_routes.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "stripe_org"
on stripe_subscriptions
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = stripe_subscriptions.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "zoho_org"
on zoho_email_logs
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = zoho_email_logs.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "beds24_org"
on beds24_sync_state
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = beds24_sync_state.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- SYSTEM QUEUES (SERVICE ROLE ONLY)

create policy "event_queue_service_only"
on integration_event_queue
for all
using (false);