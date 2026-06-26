-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 5 - FULL FAULT-TOLERANT EXECUTION ENGINE
-- =====================================================

-- =====================================================
-- 000.05 DEVICE REGISTRY
-- =====================================================

create table if not exists platform.devices (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null,

    name text not null,
    device_type text not null,
    integration_type text not null,

    external_id text,
    room text,

    metadata jsonb default '{}'::jsonb,

    is_active boolean default true,

    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_devices_tenant
on platform.devices (tenant_id);

-- =====================================================
-- 000.05 COMMAND QUEUE (WITH PRIORITY + TIMEOUT SUPPORT)
-- =====================================================

create table if not exists platform.device_commands (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,
    user_id uuid,

    device_id uuid not null references platform.devices(id),

    correlation_id uuid not null,
    idempotency_key text,

    command_type text not null,

    payload jsonb default '{}'::jsonb,

    status text default 'queued',
    -- queued | processing | success | failed | retrying | cancelled | timed_out

    priority int default 5, -- NEW: 1 = highest priority

    retry_count int default 0,
    max_retries int default 3,

    next_retry_at timestamptz, -- NEW: backoff scheduling

    worker_id text,

    scheduled_at timestamptz default now(),
    started_at timestamptz,
    finished_at timestamptz,

    execution_timeout_seconds int default 60, -- NEW

    result jsonb,
    error jsonb,

    version int default 1
);

-- =====================================================
-- IDEMPOTENCY SAFETY
-- =====================================================

create unique index if not exists uq_device_commands_idempotency
on platform.device_commands (tenant_id, idempotency_key)
where idempotency_key is not null;

-- =====================================================
-- INDEXES (SUPPORT + SCALE OPTIMIZED)
-- =====================================================

create index if not exists idx_commands_queue
on platform.device_commands (tenant_id, status, priority, scheduled_at);

create index if not exists idx_commands_retry
on platform.device_commands (tenant_id, next_retry_at);

create index if not exists idx_commands_corr
on platform.device_commands (correlation_id);

-- =====================================================
-- 000.05 DEAD LETTER QUEUE
-- =====================================================

create table if not exists platform.device_commands_dlq (
    id uuid primary key default gen_random_uuid(),

    original_command_id uuid,
    tenant_id uuid,
    device_id uuid,

    command_type text,
    payload jsonb,

    failure_reason text,
    error jsonb,

    created_at timestamptz default now()
);

-- =====================================================
-- 000.05 DEVICE STATE (WITH HISTORY ENABLEMENT)
-- =====================================================

create table if not exists platform.device_state (
    device_id uuid primary key references platform.devices(id),
    tenant_id uuid not null,

    state jsonb default '{}'::jsonb,
    state_version int default 1,

    last_sync_at timestamptz default now()
);

-- =====================================================
-- 000.05 DEVICE STATE HISTORY (NEW CRITICAL FIX)
-- =====================================================

create table if not exists platform.device_state_history (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,
    device_id uuid,

    previous_state jsonb,
    new_state jsonb,

    change_source text, -- command | webhook | manual | sync

    correlation_id uuid,

    created_at timestamptz default now()
);

create index if not exists idx_state_history_device
on platform.device_state_history (device_id, created_at desc);

-- =====================================================
-- 000.05 INTEGRATION QUEUE (RELIABILITY + DELIVERY TRACKING)
-- =====================================================

create table if not exists platform.integration_queue (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    integration_type text,
    event_type text,

    payload jsonb,

    status text default 'pending',
    -- pending | processing | sent | failed | retrying | dead_letter

    retry_count int default 0,
    max_retries int default 5,

    next_retry_at timestamptz,

    last_error jsonb,

    delivered_at timestamptz,

    created_at timestamptz default now()
);

-- =====================================================
-- 000.05 EXECUTION WATCHDOG (TIMEOUT SYSTEM)
-- =====================================================

create or replace function platform.execution_watchdog()
returns void
language plpgsql
as $$
begin
    update platform.device_commands
    set status = 'timed_out',
        finished_at = now()
    where status = 'processing'
      and started_at < now() - interval '1 minute' * execution_timeout_seconds;
end;
$$;

-- =====================================================
-- 000.05 RETRY BACKOFF CALCULATION
-- =====================================================

create or replace function platform.calculate_backoff(retry_count int)
returns interval
language sql
as $$
    select (interval '1 second' * power(2, retry_count)) +
           (interval '1 second' * random() * 2);
$$;

-- =====================================================
-- 000.05 UPDATE COMMAND STATUS (ENHANCED STATE MACHINE)
-- =====================================================

create or replace function platform.update_device_command_status(
    p_command_id uuid,
    p_status text,
    p_worker_id text,
    p_result jsonb default null,
    p_error jsonb default null
)
returns void
language plpgsql
as $$
begin
    update platform.device_commands
    set
        status = p_status,
        worker_id = coalesce(p_worker_id, worker_id),
        result = coalesce(p_result, result),
        error = p_error,

        started_at = case
            when started_at is null then now()
            else started_at
        end,

        finished_at = case
            when p_status in ('success','failed','cancelled','timed_out')
            then now()
            else finished_at
        end,

        retry_count = case
            when p_status = 'retrying' then retry_count + 1
            else retry_count
        end,

        next_retry_at = case
            when p_status = 'retrying'
            then now() + platform.calculate_backoff(retry_count)
            else next_retry_at
        end,

        version = version + 1
    where id = p_command_id;
end;
$$;

-- =====================================================
-- 000.05 FETCH NEXT COMMAND (FULL SAFE WORKER MODEL)
-- =====================================================

create or replace function platform.fetch_next_command()
returns setof platform.device_commands
language sql
as $$
    select *
    from platform.device_commands
    where status = 'queued'
      and scheduled_at <= now()
      and (next_retry_at is null or next_retry_at <= now())
    order by priority asc, scheduled_at asc
    limit 1
    for update skip locked;
$$;

-- =====================================================
-- 000.05 MOVE TO DLQ (SAFE FAILURE HANDLING)
-- =====================================================

create or replace function platform.move_to_dlq(
    p_command_id uuid,
    p_reason text,
    p_error jsonb
)
returns void
language plpgsql
as $$
declare cmd record;
begin
    select * into cmd
    from platform.device_commands
    where id = p_command_id;

    insert into platform.device_commands_dlq (
        original_command_id,
        tenant_id,
        device_id,
        command_type,
        payload,
        failure_reason,
        error
    )
    values (
        cmd.id,
        cmd.tenant_id,
        cmd.device_id,
        cmd.command_type,
        cmd.payload,
        p_reason,
        p_error
    );

    update platform.device_commands
    set status = 'failed'
    where id = p_command_id;
end;
$$;

-- =====================================================
-- 000.05 DEVICE STATE SYNC (WITH HISTORY TRACKING)
-- =====================================================

create or replace function platform.sync_device_state(
    p_device_id uuid,
    p_state jsonb,
    p_source text default 'sync',
    p_correlation_id uuid default null
)
returns void
language plpgsql
as $$
declare old_state jsonb;
begin
    select state into old_state
    from platform.device_state
    where device_id = p_device_id;

    insert into platform.device_state_history (
        tenant_id,
        device_id,
        previous_state,
        new_state,
        change_source,
        correlation_id
    )
    values (
        platform.current_tenant_id(),
        p_device_id,
        old_state,
        p_state,
        p_source,
        p_correlation_id
    );

    insert into platform.device_state (
        device_id,
        tenant_id,
        state,
        state_version,
        last_sync_at
    )
    values (
        p_device_id,
        platform.current_tenant_id(),
        p_state,
        1
    )
    on conflict (device_id)
    do update set
        state = excluded.state,
        state_version = platform.device_state.state_version + 1,
        last_sync_at = now();
end;
$$;

-- =====================================================
-- 000.05 INTEGRATION PUSH (WITH RETRY SUPPORT)
-- =====================================================

create or replace function platform.push_integration_event(
    p_integration_type text,
    p_event_type text,
    p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
as $$
begin
    insert into platform.integration_queue (
        tenant_id,
        integration_type,
        event_type,
        payload,
        next_retry_at
    )
    values (
        platform.current_tenant_id(),
        p_integration_type,
        p_event_type,
        p_payload,
        now()
    );
end;
$$;

-- =====================================================
-- 000.05 EXECUTION SUPERVISOR (SYSTEM HEALTH)
-- =====================================================

create table if not exists platform.execution_supervisor (
    id uuid primary key default gen_random_uuid(),

    metric_name text,
    metric_value jsonb,

    recorded_at timestamptz default now()
);

-- =====================================================
-- ARCHITECTURE GUARANTEE
-- =====================================================

comment on schema platform is '
REV19 EXECUTION RULES FINAL:

1. All commands MUST support priority execution
2. All retries MUST use exponential backoff
3. All failures after max_retries MUST go to DLQ
4. All device state changes MUST be historized
5. Execution watchdog MUST run periodically
6. Workers MUST use SKIP LOCKED model
7. No silent failures allowed in any subsystem
8. Integration layer MUST support retry + delay
';
-- =====================================================
-- END PART 5 FINAL v3
-- =====================================================