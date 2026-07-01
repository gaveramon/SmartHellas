-- =====================================================
-- 007 PRECONFIG ENGINE (CLEAN PROVISIONING BLUEPRINT LAYER)
-- NO EXECUTION / NO LOGGING / NO RUNTIME STATE
-- =====================================================

-- =====================================================
-- 1. PRECONFIG TEMPLATES (MASTER BLUEPRINTS)
-- =====================================================

create table if not exists preconfig_templates (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    name text not null,

    description text,

    property_type property_type,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_preconfig_templates_tenant
on preconfig_templates (tenant_id);

-- =====================================================
-- 2. DEVICE BUNDLES (STANDARD HARDWARE PACKAGES)
-- =====================================================

create table if not exists device_bundles (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text
);

-- =====================================================
-- 3. BUNDLE DEVICES (WHAT DEVICES BELONG IN A PACKAGE)
-- =====================================================

create table if not exists bundle_devices (
    id uuid primary key default gen_random_uuid(),

    bundle_id uuid not null references device_bundles(id) on delete cascade,

    device_category device_category not null,

    quantity int default 1
);

create index if not exists idx_bundle_devices_bundle
on bundle_devices (bundle_id);

-- =====================================================
-- 4. PRECONFIG DEVICE MAP (DEFAULT ROOM ASSIGNMENTS)
-- =====================================================

create table if not exists preconfig_device_map (
    id uuid primary key default gen_random_uuid(),

    template_id uuid not null references preconfig_templates(id) on delete cascade,

    device_category device_category not null,

    room_type room_type not null,

    recommended_protocol device_protocol,

    default_config jsonb
);

create index if not exists idx_preconfig_device_map_template
on preconfig_device_map (template_id);

-- =====================================================
-- 5. ONBOARDING BLUEPRINTS (HIGH LEVEL FLOW DEFINITION)
-- =====================================================

create table if not exists onboarding_blueprints (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    property_type property_type,

    steps jsonb not null,
    -- defines ordering and required actions (NOT execution)

    created_at timestamptz default now()
);

-- =====================================================
-- END 007 PRECONFIG ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================