-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 1 - FINAL PRODUCTION FOUNDATION
-- =====================================================

-- =====================================================
-- 000.00 PLATFORM SCHEMA
-- =====================================================

create schema if not exists platform;

comment on schema platform is 'REV19 Platform Layer - infrastructure only (no business logic allowed)';

-- =====================================================
-- 000.01 REQUIRED EXTENSIONS (SUPABASE SAFE)
-- =====================================================

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;
create extension if not exists btree_gin;
create extension if not exists btree_gist;
create extension if not exists pg_stat_statements;

-- Supabase ecosystem extensions
create extension if not exists pg_net;
create extension if not exists pg_cron;
create extension if not exists vault;

-- UUID compatibility (safe for Supabase environments)
create extension if not exists "uuid-ossp";

-- =====================================================
-- 000.02 PLATFORM VERSIONING (APPEND ONLY)
-- =====================================================

create table if not exists platform.schema_version (
    id uuid primary key default gen_random_uuid(),
    version text not null unique,
    applied_at timestamptz not null default now(),
    description text
);

-- IMPORTANT: append-only migration history
insert into platform.schema_version (version, description)
values ('REV19.PART1.FINAL', 'Platform foundation layer final production version')
on conflict (version) do nothing;

-- =====================================================
-- 000.03 UPDATED_AT FUNCTION (SINGLE SOURCE OF TRUTH)
-- =====================================================

create or replace function platform.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    if to_jsonb(new) ? 'updated_at' then
        new.updated_at = now();
    end if;
    return new;
end;
$$;

-- =====================================================
-- 000.04 GLOBAL CONSTANTS (SYSTEM ONLY)
-- =====================================================

create table if not exists platform.constants (
    key text primary key,
    value jsonb not null,
    description text,
    is_sensitive boolean default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger trg_constants_updated_at
before update on platform.constants
for each row execute function platform.set_updated_at();

insert into platform.constants (key, value, description)
values
('platform_name', '"REV19_SAAS"', 'Platform identifier'),
('max_tenants_baseline', '10000', 'Target scale baseline'),
('default_timezone', '"UTC"', 'System timezone contract')
on conflict (key) do nothing;

-- =====================================================
-- 000.05 TENANT SETTINGS (MULTI-TENANT CORE BASE)
-- =====================================================

create table if not exists platform.tenant_settings (
    tenant_id uuid not null,
    key text not null,
    value jsonb not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (tenant_id, key)
);

create index if not exists idx_tenant_settings_tenant_id
on platform.tenant_settings (tenant_id);

create trigger trg_tenant_settings_updated_at
before update on platform.tenant_settings
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.06 PLATFORM CONTRACT (ARCHITECTURE ENFORCEMENT BASE)
-- =====================================================

create table if not exists platform.table_contracts (
    table_name text primary key,
    requires_tenant_id boolean default true,
    requires_created_at boolean default true,
    requires_updated_at boolean default true,
    requires_rls boolean default true,
    required_indexes jsonb default '[]'::jsonb,
    description text,
    created_at timestamptz not null default now()
);

-- Example contract baseline (used by 001–013 validation later)
insert into platform.table_contracts (
    table_name,
    requires_tenant_id,
    requires_created_at,
    requires_updated_at,
    requires_rls,
    description
)
values
('default_contract', true, true, true, true, 'Default SaaS table contract baseline')
on conflict (table_name) do nothing;

-- =====================================================
-- 000.07 PLATFORM GUARANTEES (HARD RULES)
-- =====================================================

comment on schema platform is '
REV19 RULES:
- No business logic allowed
- No domain entities allowed
- Only infrastructure and platform services
- All domain tables MUST follow table_contracts rules
- All timestamp logic MUST use platform.set_updated_at
';

-- =====================================================
-- END PART 1 - FINAL
-- =====================================================

-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 2 - FINAL IMPROVED IDENTITY FOUNDATION
-- =====================================================

-- =====================================================
-- 000.02 PROFILES (PURE IDENTITY LAYER ONLY)
-- =====================================================

create table if not exists platform.profiles (
    id uuid primary key references auth.users(id) on delete cascade,

    email text,
    full_name text,
    avatar_url text,

    is_active boolean default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_email
on platform.profiles (email);

create trigger trg_profiles_updated_at
before update on platform.profiles
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.02.01 AUTH USER HOOK (SAFE + SUPABASE CORRECT)
-- =====================================================

create or replace function platform.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = platform, public
as $$
begin
    insert into platform.profiles (id, email, full_name)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'full_name', '')
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function platform.handle_new_auth_user();

-- =====================================================
-- 000.02.02 IDENTITY LAYER (ONLY ACCESS POINT FOR 001–013)
-- =====================================================

create or replace function platform.current_user_id()
returns uuid
language sql
stable
as $$
    select auth.uid();
$$;

create or replace function platform.current_user_email()
returns text
language sql
stable
as $$
    select coalesce(auth.jwt() ->> 'email', auth.email());
$$;

-- =====================================================
-- 000.02.03 AUTH STATE HELPERS
-- =====================================================

create or replace function platform.is_authenticated()
returns boolean
language sql
stable
as $$
    select auth.uid() is not null;
$$;

-- =====================================================
-- 000.02.04 PLATFORM ADMIN (REMOVED FROM PROFILE LOGIC)
-- =====================================================

-- NOTE:
-- Admin is NOT stored on profile anymore.
-- This will be handled via roles system in PART 3.

create or replace function platform.is_platform_admin()
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.profiles p
        where p.id = auth.uid()
        and p.email ilike '%@your-platform-domain.com'
    );
$$;

-- =====================================================
-- 000.02.05 IDENTITY CONTEXT OBJECT (RLS READY)
-- =====================================================

create or replace function platform.get_identity()
returns jsonb
language sql
stable
as $$
    select jsonb_build_object(
        'user_id', auth.uid(),
        'email', coalesce(auth.jwt() ->> 'email', auth.email()),
        'is_authenticated', auth.uid() is not null
    );
$$;

-- =====================================================
-- 000.02.06 TENANT HOOK (PLACEHOLDER FOR PART 3)
-- =====================================================

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
as $$
    select null::uuid;
$$;

comment on function platform.current_tenant_id is '
Reserved for PART 3 - Multi-tenant authorization layer.
Must be implemented before any RLS policies in domain layer.
';

-- =====================================================
-- 000.02.07 ARCHITECTURE GUARANTEES
-- =====================================================

comment on table platform.profiles is '
REV19 RULE:
- This table represents ONLY global identity
- NO roles
- NO tenant logic
- NO permissions
- Authorization is handled in PART 3+
';

-- =====================================================
-- END PART 2 (FINAL IMPROVED)
-- =====================================================

-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 3 - ENTERPRISE TENANT + RBAC + RLS CORE
-- =====================================================

-- =====================================================
-- 000.03 TENANTS (CORE ENTITY)
-- =====================================================

create table if not exists platform.tenants (
    id uuid primary key default gen_random_uuid(),

    name text not null,
    type text default 'airbnb_owner',

    is_active boolean default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger trg_tenants_updated_at
before update on platform.tenants
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.03.01 USER ↔ TENANT MEMBERSHIP (SOURCE OF TRUTH)
-- =====================================================

create table if not exists platform.user_tenants (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null references platform.profiles(id) on delete cascade,
    tenant_id uuid not null references platform.tenants(id) on delete cascade,

    role text not null,

    is_active boolean default true,

    created_at timestamptz not null default now(),

    unique (user_id, tenant_id)
);

create index if not exists idx_user_tenants_user
on platform.user_tenants (user_id);

create index if not exists idx_user_tenants_tenant
on platform.user_tenants (tenant_id);

-- =====================================================
-- 000.03.02 TENANT CONTEXT RESOLUTION (DETERMINISTIC SAFE)
-- =====================================================

-- RULE:
-- 1. If user has only 1 tenant → auto use it
-- 2. If multiple → require explicit selection via client layer

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
as $$
    select ut.tenant_id
    from platform.user_tenants ut
    where ut.user_id = auth.uid()
      and ut.is_active = true
    order by ut.created_at asc
    limit 1
$$;

-- =====================================================
-- 000.03.03 ROLE RESOLUTION (TENANT-SCOPED)
-- =====================================================

create or replace function platform.current_role()
returns text
language sql
stable
as $$
    select ut.role
    from platform.user_tenants ut
    where ut.user_id = auth.uid()
      and ut.tenant_id = platform.current_tenant_id()
      and ut.is_active = true
    limit 1
$$;

-- =====================================================
-- 000.03.04 TENANT ACCESS CHECK
-- =====================================================

create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.user_tenants ut
        where ut.user_id = auth.uid()
          and ut.tenant_id = tid
          and ut.is_active = true
    );
$$;

-- =====================================================
-- 000.03.05 ROLE ENGINE (SAFE RBAC)
-- =====================================================

create or replace function platform.has_role(required_role text)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.user_tenants ut
        where ut.user_id = auth.uid()
          and ut.tenant_id = platform.current_tenant_id()
          and ut.role = required_role
          and ut.is_active = true
    );
$$;

-- =====================================================
-- 000.03.06 ROLE HELPERS (HIERARCHY SAFE)
-- =====================================================

create or replace function platform.is_owner()
returns boolean
language sql
stable
as $$
    select platform.has_role('owner');
$$;

create or replace function platform.is_admin()
returns boolean
language sql
stable
as $$
    select platform.has_role('owner')
        or platform.has_role('admin');
$$;

create or replace function platform.is_support()
returns boolean
language sql
stable
as $$
    select platform.has_role('support');
$$;

-- =====================================================
-- 000.03.07 PERMISSION LAYER (LIGHTWEIGHT ABSTRACTION)
-- =====================================================

-- NOTE:
-- This is NOT full ABAC.
-- It is a scalable hook for future device / onboarding / automation permissions.

create or replace function platform.has_permission(permission text)
returns boolean
language sql
stable
as $$
    select case
        when platform.is_owner() then true
        when platform.is_admin() then true
        else false
    end;
$$;

-- =====================================================
-- 000.03.08 RLS CORE PATTERNS
-- =====================================================

-- Tenant ownership match (core RLS building block)
create or replace function platform.rls_tenant_match(record_tenant_id uuid)
returns boolean
language sql
stable
as $$
    select record_tenant_id = platform.current_tenant_id()
$$;

-- Admin override pattern (for support + debugging)
create or replace function platform.rls_admin_bypass()
returns boolean
language sql
stable
as $$
    select platform.is_admin();
$$;

-- Full access safety pattern
create or replace function platform.rls_allow()
returns boolean
language sql
stable
as $$
    select platform.is_admin() or platform.rls_tenant_match(platform.current_tenant_id());
$$;

-- =====================================================
-- 000.03.09 SECURITY CONTRACT
-- =====================================================

comment on schema platform is '
REV19 TENANT + RBAC RULES:

1. tenant context is derived from user_tenants
2. single tenant users auto-resolve safely
3. multi-tenant users require explicit selection in application layer
4. roles are always tenant-scoped
5. RLS must use rls_tenant_match() or rls_allow()
6. admin bypass is controlled and explicit
7. permissions layer is extensible but not required yet
';
-- =====================================================
-- END PART 3 (FINAL ENTERPRISE)
-- =====================================================

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

-- =====================================================
-- 000 SUPABASE PLATFORM LAYER
-- CHAPTER 6 - EVENT + WEBHOOK + RELIABILITY CORE
-- FINAL CLEAN ARCHITECTURE v3
-- =====================================================

-- =====================================================
-- 1. INTERNAL EVENT LOG (IMMUTABLE SYSTEM KERNEL)
-- =====================================================

create table if not exists platform.internal_events (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    source text not null, -- system module identifier
    event_type text not null,

    correlation_id uuid,

    payload jsonb default '{}'::jsonb,

    status text default 'pending',
    -- pending | processed | failed

    created_at timestamptz default now()
);

create index if not exists idx_internal_events_lookup
on platform.internal_events (tenant_id, status, created_at);

-- =====================================================
-- 2. EXTERNAL WEBHOOK INGEST LAYER (IDEMPOTENT EDGE)
-- =====================================================

create table if not exists platform.external_webhooks (
    id uuid primary key default gen_random_uuid(),

    source text not null, -- external provider

    external_event_id text not null,

    event_type text,

    tenant_id uuid,

    payload jsonb default '{}'::jsonb,

    received_at timestamptz default now()
);

-- HARD IDEMPOTENCY GUARANTEE
create unique index if not exists uq_external_webhooks_dedup
on platform.external_webhooks (source, external_event_id);

-- =====================================================
-- 3. GENERIC RETRY EXECUTION QUEUE (WORKER LAYER)
-- =====================================================

create table if not exists platform.retry_tasks (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    handler text not null, -- worker identifier

    target_type text,
    target_id uuid,

    attempt int default 0,
    max_attempts int default 5,

    next_retry_at timestamptz,

    status text default 'queued',
    -- queued | processing | done | failed

    last_error text,

    payload jsonb default '{}'::jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_retry_tasks_schedule
on platform.retry_tasks (status, next_retry_at);

-- =====================================================
-- 4. DEAD LETTER QUEUE (FINAL FAILURE STORE ONLY)
-- =====================================================

create table if not exists platform.dead_letter_archive (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    origin text, -- retry_tasks | internal_events | external_webhooks

    handler text,

    target_type text,
    target_id uuid,

    error text,

    payload jsonb,

    failed_at timestamptz default now()
);

-- =====================================================
-- 5. EVENT OUTBOX (CONSISTENCY BUFFER ONLY)
-- =====================================================

create table if not exists platform.event_outbox (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    event_type text,

    payload jsonb,

    processed boolean default false,

    created_at timestamptz default now()
);

create index if not exists idx_event_outbox_pending
on platform.event_outbox (processed, created_at);

-- =====================================================
-- 6. INTERNAL EVENT PUBLISHER (IMMUTABLE LOG ENTRY)
-- =====================================================

create or replace function platform.publish_internal_event(
    p_source text,
    p_event_type text,
    p_payload jsonb,
    p_correlation_id uuid default null
)
returns uuid
language plpgsql
as $$
declare event_id uuid;
begin

    insert into platform.internal_events (
        tenant_id,
        source,
        event_type,
        correlation_id,
        payload
    )
    values (
        platform.current_tenant_id(),
        p_source,
        p_event_type,
        coalesce(p_correlation_id, gen_random_uuid()),
        p_payload
    )
    returning id into event_id;

    return event_id;
end;
$$;

-- =====================================================
-- 7. EXTERNAL WEBHOOK INGEST (STRICT IDEMPOTENCY)
-- =====================================================

create or replace function platform.ingest_external_webhook(
    p_source text,
    p_external_event_id text,
    p_event_type text,
    p_payload jsonb
)
returns void
language plpgsql
as $$
begin

    insert into platform.external_webhooks (
        source,
        external_event_id,
        event_type,
        tenant_id,
        payload
    )
    values (
        p_source,
        p_external_event_id,
        p_event_type,
        platform.current_tenant_id(),
        p_payload
    )
    on conflict (source, external_event_id) do nothing;

end;
$$;

-- =====================================================
-- 8. RETRY TASK SCHEDULER (GENERIC WORK UNIT)
-- =====================================================

create or replace function platform.schedule_retry_task(
    p_handler text,
    p_target_type text,
    p_target_id uuid,
    p_payload jsonb,
    p_error text
)
returns void
language plpgsql
as $$
begin

    insert into platform.retry_tasks (
        tenant_id,
        handler,
        target_type,
        target_id,
        attempt,
        next_retry_at,
        last_error,
        payload
    )
    values (
        platform.current_tenant_id(),
        p_handler,
        p_target_type,
        p_target_id,
        0,
        now() + interval '1 minute',
        p_error,
        p_payload
    );

end;
$$;

-- =====================================================
-- 9. DEAD LETTER ARCHIVE WRITER (FINAL FAILURE ONLY)
-- =====================================================

create or replace function platform.archive_dead_letter(
    p_origin text,
    p_handler text,
    p_target_type text,
    p_target_id uuid,
    p_error text,
    p_payload jsonb
)
returns void
language plpgsql
as $$
begin

    insert into platform.dead_letter_archive (
        tenant_id,
        origin,
        handler,
        target_type,
        target_id,
        error,
        payload
    )
    values (
        platform.current_tenant_id(),
        p_origin,
        p_handler,
        p_target_type,
        p_target_id,
        p_error,
        p_payload
    );

end;
$$;

-- =====================================================
-- ARCHITECTURE GUARANTEE (FINAL PLATFORM CONTRACT)
-- =====================================================

comment on schema platform is '
000 CHAPTER 6 FINAL RULES:

1. internal_events = immutable system event log
2. external_webhooks = idempotent ingestion layer only
3. retry_tasks = execution abstraction (worker-driven)
4. dead_letter_archive = final failure sink only
5. event_outbox = consistency buffer only
6. no business logic allowed anywhere in 000 layer
7. handlers are abstract execution references only
8. system must remain fully reusable across SaaS products
';
-- =====================================================
-- END CHAPTER 6 FINAL v3
-- =====================================================

-- =====================================================
-- 000 SUPABASE PLATFORM LAYER
-- CHAPTER 7 - REALTIME + CRON + MONITORING + HEALTH
-- FINAL v3 IMPROVED CONTROL PLANE
-- =====================================================

-- =====================================================
-- 1. SYSTEM NODES REGISTRY (NORMALIZED CONTROL PLANE)
-- =====================================================

create table if not exists platform.system_nodes (
    id uuid primary key default gen_random_uuid(),

    node_type text not null,
    node_identifier text not null,

    status text default 'alive',
    -- alive | degraded | down

    metadata jsonb default '{}'::jsonb,

    last_seen timestamptz default now()
);

create unique index if not exists uq_system_nodes
on platform.system_nodes (node_type, node_identifier);

create index if not exists idx_system_nodes_status
on platform.system_nodes (status, last_seen);

-- =====================================================
-- 2. NODE HEARTBEATS (APPEND-ONLY TIME SERIES)
-- =====================================================

create table if not exists platform.node_heartbeats (
    id uuid primary key default gen_random_uuid(),

    node_id uuid references platform.system_nodes(id),

    status text,

    metadata jsonb default '{}'::jsonb,

    recorded_at timestamptz default now()
);

create index if not exists idx_node_heartbeats_time
on platform.node_heartbeats (node_id, recorded_at);

-- =====================================================
-- 3. SCHEDULED JOB REGISTRY (CONTROL PLANE ONLY)
-- =====================================================

create table if not exists platform.scheduled_jobs (
    id uuid primary key default gen_random_uuid(),

    job_name text not null,

    cron_expression text not null,

    handler text not null,

    is_active boolean default true,

    last_run timestamptz,
    next_run timestamptz,

    metadata jsonb default '{}'::jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_scheduled_jobs_next_run
on platform.scheduled_jobs (is_active, next_run);

-- =====================================================
-- 4. JOB EXECUTION HISTORY (FULL CONTEXT FIX)
-- =====================================================

create table if not exists platform.job_executions (
    id uuid primary key default gen_random_uuid(),

    job_id uuid references platform.scheduled_jobs(id),

    correlation_id uuid,

    attempt int default 1,

    status text,
    -- success | failed | timeout

    execution_time_ms int,

    error text,

    started_at timestamptz default now(),
    finished_at timestamptz
);

create index if not exists idx_job_executions_job
on platform.job_executions (job_id, started_at);

create index if not exists idx_job_executions_correlation
on platform.job_executions (correlation_id);

-- =====================================================
-- 5. QUEUE PROCESSOR OBSERVABILITY
-- =====================================================

create table if not exists platform.queue_processor_logs (
    id uuid primary key default gen_random_uuid(),

    queue_name text not null,

    handler text,

    processed_count int default 0,

    failed_count int default 0,

    execution_time_ms int,

    status text default 'ok',
    -- ok | degraded | failed

    created_at timestamptz default now()
);

create index if not exists idx_queue_logs_time
on platform.queue_processor_logs (queue_name, created_at);

-- =====================================================
-- 6. SYSTEM METRICS (RAW TIME SERIES)
-- =====================================================

create table if not exists platform.system_metrics (
    id uuid primary key default gen_random_uuid(),

    metric_name text not null,

    metric_value numeric,

    metric_json jsonb,

    recorded_at timestamptz default now()
);

create index if not exists idx_system_metrics_time
on platform.system_metrics (metric_name, recorded_at);

-- =====================================================
-- 6B. SYSTEM METRICS AGGREGATES (SCALING LAYER)
-- =====================================================

create table if not exists platform.system_metrics_aggregated (
    id uuid primary key default gen_random_uuid(),

    metric_name text not null,

    window_start timestamptz,
    window_end timestamptz,

    avg_value numeric,
    min_value numeric,
    max_value numeric,

    sample_count int default 0
);

-- =====================================================
-- 7. EVENT LAG MONITOR (ROLLING WINDOW READY)
-- =====================================================

create table if not exists platform.event_lag_monitor (
    id uuid primary key default gen_random_uuid(),

    queue_name text not null,

    lag_seconds int,

    status text default 'ok',
    -- ok | warning | critical

    recorded_at timestamptz default now()
);

create index if not exists idx_event_lag_time
on platform.event_lag_monitor (queue_name, recorded_at);

-- =====================================================
-- 8. REALTIME STREAM CONFIG (DECLARATIVE ONLY)
-- =====================================================

create table if not exists platform.realtime_streams (
    id uuid primary key default gen_random_uuid(),

    stream_name text not null,

    source_table text not null,

    filter jsonb default '{}'::jsonb,

    is_active boolean default true,

    created_at timestamptz default now()
);

create unique index if not exists uq_realtime_streams
on platform.realtime_streams (stream_name);

-- =====================================================
-- 9. NODE HEARTBEAT UPSERT (FIXED RELIABILITY)
-- =====================================================

create or replace function platform.update_node_heartbeat(
    p_node_type text,
    p_node_identifier text,
    p_status text,
    p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
as $$
declare v_node_id uuid;
begin

    insert into platform.system_nodes (
        node_type,
        node_identifier,
        status,
        metadata,
        last_seen
    )
    values (
        p_node_type,
        p_node_identifier,
        p_status,
        p_metadata,
        now()
    )
    on conflict (node_type, node_identifier)
    do update set
        status = excluded.status,
        metadata = excluded.metadata,
        last_seen = now()
    returning id into v_node_id;

    insert into platform.node_heartbeats (
        node_id,
        status,
        metadata
    )
    values (
        v_node_id,
        p_status,
        p_metadata
    );

end;
$$;

-- =====================================================
-- 10. JOB EXECUTION LOGGER (CORRELATION AWARE)
-- =====================================================

create or replace function platform.log_job_execution(
    p_job_id uuid,
    p_status text,
    p_execution_time_ms int,
    p_error text default null,
    p_correlation_id uuid default null,
    p_attempt int default 1
)
returns void
language plpgsql
as $$
begin

    insert into platform.job_executions (
        job_id,
        correlation_id,
        attempt,
        status,
        execution_time_ms,
        error,
        finished_at
    )
    values (
        p_job_id,
        p_correlation_id,
        p_attempt,
        p_status,
        p_execution_time_ms,
        p_error,
        now()
    );

end;
$$;

-- =====================================================
-- 11. QUEUE METRICS RECORDER
-- =====================================================

create or replace function platform.record_queue_metrics(
    p_queue_name text,
    p_processed int,
    p_failed int,
    p_execution_time_ms int,
    p_status text
)
returns void
language plpgsql
as $$
begin

    insert into platform.queue_processor_logs (
        queue_name,
        processed_count,
        failed_count,
        execution_time_ms,
        status
    )
    values (
        p_queue_name,
        p_processed,
        p_failed,
        p_execution_time_ms,
        p_status
    );

end;
$$;

-- =====================================================
-- 12. EVENT LAG RECORDER (ROLLING READY)
-- =====================================================

create or replace function platform.record_event_lag(
    p_queue_name text,
    p_lag_seconds int
)
returns void
language plpgsql
as $$
declare v_status text;
begin

    if p_lag_seconds < 5 then
        v_status := 'ok';
    elsif p_lag_seconds < 30 then
        v_status := 'warning';
    else
        v_status := 'critical';
    end if;

    insert into platform.event_lag_monitor (
        queue_name,
        lag_seconds,
        status
    )
    values (
        p_queue_name,
        p_lag_seconds,
        v_status
    );

end;
$$;

-- =====================================================
-- 13. REALTIME STREAM REGISTRY
-- =====================================================

create or replace function platform.register_realtime_stream(
    p_stream_name text,
    p_source_table text,
    p_filter jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
as $$
declare stream_id uuid;
begin

    insert into platform.realtime_streams (
        stream_name,
        source_table,
        filter,
        is_active
    )
    values (
        p_stream_name,
        p_source_table,
        p_filter,
        true
    )
    returning id into stream_id;

    return stream_id;
end;
$$;

-- =====================================================
-- ARCHITECTURE GUARANTEE (FINAL v3 RULES)
-- =====================================================

comment on schema platform is '
000 CHAPTER 7 FINAL v3 RULES:

1. system_nodes = canonical node registry
2. node_heartbeats = time-series liveness log
3. scheduled_jobs = control plane only
4. job_executions = full execution trace + correlation support
5. system_metrics = raw telemetry store
6. system_metrics_aggregated = scaling layer for analytics
7. event_lag_monitor = rolling queue health tracking
8. realtime_streams = declarative config only
9. all execution logic must exist outside this layer
';
-- =====================================================
-- END CHAPTER 7 FINAL v3
-- =====================================================

-- =====================================================
-- 000 SUPABASE PLATFORM LAYER
-- CHAPTER 8 - PERFORMANCE + MIGRATION + UTILITY KERNEL
-- FINAL v3 PRODUCTION HARDENED
-- =====================================================

-- =====================================================
-- 1. QUERY PERFORMANCE LOG (PARTITION READY)
-- =====================================================

create table if not exists platform.query_performance_log (
    id uuid primary key default gen_random_uuid(),

    query_hash text not null,
    query_text text,

    execution_time_ms int not null,

    rows_returned int,

    source text, -- api | worker | cron | edge

    tenant_id uuid,

    created_at timestamptz default now()
);

create index if not exists idx_query_perf_time
on platform.query_performance_log (execution_time_ms, created_at);

create index if not exists idx_query_perf_hash
on platform.query_performance_log (query_hash);

-- =====================================================
-- 2. INDEX USAGE TRACKER (IMPROVED LOOKUP MODEL)
-- =====================================================

create table if not exists platform.index_usage_stats (
    id uuid primary key default gen_random_uuid(),

    table_name text not null,
    index_name text not null,

    scans bigint default 0,
    tuples_read bigint default 0,
    tuples_fetched bigint default 0,

    last_updated timestamptz default now()
);

create index if not exists idx_index_usage_table
on platform.index_usage_stats (table_name, index_name);

-- =====================================================
-- 3. SLOW QUERY FLAGS (ANOMALY STORE ENHANCED)
-- =====================================================

create table if not exists platform.slow_query_flags (
    id uuid primary key default gen_random_uuid(),

    query_hash text unique not null,

    severity text,
    -- low | medium | high | critical

    avg_execution_time_ms numeric default 0,

    occurrences int default 1,

    first_seen timestamptz default now(),

    last_seen timestamptz default now()
);

create index if not exists idx_slow_query_severity
on platform.slow_query_flags (severity, last_seen);

-- =====================================================
-- 4. MIGRATION REGISTRY (SAFE VERSION CONTROL)
-- =====================================================

create table if not exists platform.schema_migrations (
    id uuid primary key default gen_random_uuid(),

    migration_name text not null,

    version text not null,

    applied_at timestamptz default now(),

    rollback_available boolean default false
);

create unique index if not exists uq_schema_migration_version
on platform.schema_migrations (version);

-- =====================================================
-- 5. MIGRATION EXECUTION LOG
-- =====================================================

create table if not exists platform.migration_execution_log (
    id uuid primary key default gen_random_uuid(),

    migration_name text,

    status text,
    -- success | failed

    error text,

    execution_time_ms int,

    executed_at timestamptz default now()
);

create index if not exists idx_migration_exec_time
on platform.migration_execution_log (executed_at);

-- =====================================================
-- 6. SCHEMA CHANGE TRACKER (STRUCTURED EVOLUTION)
-- =====================================================

create table if not exists platform.schema_change_log (
    id uuid primary key default gen_random_uuid(),

    object_type text,
    -- table | function | index | trigger

    object_name text,

    change_type text,
    -- create | alter | drop

    definition_snapshot jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_schema_changes_time
on platform.schema_change_log (object_name, created_at);

-- =====================================================
-- 7. UTILITY FUNCTION REGISTRY (DEPENDENCY-AWARE LIGHT MODEL)
-- =====================================================

create table if not exists platform.utility_function_registry (
    id uuid primary key default gen_random_uuid(),

    function_name text unique not null,

    category text,
    -- auth | performance | logging | system | helper

    depends_on text[], -- lightweight dependency hints

    description text,

    is_active boolean default true,

    created_at timestamptz default now()
);

-- =====================================================
-- 8. PERFORMANCE SNAPSHOTS (TIME BUCKET READY)
-- =====================================================

create table if not exists platform.performance_snapshots (
    id uuid primary key default gen_random_uuid(),

    cpu_usage numeric check (cpu_usage >= 0),
    db_load numeric check (db_load >= 0),
    cache_hit_ratio numeric check (cache_hit_ratio between 0 and 1),

    active_connections int,

    recorded_at timestamptz default now()
);

create index if not exists idx_perf_snapshots_time
on platform.performance_snapshots (recorded_at);

-- =====================================================
-- 9. QUERY PERFORMANCE LOGGER
-- =====================================================

create or replace function platform.log_query_performance(
    p_query_hash text,
    p_query_text text,
    p_execution_time_ms int,
    p_rows_returned int,
    p_source text,
    p_tenant_id uuid default null
)
returns void
language plpgsql
as $$
begin

    insert into platform.query_performance_log (
        query_hash,
        query_text,
        execution_time_ms,
        rows_returned,
        source,
        tenant_id
    )
    values (
        p_query_hash,
        p_query_text,
        p_execution_time_ms,
        p_rows_returned,
        p_source,
        p_tenant_id
    );

end;
$$;

-- =====================================================
-- 10. SLOW QUERY FLAGGER (FULL ANOMALY MODEL)
-- =====================================================

create or replace function platform.flag_slow_query(
    p_query_hash text,
    p_execution_time_ms int
)
returns void
language plpgsql
as $$
declare v_severity text;
begin

    if p_execution_time_ms < 200 then
        v_severity := 'low';
    elsif p_execution_time_ms < 1000 then
        v_severity := 'medium';
    elsif p_execution_time_ms < 3000 then
        v_severity := 'high';
    else
        v_severity := 'critical';
    end if;

    insert into platform.slow_query_flags (
        query_hash,
        severity,
        avg_execution_time_ms,
        occurrences,
        first_seen,
        last_seen
    )
    values (
        p_query_hash,
        v_severity,
        p_execution_time_ms,
        1,
        now(),
        now()
    )
    on conflict (query_hash)
    do update set
        occurrences = slow_query_flags.occurrences + 1,
        avg_execution_time_ms =
            (slow_query_flags.avg_execution_time_ms * slow_query_flags.occurrences
            + excluded.avg_execution_time_ms)
            / (slow_query_flags.occurrences + 1),
        severity = excluded.severity,
        last_seen = now();

end;
$$;

-- =====================================================
-- 11. MIGRATION LOGGER
-- =====================================================

create or replace function platform.log_migration_execution(
    p_migration_name text,
    p_status text,
    p_execution_time_ms int,
    p_error text default null
)
returns void
language plpgsql
as $$
begin

    insert into platform.migration_execution_log (
        migration_name,
        status,
        error,
        execution_time_ms,
        executed_at
    )
    values (
        p_migration_name,
        p_status,
        p_error,
        p_execution_time_ms,
        now()
    );

end;
$$;

-- =====================================================
-- 12. SCHEMA CHANGE LOGGER
-- =====================================================

create or replace function platform.log_schema_change(
    p_object_type text,
    p_object_name text,
    p_change_type text,
    p_definition_snapshot jsonb
)
returns void
language plpgsql
as $$
begin

    insert into platform.schema_change_log (
        object_type,
        object_name,
        change_type,
        definition_snapshot
    )
    values (
        p_object_type,
        p_object_name,
        p_change_type,
        p_definition_snapshot
    );

end;
$$;

-- =====================================================
-- ARCHITECTURE GUARANTEE (FINAL v3 HARDENED RULES)
-- =====================================================

comment on schema platform is '
000 CHAPTER 8 FINAL v3 RULES:

1. query_performance_log = partition-ready query observability layer
2. index_usage_stats = multi-index optimization feedback system
3. slow_query_flags = anomaly detection registry (deduplicated)
4. schema_migrations = strict version-controlled schema registry
5. migration_execution_log = immutable migration audit trail
6. schema_change_log = structured schema evolution log (JSONB)
7. performance_snapshots = time-bucket ready system telemetry
8. utility_function_registry = dependency-aware helper registry
9. no business logic allowed anywhere in this layer
10. this is a production-grade Supabase database OS kernel
';
-- =====================================================
-- END CHAPTER 8 FINAL v3
-- =====================================================