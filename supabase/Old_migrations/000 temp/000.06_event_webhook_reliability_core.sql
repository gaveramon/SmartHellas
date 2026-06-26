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