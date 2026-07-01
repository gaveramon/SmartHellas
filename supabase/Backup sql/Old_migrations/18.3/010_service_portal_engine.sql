-- =====================================================
-- REV18.3 PRODUCTION HARDENED
-- 010_service_portal_engine.sql
-- Control + Execution + Governance Layer
-- =====================================================

-- =====================================================
-- 1. PORTAL USERS
-- =====================================================

create table portal_users (
    id uuid primary key default gen_random_uuid(),
    organization_id uuid not null references organizations(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,

    role user_role not null,

    last_login_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),

    unique (organization_id, user_id)
);

create index idx_portal_users_org on portal_users(organization_id);


-- =====================================================
-- 2. FEATURE ENTITLEMENTS
-- =====================================================

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


-- =====================================================
-- 3. COMMAND EXECUTION ENGINE (HARDENED)
-- =====================================================

create type device_command_status as enum (
    'pending',
    'queued',
    'routing',
    'sent',
    'acknowledged',
    'failed',
    'timeout',
    'cancelled'
);

create table device_control_commands (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,
    property_id uuid not null,

    device_id uuid not null references devices(id) on delete cascade,
    integration_id uuid references integrations(id),

    command_type text not null,
    payload jsonb not null default '{}'::jsonb,

    status device_command_status default 'pending',

    priority int default 1,
    lock_key text, -- prevents conflicting commands (lock/airco)

    retry_count int default 0,
    max_retries int default 3,

    idempotency_key text,

    correlation_id uuid default gen_random_uuid(),

    created_at timestamptz default now(),
    sent_at timestamptz,
    finished_at timestamptz,

    error_message text
);

create index idx_commands_device on device_control_commands(device_id);
create index idx_commands_status on device_control_commands(status);
create index idx_commands_lock on device_control_commands(lock_key);


-- =====================================================
-- 4. COMMAND RESULTS (STATE GUARANTEE)
-- =====================================================

create table device_command_results (
    id uuid primary key default gen_random_uuid(),
    command_id uuid not null references device_control_commands(id) on delete cascade,

    success boolean default false,
    response_payload jsonb default '{}'::jsonb,

    final_device_state jsonb,

    latency_ms int,

    created_at timestamptz default now()
);


-- =====================================================
-- 5. DEVICE STATE (RECONCILIATION CORE)
-- =====================================================

create table device_state_desired (
    id uuid primary key default gen_random_uuid(),
    device_id uuid not null references devices(id) on delete cascade,

    desired_state jsonb not null default '{}'::jsonb,

    priority int default 1,
    source text,

    updated_at timestamptz default now(),

    unique(device_id)
);

create table device_state_actual_log (
    id uuid primary key default gen_random_uuid(),
    device_id uuid not null references devices(id) on delete cascade,

    state jsonb not null,
    battery_level int,
    signal_strength int,

    recorded_at timestamptz default now()
);

create index idx_device_state_log_device on device_state_actual_log(device_id);


-- =====================================================
-- 6. DEVICE COMMAND ROUTER (NEW CRITICAL LAYER)
-- =====================================================

create table device_command_routes (
    id uuid primary key default gen_random_uuid(),

    provider integration_provider not null,
    device_type text not null,

    route_handler text not null,
    -- e.g. aqara_m3_handler | ttlock_gateway_handler | shelly_http_handler

    config jsonb default '{}'::jsonb,

    created_at timestamptz default now()
);


-- =====================================================
-- 7. AUTOMATION ENGINE (DETERMINISTIC FIX)
-- =====================================================

create table automation_rules (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,
    property_id uuid not null,

    name text not null,

    version int default 1,

    trigger_type text not null,
    action_type text not null,

    priority int default 1,

    config jsonb not null default '{}'::jsonb,

    enabled boolean default true,

    created_at timestamptz default now()
);


create table automation_executions (
    id uuid primary key default gen_random_uuid(),

    rule_id uuid references automation_rules(id) on delete cascade,

    trigger_event jsonb,
    evaluation_result jsonb,

    matched boolean default false,

    status operation_status default 'pending',

    created_at timestamptz default now()
);


-- =====================================================
-- 8. SUPPORT + SERVICE LOGGING
-- =====================================================

create table support_tickets (
    id uuid primary key default gen_random_uuid(),
    organization_id uuid not null references organizations(id) on delete cascade,
    property_id uuid,

    title text,
    description text,
    status text default 'open',
    priority int default 1,

    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create table service_event_log (
    id uuid primary key default gen_random_uuid(),
    organization_id uuid not null references organizations(id) on delete cascade,
    property_id uuid,

    event_type text not null,
    actor_type actor_type not null,
    actor_user_id uuid,

    payload jsonb default '{}'::jsonb,

    created_at timestamptz default now()
);


-- =====================================================
-- 9. ONBOARDING STATE BRIDGE
-- =====================================================

create table onboarding_checkpoints (
    id uuid primary key default gen_random_uuid(),
    property_id uuid not null references properties(id) on delete cascade,

    step_code text not null,
    status text default 'pending',

    metadata jsonb default '{}'::jsonb,

    created_at timestamptz default now(),
    updated_at timestamptz default now()
);


create table onboarding_execution_state (
    id uuid primary key default gen_random_uuid(),
    property_id uuid not null,

    current_step text,
    completion_percentage int default 0,

    last_updated_at timestamptz default now(),

    unique(property_id)
);


-- =====================================================
-- 10. DEVICE HEALTH (TIME SERIES FIX)
-- =====================================================

create table device_health_log (
    id uuid primary key default gen_random_uuid(),
    device_id uuid not null references devices(id) on delete cascade,

    status text,
    battery_level int,
    signal_strength int,

    recorded_at timestamptz default now()
);

create index idx_device_health_log_device on device_health_log(device_id);


-- =====================================================
-- 11. MULTI-TENANT RLS (HARDENED)
-- =====================================================

alter table portal_users enable row level security;
alter table device_control_commands enable row level security;
alter table automation_rules enable row level security;
alter table support_tickets enable row level security;
alter table service_event_log enable row level security;

-- SAFE MULTI-TENANT POLICIES

create policy portal_users_access on portal_users
for all
using (
    organization_id is not null
    and exists (
        select 1 from memberships m
        where m.organization_id = portal_users.organization_id
        and m.user_id = auth.uid()
        and m.deleted_at is null
    )
);

create policy device_commands_access on device_control_commands
for all
using (
    exists (
        select 1 from memberships m
        where m.organization_id = device_control_commands.organization_id
        and m.user_id = auth.uid()
    )
);

create policy automation_rules_access on automation_rules
for all
using (
    exists (
        select 1 from memberships m
        where m.organization_id = automation_rules.organization_id
        and m.user_id = auth.uid()
    )
);

create policy support_tickets_access on support_tickets
for all
using (
    exists (
        select 1 from memberships m
        where m.organization_id = support_tickets.organization_id
        and m.user_id = auth.uid()
    )
);

create policy service_event_log_access on service_event_log
for all
using (
    exists (
        select 1 from memberships m
        where m.organization_id = service_event_log.organization_id
        and m.user_id = auth.uid()
    )
);