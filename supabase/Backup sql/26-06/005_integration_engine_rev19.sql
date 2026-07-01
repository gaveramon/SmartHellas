-- =====================================================
-- 005 INTEGRATION ENGINE (CLEAN DEFINITION LAYER)
-- NO EXECUTION / NO LOGS / NO RUNTIME STATE
-- =====================================================

-- =====================================================
-- 1. INTEGRATION PROVIDERS (MASTER REGISTRY)
-- =====================================================

create table if not exists integration_providers (
    id uuid primary key default gen_random_uuid(),

    name integration_provider not null,

    display_name text,

    is_active boolean default true,

    created_at timestamptz default now()
);

-- =====================================================
-- 2. TENANT INTEGRATIONS (CONNECTION CONFIG ONLY)
-- =====================================================

create table if not exists tenant_integrations (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider integration_provider not null,

    config jsonb not null,
    -- e.g. API base URL, feature flags, mapping rules

    is_enabled boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_tenant_integrations_tenant
on tenant_integrations (tenant_id);

-- =====================================================
-- 3. WEBHOOK DEFINITIONS (NO EXECUTION DATA)
-- =====================================================

create table if not exists webhook_definitions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    provider integration_provider not null,

    event_type text not null,
    -- booking.created, device.status, payment.succeeded

    target_url text not null,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_webhook_definitions_provider
on webhook_definitions (provider);

-- =====================================================
-- 4. INTEGRATION CAPABILITIES (WHAT EACH PROVIDER CAN DO)
-- =====================================================

create table if not exists integration_capabilities (
    id uuid primary key default gen_random_uuid(),

    provider integration_provider not null,

    capability text not null,
    -- send_command, receive_event, sync_state, create_user

    is_supported boolean default true
);

create index if not exists idx_integration_capabilities_provider
on integration_capabilities (provider);

-- =====================================================
-- 5. DEVICE INTEGRATION MAPPING (ABSTRACT ONLY)
-- =====================================================

create table if not exists device_integration_map (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    provider integration_provider not null,

    external_id text,

    config jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_device_integration_device
on device_integration_map (device_id);

-- =====================================================
-- END 005 INTEGRATION ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================