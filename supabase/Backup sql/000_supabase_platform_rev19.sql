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

-- Supabase ecosystem extensions (wired in Part 5 cron workers + Part 11 stubs)
create extension if not exists pg_net;

do $$
begin
    if not exists (select 1 from pg_extension where extname = 'vault') then
        create extension vault;
    end if;
exception
    when others then
        raise notice 'vault extension not available; skipping';
end $$;

do $$
begin
    if not exists (select 1 from pg_extension where extname = 'pg_cron') then
        create extension pg_cron with schema pg_catalog;
    end if;
exception
    when duplicate_object then null;
    when others then
        raise notice 'pg_cron extension not available; skipping';
end $$;

do $$
begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
        grant usage on schema cron to postgres;
        grant all privileges on all tables in schema cron to postgres;
    end if;
end $$;

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

    email citext,
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
set search_path = ''
as $$
begin
    insert into platform.profiles (id, email, full_name)
    values (
        new.id,
        new.email::citext,
        coalesce(new.raw_user_meta_data->>'full_name', '')
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

revoke all on function platform.handle_new_auth_user() from public;
grant execute on function platform.handle_new_auth_user() to service_role;

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
-- 000.02.04 PLATFORM ADMIN (SERVICE_ROLE MANAGED)
-- =====================================================

create table if not exists platform.platform_admins (
    user_id uuid primary key references platform.profiles(id) on delete cascade,
    created_at timestamptz not null default now()
);

comment on table platform.platform_admins is
    'Platform operators. Managed by service_role only.';

create or replace function platform.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from platform.platform_admins pa
        where pa.user_id = (select auth.uid())
    );
$$;

revoke all on function platform.is_platform_admin() from public;
grant execute on function platform.is_platform_admin() to authenticated, service_role;

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

-- Tenant authorization stubs are defined in PART 3 (bound in 002).

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
-- PART 3 - RLS STUBS + POLICY FACTORIES
-- (Membership implementations bound in 002)
-- =====================================================

-- =====================================================
-- 000.03.01 TENANT / RBAC STUBS (SAFE UNTIL 002)
-- =====================================================

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
as $$
    select null::uuid;
$$;

comment on function platform.current_tenant_id is
    'Stub until 002 binds membership-aware implementation.';

create or replace function platform.current_role()
returns text
language sql
stable
as $$
    select null::text;
$$;

create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
as $$
    select false;
$$;

create or replace function platform.has_role(required_role text)
returns boolean
language sql
stable
as $$
    select false;
$$;

create or replace function platform.is_owner()
returns boolean
language sql
stable
as $$
    select false;
$$;

create or replace function platform.is_admin()
returns boolean
language sql
stable
as $$
    select false;
$$;

create or replace function platform.is_support()
returns boolean
language sql
stable
as $$
    select false;
$$;

create or replace function platform.has_permission(permission text)
returns boolean
language sql
stable
as $$
    select false;
$$;

-- =====================================================
-- 000.03.02 PUBLIC TENANT ACCESS STUB (BOUND IN 002)
-- =====================================================

create or replace function public.has_tenant_access(p_public_tenant_id uuid)
returns boolean
language sql
stable
as $$
    select false;
$$;

-- =====================================================
-- 000.03.03 RLS CORE PATTERNS
-- =====================================================

create or replace function platform.rls_tenant_match(record_tenant_id uuid)
returns boolean
language sql
stable
as $$
    select record_tenant_id is not null
       and record_tenant_id = (select platform.current_tenant_id());
$$;

create or replace function platform.rls_allow(p_tenant_id uuid)
returns boolean
language sql
stable
as $$
    select platform.is_platform_admin()
        or platform.has_tenant_access(p_tenant_id);
$$;

comment on function platform.rls_allow(uuid) is
    'Use in RLS policies: platform.rls_allow(tenant_id)';

create or replace function platform.rls_allow()
returns boolean
language sql
stable
as $$
    select platform.is_platform_admin()
        or (select platform.current_tenant_id()) is not null;
$$;

comment on function platform.rls_allow() is
    'Legacy no-arg helper; prefer platform.rls_allow(uuid) in policies.';

-- =====================================================
-- 000.03.04 RLS POLICY FACTORIES
-- =====================================================

create or replace function platform._apply_tenant_rls(p_table regclass)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_schema text;
    v_table text;
begin
    select n.nspname, c.relname
    into v_schema, v_table
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.oid = p_table;

    execute format('alter table %I.%I enable row level security', v_schema, v_table);

    execute format('drop policy if exists %I on %I.%I', v_table || '_select', v_schema, v_table);
    execute format('drop policy if exists %I on %I.%I', v_table || '_insert', v_schema, v_table);
    execute format('drop policy if exists %I on %I.%I', v_table || '_update', v_schema, v_table);
    execute format('drop policy if exists %I on %I.%I', v_table || '_delete', v_schema, v_table);

    execute format(
        'create policy %I on %I.%I for select to authenticated using (platform.rls_allow(tenant_id))',
        v_table || '_select', v_schema, v_table
    );
    execute format(
        'create policy %I on %I.%I for insert to authenticated with check (platform.rls_allow(tenant_id))',
        v_table || '_insert', v_schema, v_table
    );
    execute format(
        'create policy %I on %I.%I for update to authenticated using (platform.rls_allow(tenant_id)) with check (platform.rls_allow(tenant_id))',
        v_table || '_update', v_schema, v_table
    );
    execute format(
        'create policy %I on %I.%I for delete to authenticated using (platform.rls_allow(tenant_id))',
        v_table || '_delete', v_schema, v_table
    );
end;
$$;

create or replace function platform._apply_platform_admin_rls(p_table regclass)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_schema text;
    v_table text;
begin
    select n.nspname, c.relname
    into v_schema, v_table
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.oid = p_table;

    execute format('alter table %I.%I enable row level security', v_schema, v_table);

    execute format('drop policy if exists %I on %I.%I', v_table || '_admin_all', v_schema, v_table);

    execute format(
        'create policy %I on %I.%I for all to authenticated using (platform.is_platform_admin()) with check (platform.is_platform_admin())',
        v_table || '_admin_all', v_schema, v_table
    );
end;
$$;

create or replace function public._apply_public_tenant_rls(p_table regclass)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_table text;
begin
    select c.relname into v_table
    from pg_class c
    where c.oid = p_table;

    execute format('alter table public.%I enable row level security', v_table);

    execute format('drop policy if exists %I on public.%I', v_table || '_select', v_table);
    execute format('drop policy if exists %I on public.%I', v_table || '_insert', v_table);
    execute format('drop policy if exists %I on public.%I', v_table || '_update', v_table);
    execute format('drop policy if exists %I on public.%I', v_table || '_delete', v_table);

    execute format(
        'create policy %I on public.%I for select to authenticated using (public.has_tenant_access(tenant_id))',
        v_table || '_select', v_table
    );
    execute format(
        'create policy %I on public.%I for insert to authenticated with check (public.has_tenant_access(tenant_id))',
        v_table || '_insert', v_table
    );
    execute format(
        'create policy %I on public.%I for update to authenticated using (public.has_tenant_access(tenant_id)) with check (public.has_tenant_access(tenant_id))',
        v_table || '_update', v_table
    );
    execute format(
        'create policy %I on public.%I for delete to authenticated using (public.has_tenant_access(tenant_id))',
        v_table || '_delete', v_table
    );
end;
$$;

-- =====================================================
-- 000.03.05 SECURITY CONTRACT
-- =====================================================

comment on schema platform is '
REV19 TENANT + RBAC RULES:

1. public.tenants + tenant_memberships are SSOT (002)
2. platform helpers are stubs until 002 binds implementations
3. multi-tenant users require JWT app_metadata.tenant_id or client selection
4. RLS must use platform.rls_allow(tenant_id)
5. public domain tables use public.has_tenant_access(tenant_id)
';
-- =====================================================
-- END PART 3
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
security definer
set search_path = ''
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

create or replace function platform.ensure_log_partitions(p_months_ahead int default 2)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_table text;
    v_month_start date;
    v_i int;
begin
    foreach v_table in array array['event_log', 'audit_log', 'operation_log']
    loop
        for v_i in 0..p_months_ahead loop
            v_month_start := (date_trunc('month', now()) + (v_i || ' months')::interval)::date;
            perform platform.create_monthly_partition(v_table, v_month_start);
        end loop;
    end loop;
end;
$$;

create or replace function platform.drop_old_log_partitions(
    p_base_table text,
    p_retention interval
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_partition record;
    v_cutoff date;
begin
    v_cutoff := (date_trunc('month', now()) - p_retention)::date;

    for v_partition in
        select c.relname as partition_name
        from pg_inherits i
        join pg_class c on c.oid = i.inhrelid
        join pg_class p on p.oid = i.inhparent
        join pg_namespace n on n.oid = p.relnamespace
        where n.nspname = 'platform'
          and p.relname = p_base_table
          and c.relname ~ ('^' || p_base_table || '_\d{4}_\d{2}$')
    loop
        if to_date(right(v_partition.partition_name, 7), 'YYYY_MM') < v_cutoff then
            execute format(
                'drop table if exists platform.%I',
                v_partition.partition_name
            );
        end if;
    end loop;
end;
$$;

create or replace function platform.purge_expired_logs()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform platform.drop_old_log_partitions('event_log', interval '90 days');
    perform platform.drop_old_log_partitions('audit_log', interval '365 days');
    perform platform.drop_old_log_partitions('operation_log', interval '180 days');

    delete from platform.error_log
    where created_at < now() - interval '180 days';

    delete from platform.soft_delete_log
    where deleted_at < now() - interval '180 days';
end;
$$;

-- =====================================================
-- 000.04 EVENT LOG (HIGH-VOLUME STREAM)
-- =====================================================

create table if not exists platform.event_log (
    id uuid not null default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    event_type text not null,
    source text not null, -- system | user | device | automation

    correlation_id uuid,
    device_id uuid,

    payload jsonb default '{}'::jsonb,
    severity text default 'info',

    created_at timestamptz not null default now(),

    primary key (id, created_at)
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
    id uuid not null default gen_random_uuid(),

    tenant_id uuid,
    user_id uuid,

    action text not null,
    entity_type text,
    entity_id uuid,

    ip_address inet,
    user_agent text,

    metadata jsonb default '{}'::jsonb,

    created_at timestamptz not null default now(),

    primary key (id, created_at)
) partition by range (created_at);

create index if not exists idx_audit_tenant_time
on platform.audit_log (tenant_id, created_at desc);

create or replace function platform.deny_audit_log_mutation()
returns trigger
language plpgsql
as $$
begin
    raise exception 'platform.audit_log is immutable';
end;
$$;

create trigger trg_audit_log_immutable
before update or delete on platform.audit_log
for each row execute function platform.deny_audit_log_mutation();

-- =====================================================
-- 000.04 OPERATION LOG (COMMAND EXECUTION ENGINE)
-- =====================================================

create table if not exists platform.operation_log (
    id uuid not null default gen_random_uuid(),

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

    started_at timestamptz not null default now(),
    finished_at timestamptz,

    primary key (id, started_at)
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

select platform.ensure_log_partitions(2);

-- =====================================================
-- END PART 4 (FINAL ENTERPRISE v2)
-- =====================================================

-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 5 - FULL FAULT-TOLERANT EXECUTION ENGINE
-- =====================================================

-- =====================================================
-- 000.05 COMMAND QUEUE (WITH PRIORITY + TIMEOUT SUPPORT)
-- device_id FK to public.devices added in 003
-- =====================================================

create table if not exists platform.device_commands (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,
    user_id uuid,

    device_id uuid not null,

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

create index if not exists idx_commands_device
on platform.device_commands (device_id);

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
-- 000.05B SHIPMENT DISPATCH QUEUE (CARRIER EXECUTION — 008 DOMAIN LINK IN 008)
-- Label generation and carrier API calls. fulfilment_order_id FK added in 008.
-- =====================================================

create table if not exists platform.shipment_dispatch_queue (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    fulfilment_order_id uuid not null,

    status text not null default 'pending',
    -- pending | processing | dispatched | failed | retrying | dead_letter

    tracking_number text,

    label_artifact_ref text,

    payload jsonb default '{}'::jsonb,

    retry_count int default 0,
    max_retries int default 5,

    next_retry_at timestamptz,

    last_error jsonb,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    dispatched_at timestamptz
);

create index if not exists idx_shipment_dispatch_pending
on platform.shipment_dispatch_queue (tenant_id, status, created_at);

create index if not exists idx_shipment_dispatch_fulfilment
on platform.shipment_dispatch_queue (fulfilment_order_id);

comment on table platform.shipment_dispatch_queue is
    'Carrier label/dispatch execution queue. Domain intent lives in public.fulfilment_orders (008).';

comment on column platform.shipment_dispatch_queue.label_artifact_ref is
    'Storage or vault reference to generated label PDF/ZPL — never inline binary.';

-- =====================================================
-- 000.05C SHIPMENT TRACKING EVENTS (CARRIER SCAN INGEST)
-- =====================================================

create table if not exists platform.shipment_tracking_events (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    fulfilment_order_id uuid not null,

    carrier_source text not null,

    external_event_id text not null,

    event_type text not null,

    location text,

    payload jsonb default '{}'::jsonb,

    occurred_at timestamptz not null,

    received_at timestamptz not null default now(),

    unique (carrier_source, external_event_id)
);

create index if not exists idx_shipment_tracking_fulfilment
on platform.shipment_tracking_events (fulfilment_order_id, occurred_at desc);

create index if not exists idx_shipment_tracking_tenant
on platform.shipment_tracking_events (tenant_id, received_at desc);

comment on table platform.shipment_tracking_events is
    'Idempotent carrier tracking ingest. Updates public.fulfilment_orders status via worker, not trigger.';

-- =====================================================
-- 000.05 EXECUTION WATCHDOG (TIMEOUT SYSTEM)
-- =====================================================

create or replace function platform.execution_watchdog()
returns void
language plpgsql
security definer
set search_path = ''
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
4. device_id references public.devices (FK added in 003)
5. Execution watchdog MUST run periodically (cron in 013)
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
-- 1B. WORKFLOW CONTEXT INBOX (TRANSIENT INPUT — NOT DEFINITIONS)
-- Typed context_type bound to 001 operation_context_type in 006.
-- Replaces former public.operation_contexts (business layer).
-- =====================================================

create table if not exists platform.operation_contexts (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    context_type text not null,

    payload jsonb default '{}'::jsonb,

    correlation_id uuid,

    status text not null default 'pending',
    -- pending | processed | failed

    created_at timestamptz default now(),

    processed_at timestamptz
);

create index if not exists idx_operation_contexts_pending
on platform.operation_contexts (tenant_id, status, created_at);

comment on table platform.operation_contexts is
    'Transient workflow trigger input staging. Workers consume rows; definitions live in 006.';

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
-- 2B. WEBHOOK TENANT RESOLUTION (INBOUND EDGE)
-- =====================================================

create table if not exists platform.webhook_provider_tenant_map (
    id uuid primary key default gen_random_uuid(),

    source text not null,
    external_account_id text not null,

    tenant_id uuid not null,

    created_at timestamptz not null default now(),

    unique (source, external_account_id)
);

create index if not exists idx_webhook_tenant_map_tenant
on platform.webhook_provider_tenant_map (tenant_id);

-- =====================================================
-- 2C. PAYMENT EXECUTION LAYER (CHECKOUT + CHARGE STATE)
-- Durable ledger for Stripe/VivaWallet workers. Business catalog stays in 009.
-- Inbound webhooks land in external_webhooks; workers call apply_payment_status().
-- =====================================================

create table if not exists platform.payment_intents (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider text not null,
    -- stripe | vivawallet (typed to integration_provider in 009)

    external_intent_id text,

    amount numeric(12,2) not null,

    currency text not null default 'EUR',

    status text not null default 'pending',
    -- pending | authorized | paid | failed | refunded | cancelled (payment_status in 001)

    target_type text not null,
    -- subscription | proposal | invoice

    target_id uuid not null,

    metadata jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint chk_payment_intents_currency_iso
        check (char_length(currency) = 3),

    unique (provider, external_intent_id)
);

create index if not exists idx_payment_intents_tenant_created
on platform.payment_intents (tenant_id, created_at desc);

create index if not exists idx_payment_intents_status
on platform.payment_intents (tenant_id, status, created_at desc);

create index if not exists idx_payment_intents_target
on platform.payment_intents (target_type, target_id);

create trigger trg_payment_intents_updated_at
before update on platform.payment_intents
for each row execute function platform.set_updated_at();

comment on table platform.payment_intents is
    'Durable payment/checkout state. Workers update via apply_payment_status(); never store secrets here.';

create table if not exists platform.payment_events (
    id uuid primary key default gen_random_uuid(),

    payment_intent_id uuid not null references platform.payment_intents(id) on delete cascade,

    tenant_id uuid not null,

    event_type text not null,
    -- intent_created | status_changed | provider_webhook | refund

    old_status text,
    new_status text not null,

    source text not null,
    -- webhook | worker | manual

    external_event_id text,

    payload jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now()
);

create unique index if not exists uq_payment_events_external_dedup
on platform.payment_events (payment_intent_id, external_event_id)
where external_event_id is not null;

create index if not exists idx_payment_events_intent
on platform.payment_events (payment_intent_id, created_at desc);

create index if not exists idx_payment_events_tenant_created
on platform.payment_events (tenant_id, created_at desc);

comment on table platform.payment_events is
    'Append-only payment lifecycle log. Idempotent on external_event_id when present.';

create table if not exists platform.payment_provider_refs (
    id uuid primary key default gen_random_uuid(),

    provider text not null,
    -- stripe | vivawallet (typed to integration_provider in 009)

    ref_type text not null,
    -- plan_pricing | product_plan

    internal_id uuid not null,

    external_id text not null,

    created_at timestamptz not null default now(),

    unique (provider, ref_type, internal_id)
);

create index if not exists idx_payment_provider_refs_lookup
on platform.payment_provider_refs (provider, external_id);

comment on table platform.payment_provider_refs is
    'Provider ID map for catalog rows (009 plan_pricing / product_plans). Not a business catalog.';

create or replace function platform.apply_payment_status(
    p_intent_id uuid,
    p_new_status text,
    p_source text,
    p_event_type text default 'status_changed',
    p_external_event_id text default null,
    p_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_old_status text;
    v_tenant_id uuid;
begin
    select pi.status, pi.tenant_id
    into v_old_status, v_tenant_id
    from platform.payment_intents pi
    where pi.id = p_intent_id
    for update;

    if not found then
        raise exception 'payment_intent % not found', p_intent_id;
    end if;

    if p_external_event_id is not null and exists (
        select 1
        from platform.payment_events pe
        where pe.payment_intent_id = p_intent_id
          and pe.external_event_id = p_external_event_id
    ) then
        return;
    end if;

    insert into platform.payment_events (
        payment_intent_id,
        tenant_id,
        event_type,
        old_status,
        new_status,
        source,
        external_event_id,
        payload
    )
    values (
        p_intent_id,
        v_tenant_id,
        p_event_type,
        v_old_status,
        p_new_status,
        p_source,
        p_external_event_id,
        coalesce(p_payload, '{}'::jsonb)
    );

    update platform.payment_intents
    set status = p_new_status
    where id = p_intent_id;
end;
$$;

comment on function platform.apply_payment_status(uuid, text, text, text, text, jsonb) is
    'Idempotent payment status transition. service_role only. Updates 002.subscriptions via worker, not here.';

revoke all on function platform.apply_payment_status(uuid, text, text, text, text, jsonb) from public;
grant execute on function platform.apply_payment_status(uuid, text, text, text, text, jsonb) to service_role;

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
    p_payload jsonb,
    p_tenant_id uuid default null,
    p_external_account_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant_id uuid;
begin
    v_tenant_id := coalesce(
        p_tenant_id,
        (
            select w.tenant_id
            from platform.webhook_provider_tenant_map w
            where w.source = p_source
              and w.external_account_id = p_external_account_id
        ),
        platform.current_tenant_id()
    );

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
        v_tenant_id,
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
-- 10. CRON WORKERS (RETRY + MAINTENANCE ORCHESTRATION)
-- pg_cron schedule wired in 014_platform_bootstrap_finale_rev19.sql
-- =====================================================

create or replace function platform.process_retry_tasks()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_task record;
    v_processed int := 0;
begin
    for v_task in
        select id, handler, target_type, target_id, attempt, max_attempts, payload, last_error
        from platform.retry_tasks
        where status in ('queued', 'failed')
          and (next_retry_at is null or next_retry_at <= now())
        order by next_retry_at nulls first, created_at
        limit 50
        for update skip locked
    loop
        v_processed := v_processed + 1;

        if v_task.attempt + 1 >= v_task.max_attempts then
            perform platform.archive_dead_letter(
                'retry_tasks',
                v_task.handler,
                v_task.target_type,
                v_task.target_id,
                coalesce(v_task.last_error, 'max_attempts_exceeded'),
                v_task.payload
            );

            update platform.retry_tasks
            set status = 'failed',
                attempt = v_task.attempt + 1
            where id = v_task.id;
        else
            update platform.retry_tasks
            set status = 'queued',
                attempt = v_task.attempt + 1,
                next_retry_at = now() + platform.calculate_backoff(v_task.attempt + 1),
                last_error = coalesce(last_error, 'awaiting_worker')
            where id = v_task.id;
        end if;
    end loop;

    return v_processed;
end;
$$;

create or replace function platform.process_integration_queue()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item record;
    v_processed int := 0;
begin
    for v_item in
        select id, tenant_id, integration_type, event_type, payload, retry_count, max_retries, last_error
        from platform.integration_queue
        where status in ('pending', 'failed', 'retrying')
          and (next_retry_at is null or next_retry_at <= now())
        order by next_retry_at nulls first, created_at
        limit 50
        for update skip locked
    loop
        v_processed := v_processed + 1;

        if v_item.retry_count + 1 >= v_item.max_retries then
            perform platform.archive_dead_letter(
                'integration_queue',
                coalesce(v_item.integration_type, 'integration'),
                'integration_queue',
                v_item.id,
                coalesce(v_item.last_error::text, 'max_retries_exceeded'),
                v_item.payload
            );

            update platform.integration_queue
            set status = 'dead_letter',
                retry_count = v_item.retry_count + 1
            where id = v_item.id;
        else
            update platform.integration_queue
            set status = 'retrying',
                retry_count = v_item.retry_count + 1,
                next_retry_at = now() + platform.calculate_backoff(v_item.retry_count + 1)
            where id = v_item.id;
        end if;
    end loop;

    return v_processed;
end;
$$;

create or replace function platform.enqueue_shipment_dispatch(
    p_tenant_id uuid,
    p_fulfilment_order_id uuid,
    p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id uuid;
begin
    insert into platform.shipment_dispatch_queue (
        tenant_id,
        fulfilment_order_id,
        payload
    )
    values (
        p_tenant_id,
        p_fulfilment_order_id,
        coalesce(p_payload, '{}'::jsonb)
    )
    returning id into v_id;

    return v_id;
end;
$$;

create or replace function platform.ingest_shipment_tracking_event(
    p_carrier_source text,
    p_external_event_id text,
    p_fulfilment_order_id uuid,
    p_event_type text,
    p_occurred_at timestamptz,
    p_tenant_id uuid default null,
    p_location text default null,
    p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id uuid;
begin
    insert into platform.shipment_tracking_events (
        tenant_id,
        fulfilment_order_id,
        carrier_source,
        external_event_id,
        event_type,
        location,
        payload,
        occurred_at
    )
    values (
        p_tenant_id,
        p_fulfilment_order_id,
        p_carrier_source,
        p_external_event_id,
        p_event_type,
        p_location,
        coalesce(p_payload, '{}'::jsonb),
        p_occurred_at
    )
    on conflict (carrier_source, external_event_id) do nothing
    returning id into v_id;

    return v_id;
end;
$$;

create or replace function platform.process_shipment_dispatch_queue()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item record;
    v_processed int := 0;
begin
    for v_item in
        select id, tenant_id, fulfilment_order_id, payload, retry_count, max_retries, last_error
        from platform.shipment_dispatch_queue
        where status in ('pending', 'failed', 'retrying')
          and (next_retry_at is null or next_retry_at <= now())
        order by next_retry_at nulls first, created_at
        limit 25
        for update skip locked
    loop
        v_processed := v_processed + 1;

        if v_item.retry_count + 1 >= v_item.max_retries then
            perform platform.archive_dead_letter(
                'shipment_dispatch_queue',
                'shipment',
                'shipment_dispatch_queue',
                v_item.id,
                coalesce(v_item.last_error::text, 'max_retries_exceeded'),
                v_item.payload
            );

            update platform.shipment_dispatch_queue
            set status = 'dead_letter',
                retry_count = v_item.retry_count + 1,
                updated_at = now()
            where id = v_item.id;
        else
            update platform.shipment_dispatch_queue
            set status = 'retrying',
                retry_count = v_item.retry_count + 1,
                next_retry_at = now() + platform.calculate_backoff(v_item.retry_count + 1),
                updated_at = now()
            where id = v_item.id;
        end if;
    end loop;

    return v_processed;
end;
$$;

-- =====================================================
-- ARCHITECTURE GUARANTEE (FINAL PLATFORM CONTRACT)
-- =====================================================

comment on schema platform is '
000 CHAPTER 6 FINAL RULES:

1. internal_events = immutable system event log
2. external_webhooks = idempotent ingestion layer only
3. payment_intents + payment_events = durable charge/checkout execution state
4. payment_provider_refs = Stripe/Viva ID map for 009 catalog rows
5. retry_tasks = execution abstraction (worker-driven)
6. dead_letter_archive = final failure sink only
7. event_outbox = consistency buffer only
8. no business logic allowed anywhere in 000 layer
9. handlers are abstract execution references only
10. system must remain fully reusable across SaaS products
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
-- 14. REALTIME PUBLICATION HELPER
-- =====================================================

create or replace function platform.enable_realtime(p_table regclass)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_schema text;
    v_table text;
    v_qualified text;
begin
    select n.nspname, c.relname
    into v_schema, v_table
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.oid = p_table;

    v_qualified := format('%I.%I', v_schema, v_table);

    if not exists (
        select 1
        from pg_publication_tables pt
        join pg_publication p on p.pubname = pt.pubname
        where p.pubname = 'supabase_realtime'
          and pt.schemaname = v_schema
          and pt.tablename = v_table
    ) then
        execute format(
            'alter publication supabase_realtime add table %s',
            v_qualified
        );
    end if;
end;
$$;

revoke all on function platform.enable_realtime(regclass) from public;
grant execute on function platform.enable_realtime(regclass) to service_role;

-- =====================================================
-- 15. PLATFORM CRON RUNNERS (DEFER SCHEDULE TO 013)
-- =====================================================

create or replace function platform.run_platform_cron_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_started timestamptz := clock_timestamp();
    v_retry_count int;
    v_integration_count int;
    v_shipment_count int;
    v_elapsed_ms int;
begin
    perform platform.execution_watchdog();
    v_retry_count := platform.process_retry_tasks();
    v_integration_count := platform.process_integration_queue();
    v_shipment_count := platform.process_shipment_dispatch_queue();

    v_elapsed_ms := (extract(epoch from (clock_timestamp() - v_started)) * 1000)::int;

    perform platform.record_queue_metrics(
        'platform_cron_tick',
        v_retry_count + v_integration_count + v_shipment_count,
        0,
        v_elapsed_ms,
        'ok'
    );
end;
$$;

create or replace function platform.run_platform_daily_maintenance()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_started timestamptz := clock_timestamp();
    v_elapsed_ms int;
begin
    perform platform.ensure_log_partitions(3);
    perform platform.purge_expired_logs();

    v_elapsed_ms := (extract(epoch from (clock_timestamp() - v_started)) * 1000)::int;

    perform platform.log_job_execution(
        null,
        'success',
        v_elapsed_ms,
        null,
        gen_random_uuid(),
        1
    );
end;
$$;

revoke all on function platform.run_platform_cron_tick() from public;
revoke all on function platform.run_platform_daily_maintenance() from public;
grant execute on function platform.run_platform_cron_tick() to service_role;
grant execute on function platform.run_platform_daily_maintenance() to service_role;

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

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('000_supabase_platform_rev19', 'REV19.PLATFORM.FINAL', false)
on conflict (version) do nothing;

-- =====================================================
-- END CHAPTER 8 FINAL v3
-- =====================================================

-- =====================================================
-- PART 9 - PLATFORM RLS BOOTSTRAP
-- (Public domain RLS loop deferred to 014_platform_bootstrap_finale_rev19.sql)
-- =====================================================

alter table platform.profiles enable row level security;

drop policy if exists profiles_select on platform.profiles;
drop policy if exists profiles_update on platform.profiles;

create policy profiles_select on platform.profiles
    for select to authenticated
    using (id = (select auth.uid()) or platform.is_platform_admin());

create policy profiles_update on platform.profiles
    for update to authenticated
    using (id = (select auth.uid()) or platform.is_platform_admin())
    with check (id = (select auth.uid()) or platform.is_platform_admin());

alter table platform.platform_admins enable row level security;
revoke all on table platform.platform_admins from authenticated, anon;
grant all on table platform.platform_admins to service_role;

select platform._apply_tenant_rls('platform.tenant_settings'::regclass);
select platform._apply_tenant_rls('platform.device_commands'::regclass);
select platform._apply_tenant_rls('platform.device_commands_dlq'::regclass);
select platform._apply_tenant_rls('platform.integration_queue'::regclass);
select platform._apply_tenant_rls('platform.shipment_dispatch_queue'::regclass);
select platform._apply_tenant_rls('platform.shipment_tracking_events'::regclass);
select platform._apply_tenant_rls('platform.internal_events'::regclass);
select platform._apply_tenant_rls('platform.operation_contexts'::regclass);
select platform._apply_tenant_rls('platform.external_webhooks'::regclass);
select platform._apply_tenant_rls('platform.webhook_provider_tenant_map'::regclass);
select platform._apply_tenant_rls('platform.payment_intents'::regclass);
select platform._apply_tenant_rls('platform.payment_events'::regclass);
select platform._apply_tenant_rls('platform.retry_tasks'::regclass);
select platform._apply_tenant_rls('platform.dead_letter_archive'::regclass);
select platform._apply_tenant_rls('platform.event_outbox'::regclass);
select platform._apply_tenant_rls('platform.event_log'::regclass);
select platform._apply_tenant_rls('platform.audit_log'::regclass);
select platform._apply_tenant_rls('platform.operation_log'::regclass);
select platform._apply_tenant_rls('platform.error_log'::regclass);
select platform._apply_tenant_rls('platform.soft_delete_log'::regclass);

select platform._apply_platform_admin_rls('platform.constants'::regclass);
select platform._apply_platform_admin_rls('platform.table_contracts'::regclass);
select platform._apply_platform_admin_rls('platform.schema_migrations'::regclass);
select platform._apply_platform_admin_rls('platform.migration_execution_log'::regclass);
select platform._apply_platform_admin_rls('platform.schema_change_log'::regclass);
select platform._apply_platform_admin_rls('platform.utility_function_registry'::regclass);
select platform._apply_platform_admin_rls('platform.system_nodes'::regclass);
select platform._apply_platform_admin_rls('platform.node_heartbeats'::regclass);
select platform._apply_platform_admin_rls('platform.scheduled_jobs'::regclass);
select platform._apply_platform_admin_rls('platform.job_executions'::regclass);
select platform._apply_platform_admin_rls('platform.queue_processor_logs'::regclass);
select platform._apply_platform_admin_rls('platform.system_metrics'::regclass);
select platform._apply_platform_admin_rls('platform.system_metrics_aggregated'::regclass);
select platform._apply_platform_admin_rls('platform.event_lag_monitor'::regclass);
select platform._apply_platform_admin_rls('platform.realtime_streams'::regclass);
select platform._apply_platform_admin_rls('platform.query_performance_log'::regclass);
select platform._apply_platform_admin_rls('platform.index_usage_stats'::regclass);
select platform._apply_platform_admin_rls('platform.slow_query_flags'::regclass);
select platform._apply_platform_admin_rls('platform.performance_snapshots'::regclass);
select platform._apply_platform_admin_rls('platform.execution_supervisor'::regclass);
select platform._apply_platform_admin_rls('platform.platform_admins'::regclass);
select platform._apply_platform_admin_rls('platform.payment_provider_refs'::regclass);

grant usage on schema platform to authenticated, service_role;

revoke all on function public.has_tenant_access(uuid) from public;
grant execute on function public.has_tenant_access(uuid) to authenticated, service_role;

-- =====================================================
-- END PART 9 - PLATFORM RLS BOOTSTRAP
-- =====================================================

-- =====================================================
-- PART 10 - STORAGE KERNEL
-- Path convention: {tenant_id}/{entity_type}/{file_id}
-- Avatars: {user_id}/avatar.{ext}
-- =====================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
    (
        'tenant-assets',
        'tenant-assets',
        false,
        52428800,
        null
    ),
    (
        'avatars',
        'avatars',
        true,
        5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    ),
    (
        'onboarding-docs',
        'onboarding-docs',
        false,
        104857600,
        null
    )
on conflict (id) do nothing;

create or replace function platform.storage_tenant_from_path(p_object_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
    select nullif(split_part(p_object_name, '/', 1), '')::uuid;
$$;

create or replace function platform.storage_user_from_path(p_object_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
    select nullif(split_part(p_object_name, '/', 1), '')::uuid;
$$;

comment on function platform.storage_tenant_from_path(text) is
    'Extract tenant_id from storage object path segment 1.';

comment on function platform.storage_user_from_path(text) is
    'Extract user_id from avatar path segment 1.';

-- tenant-assets: private tenant-scoped files
drop policy if exists tenant_assets_select on storage.objects;
drop policy if exists tenant_assets_insert on storage.objects;
drop policy if exists tenant_assets_update on storage.objects;
drop policy if exists tenant_assets_delete on storage.objects;

create policy tenant_assets_select on storage.objects
    for select to authenticated
    using (
        bucket_id = 'tenant-assets'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy tenant_assets_insert on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'tenant-assets'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy tenant_assets_update on storage.objects
    for update to authenticated
    using (
        bucket_id = 'tenant-assets'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    )
    with check (
        bucket_id = 'tenant-assets'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy tenant_assets_delete on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'tenant-assets'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

-- avatars: user-owned public read
drop policy if exists avatars_select on storage.objects;
drop policy if exists avatars_insert on storage.objects;
drop policy if exists avatars_update on storage.objects;
drop policy if exists avatars_delete on storage.objects;

create policy avatars_select on storage.objects
    for select to authenticated
    using (bucket_id = 'avatars');

create policy avatars_insert on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'avatars'
        and platform.storage_user_from_path(name) = (select auth.uid())
    );

create policy avatars_update on storage.objects
    for update to authenticated
    using (
        bucket_id = 'avatars'
        and platform.storage_user_from_path(name) = (select auth.uid())
    )
    with check (
        bucket_id = 'avatars'
        and platform.storage_user_from_path(name) = (select auth.uid())
    );

create policy avatars_delete on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'avatars'
        and platform.storage_user_from_path(name) = (select auth.uid())
    );

-- onboarding-docs: tenant-scoped private uploads
drop policy if exists onboarding_docs_select on storage.objects;
drop policy if exists onboarding_docs_insert on storage.objects;
drop policy if exists onboarding_docs_update on storage.objects;
drop policy if exists onboarding_docs_delete on storage.objects;

create policy onboarding_docs_select on storage.objects
    for select to authenticated
    using (
        bucket_id = 'onboarding-docs'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy onboarding_docs_insert on storage.objects
    for insert to authenticated
    with check (
        bucket_id = 'onboarding-docs'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy onboarding_docs_update on storage.objects
    for update to authenticated
    using (
        bucket_id = 'onboarding-docs'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    )
    with check (
        bucket_id = 'onboarding-docs'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

create policy onboarding_docs_delete on storage.objects
    for delete to authenticated
    using (
        bucket_id = 'onboarding-docs'
        and platform.rls_allow(platform.storage_tenant_from_path(name))
    );

-- =====================================================
-- PART 11 - VAULT + PG_NET STUBS
-- =====================================================

create or replace function platform.get_vault_secret(p_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_secret text;
begin
    if p_name is null or btrim(p_name) = '' then
        raise exception 'vault secret name is required';
    end if;

    if not exists (select 1 from pg_extension where extname = 'vault') then
        return null;
    end if;

    select ds.decrypted_secret
    into v_secret
    from vault.decrypted_secrets ds
    where ds.name = p_name
    limit 1;

    return v_secret;
end;
$$;

comment on function platform.get_vault_secret(text) is
    'Read named secret from Supabase Vault. service_role only. Returns null when vault is unavailable.';

create or replace function platform.enqueue_http_delivery(
    p_tenant_id uuid,
    p_url text,
    p_method text default 'POST',
    p_headers jsonb default '{"Content-Type": "application/json"}'::jsonb,
    p_body jsonb default '{}'::jsonb,
    p_integration_type text default 'http',
    p_event_type text default 'outbound_delivery'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_queue_id uuid;
begin
    if p_tenant_id is null then
        raise exception 'tenant_id is required for http delivery enqueue';
    end if;

    if p_url is null or btrim(p_url) = '' then
        raise exception 'url is required for http delivery enqueue';
    end if;

    insert into platform.integration_queue (
        tenant_id,
        integration_type,
        event_type,
        payload,
        status,
        next_retry_at
    )
    values (
        p_tenant_id,
        coalesce(p_integration_type, 'http'),
        coalesce(p_event_type, 'outbound_delivery'),
        jsonb_build_object(
            'url', p_url,
            'method', upper(coalesce(p_method, 'POST')),
            'headers', coalesce(p_headers, '{}'::jsonb),
            'body', coalesce(p_body, '{}'::jsonb)
        ),
        'pending',
        now()
    )
    returning id into v_queue_id;

    return v_queue_id;
end;
$$;

comment on function platform.enqueue_http_delivery(uuid, text, text, jsonb, jsonb, text, text) is
    'Enqueue outbound HTTP work into platform.integration_queue. Worker dispatches via pg_net.';

create or replace function platform.dispatch_http_request(
    p_url text,
    p_method text default 'POST',
    p_headers jsonb default '{"Content-Type": "application/json"}'::jsonb,
    p_body jsonb default '{}'::jsonb,
    p_timeout_ms int default 5000
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_request_id bigint;
    v_method text;
begin
    if not exists (select 1 from pg_extension where extname = 'pg_net') then
        return null;
    end if;

    v_method := upper(coalesce(p_method, 'POST'));

    if v_method = 'GET' then
        select net.http_get(
            url := p_url,
            headers := coalesce(p_headers, '{}'::jsonb),
            timeout_milliseconds := p_timeout_ms
        )
        into v_request_id;
    else
        select net.http_post(
            url := p_url,
            headers := coalesce(p_headers, '{}'::jsonb),
            body := coalesce(p_body, '{}'::jsonb),
            timeout_milliseconds := p_timeout_ms
        )
        into v_request_id;
    end if;

    return v_request_id;
end;
$$;

comment on function platform.dispatch_http_request(text, text, jsonb, jsonb, int) is
    'Fire-and-forget HTTP via pg_net. service_role only. Returns net request id or null.';

revoke all on function platform.get_vault_secret(text) from public;
revoke all on function platform.enqueue_http_delivery(uuid, text, text, jsonb, jsonb, text, text) from public;
revoke all on function platform.dispatch_http_request(text, text, jsonb, jsonb, int) from public;

grant execute on function platform.get_vault_secret(text) to service_role;
grant execute on function platform.enqueue_http_delivery(uuid, text, text, jsonb, jsonb, text, text) to service_role;
grant execute on function platform.dispatch_http_request(text, text, jsonb, jsonb, int) to service_role;

revoke all on function platform.enqueue_shipment_dispatch(uuid, uuid, jsonb) from public;
revoke all on function platform.ingest_shipment_tracking_event(text, text, uuid, text, timestamptz, uuid, text, jsonb) from public;
revoke all on function platform.process_shipment_dispatch_queue() from public;

grant execute on function platform.enqueue_shipment_dispatch(uuid, uuid, jsonb) to service_role;
grant execute on function platform.ingest_shipment_tracking_event(text, text, uuid, text, timestamptz, uuid, text, jsonb) to service_role;
grant execute on function platform.process_shipment_dispatch_queue() to service_role;

grant execute on function platform.storage_tenant_from_path(text) to authenticated, service_role;
grant execute on function platform.storage_user_from_path(text) to authenticated, service_role;

comment on schema platform is '
000 PART 10-11 RULES:

1. storage buckets: tenant-assets, avatars, onboarding-docs
2. tenant paths MUST start with tenant_id UUID segment
3. avatar paths MUST start with auth user_id segment
4. get_vault_secret = service_role vault read wrapper
5. enqueue_http_delivery = durable outbound HTTP via integration_queue
6. dispatch_http_request = direct pg_net stub for workers/cron
7. shipment_dispatch_queue + shipment_tracking_events = carrier execution (008 domain link)
';

-- =====================================================
-- END PART 10-11 - STORAGE + VAULT + PG_NET
-- =====================================================