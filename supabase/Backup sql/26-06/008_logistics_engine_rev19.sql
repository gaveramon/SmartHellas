-- =====================================================
-- 008 LOGISTICS ENGINE (CLEAN FULFILMENT DEFINITION LAYER)
-- NO SHIPPING EXECUTION / NO TRACKING / NO EVENTS
-- =====================================================

-- =====================================================
-- 1. LOGISTICS TEMPLATES (DELIVERY BLUEPRINTS)
-- =====================================================

create table if not exists logistics_templates (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    name text not null,

    description text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_logistics_templates_tenant
on logistics_templates (tenant_id);

-- =====================================================
-- 2. PACKAGE DEFINITIONS (WHAT GOES IN A SHIPMENT)
-- =====================================================

create table if not exists package_definitions (
    id uuid primary key default gen_random_uuid(),

    template_id uuid references logistics_templates(id) on delete cascade,

    name text not null,

    description text
);

-- =====================================================
-- 3. PACKAGE CONTENTS (DEVICE BUNDLING FOR SHIPPING)
-- =====================================================

create table if not exists package_contents (
    id uuid primary key default gen_random_uuid(),

    package_id uuid not null references package_definitions(id) on delete cascade,

    device_category device_category not null,

    quantity int default 1
);

create index if not exists idx_package_contents_package
on package_contents (package_id);

-- =====================================================
-- 4. SHIPPING CARRIERS (DEFINITION ONLY)
-- =====================================================

create table if not exists shipping_carriers (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    api_provider integration_provider,

    is_active boolean default true
);

-- =====================================================
-- 5. SHIPPING RULES (LOGIC ONLY, NO EXECUTION)
-- =====================================================

create table if not exists shipping_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    rule_name text,

    rule_config jsonb,

    is_active boolean default true,

    created_at timestamptz default now()
);

-- =====================================================
-- END 008 LOGISTICS ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================