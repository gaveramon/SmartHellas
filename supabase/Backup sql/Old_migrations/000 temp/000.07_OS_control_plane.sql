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