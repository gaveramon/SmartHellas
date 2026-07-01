-- =====================================================
-- 013 CUSTOMER PROPOSAL & MONETIZATION ENGINE
-- CLEAN COMMERCIAL + CONVERSION LOGIC LAYER
-- NO EXECUTION / NO PAYMENT / NO COMMUNICATION SIDE EFFECTS
-- =====================================================

-- =====================================================
-- 1. CUSTOMER PROPOSALS (DATA MODEL ONLY)
-- =====================================================

create table if not exists customer_proposals (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid,

    status text default 'draft',
    -- draft | presented | accepted | rejected

    total_estimated_value numeric,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_customer_proposals_tenant
on customer_proposals (tenant_id);

-- =====================================================
-- 2. PROPOSAL ITEMS (WHAT IS OFFERED)
-- =====================================================

create table if not exists proposal_items (
    id uuid primary key default gen_random_uuid(),

    proposal_id uuid not null references customer_proposals(id) on delete cascade,

    item_type text,
    -- device_package | subscription | service

    reference_id uuid,

    quantity int default 1,

    price_estimate numeric
);

create index if not exists idx_proposal_items_proposal
on proposal_items (proposal_id);

-- =====================================================
-- 3. MONETIZATION PACKAGES (SERVICE + PRODUCT BUNDLES)
-- =====================================================

create table if not exists monetization_packages (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    package_type text,
    -- hardware | service | hybrid

    base_price numeric
);

-- =====================================================
-- 4. UPSELL CAMPAIGNS (CONVERSION LOGIC ONLY)
-- =====================================================

create table if not exists upsell_campaigns (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    trigger_event text,
    -- onboarding_completed | device_added | booking_created

    target_package_id uuid references monetization_packages(id),

    campaign_rules jsonb,

    is_active boolean default true
);

create index if not exists idx_upsell_campaigns_tenant
on upsell_campaigns (tenant_id);

-- =====================================================
-- 5. SERVICE ACTIVATION STATE (NOT EXECUTION)
-- =====================================================

create table if not exists service_activation_state (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid,

    service_type text,
    -- managed_service | auto_door_code | monitoring

    status text default 'inactive',
    -- inactive | pending | active | suspended

    created_at timestamptz default now()
);

-- =====================================================
-- 6. CONVERSION SCORING (ANALYTICAL ONLY)
-- =====================================================

create table if not exists conversion_scores (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    property_id uuid,

    score numeric(5,2),

    factors jsonb,

    calculated_at timestamptz default now()
);

-- =====================================================
-- END 013 MONETIZATION ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================