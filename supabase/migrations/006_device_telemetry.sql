-- =====================================================
-- REV22 GREENFIELD BASELINE
-- 006_DEVICE_TELEMETRY.SQL
--
-- Purpose:
-- Raw device telemetry ingestion and immutable storage
--
-- Authority:
-- 004_property_device_engine.sql = DEVICE SSOT
--
-- SSOT RULE:
-- This module stores RAW DEVICE INPUT only.
--
-- ALLOWED:
-- - raw provider payload
-- - device reference
-- - tenant reference
-- - provider/source metadata
-- - provider event identifier
-- - provider timestamps
-- - ingestion timestamp
--
-- NOT ALLOWED:
-- - derived device state
-- - latest value/state
-- - usage scores
-- - aggregations
-- - calculated metrics
-- - business rules
-- - automation decisions
-- - monetization calculations
-- - normalized domain state
--
-- Derived/normalized telemetry belongs in a later module.
-- =====================================================


begin;


-- =====================================================
-- 1. RAW DEVICE TELEMETRY
--
-- Immutable raw ingestion boundary.
--
-- device_id references the 004 device registry.
-- tenant_id is intentionally stored locally so that:
--   1. tenant isolation can be enforced directly by RLS
--   2. raw telemetry remains tenant-addressable at scale
--   3. cross-tenant device references can be rejected
--
-- raw_payload remains the authoritative representation
-- of the provider/device input.
-- =====================================================

create table if not exists public.device_telemetry_raw (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    device_id uuid not null
        references public.devices(id)
        on delete restrict,

    source text not null,

    provider_event_id text,

    observed_at timestamptz,

    received_at timestamptz not null default now(),

    raw_payload jsonb not null,

    created_at timestamptz not null default now()
);


-- =====================================================
-- 2. RAW TELEMETRY INDEXES
--
-- Optimized for:
-- - tenant scoped retrieval
-- - device history
-- - chronological ingestion
-- - provider event lookup
--
-- No indexes are created on interpreted JSON fields.
-- 006 must not impose a semantic interpretation on the
-- provider payload.
-- =====================================================

create index if not exists idx_device_telemetry_raw_tenant_received
on public.device_telemetry_raw (
    tenant_id,
    received_at desc
);


create index if not exists idx_device_telemetry_raw_device_received
on public.device_telemetry_raw (
    device_id,
    received_at desc
);


create index if not exists idx_device_telemetry_raw_device_observed
on public.device_telemetry_raw (
    device_id,
    observed_at desc
);


create index if not exists idx_device_telemetry_raw_provider_event
on public.device_telemetry_raw (
    source,
    provider_event_id
)
where provider_event_id is not null;


-- =====================================================
-- 3. DEVICE ↔ TENANT INVARIANT
--
-- 004 is the SSOT for device ownership.
--
-- Telemetry may never be written under a tenant other
-- than the tenant that owns the referenced device.
--
-- This is an integrity boundary, not business logic.
-- =====================================================

create or replace function public.enforce_device_telemetry_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_device_tenant uuid;
begin

    select d.tenant_id
    into v_device_tenant
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    if v_device_tenant <> new.tenant_id then
        raise exception
            'telemetry tenant must match device tenant';
    end if;

    return new;
end;
$$;


drop trigger if exists trg_device_telemetry_tenant_consistency
on public.device_telemetry_raw;


create trigger trg_device_telemetry_tenant_consistency
before insert on public.device_telemetry_raw
for each row
execute function public.enforce_device_telemetry_tenant_consistency();


-- =====================================================
-- 4. RAW TELEMETRY STORAGE CONTRACT
--
-- Explicitly document the SSOT boundary.
-- =====================================================

comment on table public.device_telemetry_raw is
    'Raw device telemetry ingestion boundary. Stores provider/device input only. No derived state, usage scores, aggregations, automation state, or business logic.';


comment on column public.device_telemetry_raw.tenant_id is
    'Tenant ownership copied from the 004 device SSOT for isolation and indexed tenant access. Must match devices.tenant_id.';


comment on column public.device_telemetry_raw.device_id is
    'Reference to the 004 device registry SSOT.';


comment on column public.device_telemetry_raw.source is
    'Raw telemetry source/provider identifier, e.g. aqara, ttlock, mqtt, integration.';


comment on column public.device_telemetry_raw.provider_event_id is
    'Optional provider-native event identifier used for ingestion correlation/idempotency.';


comment on column public.device_telemetry_raw.observed_at is
    'Timestamp supplied by the device/provider when available.';


comment on column public.device_telemetry_raw.received_at is
    'Timestamp at which the platform received the telemetry payload.';


comment on column public.device_telemetry_raw.raw_payload is
    'Untouched provider/device payload. This is the raw telemetry SSOT.';


comment on column public.device_telemetry_raw.created_at is
    'Database insertion timestamp.';


-- =====================================================
-- 5. ROW LEVEL SECURITY
--
-- Raw telemetry is tenant-scoped.
--
-- Authenticated users:
--   SELECT only when they have tenant access.
--
-- Direct INSERT/UPDATE/DELETE:
--   prohibited for authenticated users.
--
-- Telemetry ingestion must occur through the trusted
-- server/service layer.
-- =====================================================

alter table public.device_telemetry_raw
enable row level security;

alter table public.device_telemetry_raw
force row level security;


drop policy if exists device_telemetry_raw_select
on public.device_telemetry_raw;


drop policy if exists device_telemetry_raw_insert
on public.device_telemetry_raw;


drop policy if exists device_telemetry_raw_update
on public.device_telemetry_raw;


drop policy if exists device_telemetry_raw_delete
on public.device_telemetry_raw;


-- -----------------------------------------------------
-- 5A. SELECT
-- -----------------------------------------------------

create policy device_telemetry_raw_select
on public.device_telemetry_raw
for select
to authenticated
using (
    platform.is_platform_admin()
    or public.has_tenant_access(tenant_id)
);


-- -----------------------------------------------------
-- 5B. INSERT
--
-- No authenticated INSERT policy intentionally.
--
-- Service-role ingestion bypasses normal RLS according
-- to the platform security model.
-- -----------------------------------------------------

-- Intentionally no authenticated INSERT policy.


-- -----------------------------------------------------
-- 5C. UPDATE
--
-- Raw telemetry is append-only.
-- -----------------------------------------------------

-- Intentionally no UPDATE policy.


-- -----------------------------------------------------
-- 5D. DELETE
--
-- Raw telemetry cannot be deleted through the normal
-- authenticated application boundary.
-- -----------------------------------------------------

-- Intentionally no DELETE policy.


-- =====================================================
-- 6. PRIVILEGE BOUNDARY
--
-- Prevent direct application writes.
--
-- SELECT is exposed through RLS.
-- INSERT/UPDATE/DELETE remain service-layer operations.
-- =====================================================

revoke insert, update, delete
on public.device_telemetry_raw
from anon, authenticated;


grant select
on public.device_telemetry_raw
to authenticated;


-- =====================================================
-- 7. FUNCTION SECURITY HARDENING
--
-- The integrity trigger must never depend on an unsafe
-- caller-controlled search_path.
-- =====================================================

alter function public.enforce_device_telemetry_tenant_consistency()
set search_path = '';


-- =====================================================
-- 8. SCHEMA MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)
values (
    '006_device_telemetry',
    'REV22.DEVICE.TELEMETRY',
    false
)
on conflict (version) do nothing;


commit;


-- =====================================================
-- END 006 DEVICE TELEMETRY
--
-- SSOT BOUNDARY:
--
-- 004 = Device/domain registry SSOT
-- 006 = Raw telemetry input SSOT
--
-- Future modules may derive:
-- - normalized measurements
-- - current device state
-- - usage scores
-- - energy metrics
-- - anomaly detection
-- - automation signals
-- - monetization metrics
--
-- Such derived data MUST NOT be written into
-- device_telemetry_raw.
-- =====================================================