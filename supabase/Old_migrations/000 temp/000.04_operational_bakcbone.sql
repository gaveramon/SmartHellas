-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 4 - FINAL ENTERPRISE OBSERVABILITY BACKBONE
-- =====================================================

-- =====================================================
-- 000.04 PARTITION MANAGEMENT (AUTO-SAFE DESIGN)
-- =====================================================

create or replace function platform.create_monthly_partition(
    base_table text,
    start_date date
)
returns void
language plpgsql
as $$
declare
    partition_name text;
    end_date date;
begin
    partition_name := base_table || '_' || to_char(start_date, 'YYYY_MM');
    end_date := (start_date + interval '1 month')::date;

    execute format(
        'create table if not exists platform.%I partition of platform.%I
         for values from (%L) to (%L)',
        partition_name,
        base_table,
        start_date,
        end_date
    );
end;
$$;

-- =====================================================
-- 000.04 EVENT LOG (HIGH-VOLUME STREAM)
-- =====================================================

create table if not exists platform.event_log (
    id uuid default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    event_type text not null,
    source text not null, -- system | user | device | automation

    correlation_id uuid,
    device_id uuid,

    payload jsonb default '{}'::jsonb,
    severity text default 'info',

    created_at timestamptz not null default now()
) partition by range (created_at);

-- =====================================================
-- INDEX STRATEGY (CRITICAL FOR SUPPORT + SCALE)
-- =====================================================

create index if not exists idx_event_tenant_time
on platform.event_log (tenant_id, created_at desc);

create index if not exists idx_event_tenant_type_time
on platform.event_log (tenant_id, event_type, created_at desc);

create index if not exists idx_event_correlation
on platform.event_log (correlation_id);

create index if not exists idx_event_device
on platform.event_log (device_id);

-- =====================================================
-- 000.04 AUDIT LOG (IMMUTABLE COMPLIANCE LAYER)
-- =====================================================

create table if not exists platform.audit_log (
    id uuid default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    action text not null,
    entity_type text,
    entity_id uuid,

    ip_address text,
    user_agent text,

    metadata jsonb default '{}'::jsonb,

    created_at timestamptz not null default now()
) partition by range (created_at);

create index if not exists idx_audit_tenant_time
on platform.audit_log (tenant_id, created_at desc);

-- =====================================================
-- 000.04 OPERATION LOG (COMMAND EXECUTION ENGINE)
-- =====================================================

create table if not exists platform.operation_log (
    id uuid default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    correlation_id uuid not null,
    idempotency_key text,

    operation_type text not null, -- device_command | automation | onboarding

    status text not null, -- pending | success | failed | retrying

    target_type text,
    target_id uuid,

    input jsonb default '{}'::jsonb,
    output jsonb default '{}'::jsonb,
    error jsonb,

    retry_count int default 0,

    started_at timestamptz default now(),
    finished_at timestamptz
) partition by range (started_at);

create index if not exists idx_op_tenant_time
on platform.operation_log (tenant_id, started_at desc);

create index if not exists idx_op_corr
on platform.operation_log (correlation_id);

create index if not exists idx_op_status
on platform.operation_log (tenant_id, status, started_at desc);

-- =====================================================
-- 000.04 ERROR LOG (SUPPORT + DEBUGGING)
-- =====================================================

create table if not exists platform.error_log (
    id uuid default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    correlation_id uuid,

    error_type text,
    message text,
    stacktrace text,

    context jsonb default '{}'::jsonb,
    severity text default 'error',

    created_at timestamptz not null default now()
);

create index if not exists idx_error_tenant_time
on platform.error_log (tenant_id, created_at desc);

-- =====================================================
-- 000.04 SOFT DELETE LOG (RECOVERY LAYER)
-- =====================================================

create table if not exists platform.soft_delete_log (
    id uuid default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    entity_type text,
    entity_id uuid,

    reason text,
    metadata jsonb default '{}'::jsonb,

    deleted_at timestamptz default now()
);

create index if not exists idx_soft_delete_tenant
on platform.soft_delete_log (tenant_id, deleted_at desc);

-- =====================================================
-- 000.04 SAFE LOGGING FUNCTIONS (TENANT-AUTO BINDING)
-- =====================================================

create or replace function platform.log_event(
    p_event_type text,
    p_source text,
    p_payload jsonb default '{}'::jsonb,
    p_severity text default 'info',
    p_device_id uuid default null,
    p_correlation_id uuid default null
)
returns void
language plpgsql
as $$
begin
    insert into platform.event_log (
        tenant_id,
        user_id,
        event_type,
        source,
        payload,
        severity,
        device_id,
        correlation_id
    )
    values (
        platform.current_tenant_id(),
        auth.uid(),
        p_event_type,
        p_source,
        p_payload,
        p_severity,
        p_device_id,
        coalesce(p_correlation_id, gen_random_uuid())
    );
end;
$$;

-- =====================================================
-- AUDIT LOGGER
-- =====================================================

create or replace function platform.log_audit(
    p_action text,
    p_entity_type text,
    p_entity_id uuid,
    p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
as $$
begin
    insert into platform.audit_log (
        tenant_id,
        user_id,
        action,
        entity_type,
        entity_id,
        metadata
    )
    values (
        platform.current_tenant_id(),
        auth.uid(),
        p_action,
        p_entity_type,
        p_entity_id,
        p_metadata
    );
end;
$$;

-- =====================================================
-- OPERATION LOGGER (IDEMPOTENCY SAFE)
-- =====================================================

create or replace function platform.log_operation(
    p_operation_type text,
    p_status text,
    p_target_type text,
    p_target_id uuid,
    p_input jsonb default '{}'::jsonb,
    p_output jsonb default '{}'::jsonb,
    p_error jsonb default null,
    p_correlation_id uuid default null,
    p_idempotency_key text default null
)
returns void
language plpgsql
as $$
begin
    insert into platform.operation_log (
        tenant_id,
        user_id,
        correlation_id,
        idempotency_key,
        operation_type,
        status,
        target_type,
        target_id,
        input,
        output,
        error,
        finished_at
    )
    values (
        platform.current_tenant_id(),
        auth.uid(),
        coalesce(p_correlation_id, gen_random_uuid()),
        p_idempotency_key,
        p_operation_type,
        p_status,
        p_target_type,
        p_target_id,
        p_input,
        p_output,
        p_error,
        now()
    );
end;
$$;

-- =====================================================
-- RETENTION POLICY CONTRACT (IMPORTANT)
-- =====================================================

comment on schema platform is '
REV19 OBSERVABILITY RULES:

1. event_log is high-volume → short retention (recommended 30-90 days)
2. audit_log is compliance → long retention (1+ year)
3. operation_log is execution trace → medium retention (3-6 months)
4. error_log is support-critical → 90-180 days recommended
5. partitions MUST be created monthly via automation
6. tenant_id is always system-bound (never user trusted)
7. correlation_id is mandatory for traceability
';
-- =====================================================
-- END PART 4 (FINAL ENTERPRISE v2)
-- =====================================================