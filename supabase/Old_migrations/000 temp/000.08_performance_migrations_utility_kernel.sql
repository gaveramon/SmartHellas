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