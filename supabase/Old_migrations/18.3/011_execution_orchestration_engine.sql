-- =====================================================
-- REV18.3 PRODUCTION HARDENED
-- 011_execution_engine.sql
-- FINAL EXECUTION + ORCHESTRATION LAYER
-- =====================================================

-- =====================================================
-- 0. EXECUTION STATUS (SEPARATE FROM BUSINESS LAYER)
-- =====================================================

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
-- 2. EXECUTION QUEUE (BASED ON OPERATION ACTIONS)
-- =====================================================

create table execution_queue (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,
    property_id uuid,

    operation_action_id uuid not null references operation_actions(id) on delete cascade,

    correlation_id uuid not null,

    device_id uuid references devices(id) on delete set null,
    integration_id uuid references integrations(id) on delete set null,

    routing_type text not null,
    -- device | integration | hybrid

    provider integration_provider,

    action_type operation_action_type not null,

    status execution_status not null default 'pending',

    priority int default 1,

    attempt int default 0,
    max_attempts int default 5,

    scheduled_at timestamptz default now(),
    started_at timestamptz,
    finished_at timestamptz,

    worker_id uuid references execution_workers(id),

    created_at timestamptz default now(),

    unique(operation_action_id)
);

create index idx_execution_queue_status on execution_queue(status);
create index idx_execution_queue_action on execution_queue(operation_action_id);
create index idx_execution_queue_device on execution_queue(device_id);
create index idx_execution_queue_corr on execution_queue(correlation_id);

-- =====================================================
-- 3. DEVICE EXECUTION MAP (ACTIVE ROUTING LAYER)
-- =====================================================

create table device_execution_map (
    id uuid primary key default gen_random_uuid(),

    provider integration_provider not null,
    device_type text not null,
    action_type operation_action_type not null,

    handler_name text not null,
    -- aqara_hub_handler | ttlock_gateway_handler | shelly_http_handler

    execution_mode text not null default 'sync',
    -- sync | async | webhook

    config jsonb default '{}'::jsonb,

    created_at timestamptz default now(),

    unique(provider, device_type, action_type)
);

-- =====================================================
-- 4. PROVIDER EXECUTION LOGS (SAFE IO TRACE)
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
-- 6. STATE RECONCILIATION ENGINE
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

create index idx_reconcile_device on state_reconciliation_jobs(device_id);

-- =====================================================
-- 7. AI EXECUTION DECISIONS (ADVISORY ONLY)
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

    created_at timestamptz default now()
);

create index idx_ai_exec_action on ai_execution_decisions(operation_action_id);

-- =====================================================
-- 8. SYSTEM EVENT BUS (QUEUE-LIKE DESIGN)
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

create index idx_event_bus_status on system_event_bus(status);

-- =====================================================
-- 9. EXECUTION TRACE (FULL OBSERVABILITY)
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
-- 10. RLS SECURITY HARDENED
-- =====================================================

alter table execution_queue enable row level security;
alter table provider_execution_logs enable row level security;
alter table ai_execution_decisions enable row level security;
alter table system_event_bus enable row level security;

-- EXECUTION QUEUE (TENANT SAFE)
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

-- PROVIDER LOGS (SCOPED VIA QUEUE)
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

-- AI DECISIONS
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

-- EVENT BUS (SYSTEM ONLY)
create policy event_bus_locked on system_event_bus
for all
using (false)
with check (false);