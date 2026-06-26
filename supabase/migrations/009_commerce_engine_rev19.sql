-- =====================================================
-- 009 COMMERCE ENGINE (CLEAN COMMERCIAL DOMAIN LAYER)
-- NO PAYMENT EXECUTION / NO WEBHOOKS / NO TRANSACTIONS
-- =====================================================

-- =====================================================
-- 1. PRODUCT PLANS (COMMERCIAL OFFERING MODEL)
-- =====================================================

create table if not exists product_plans (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    tier subscription_tier not null,

    is_active boolean default true,

    created_at timestamptz default now()
);

-- =====================================================
-- 2. PLAN PRICING (STATIC PRICING MODEL)
-- =====================================================

create table if not exists plan_pricing (
    id uuid primary key default gen_random_uuid(),

    plan_id uuid not null references product_plans(id) on delete cascade,

    currency text default 'EUR',

    monthly_price numeric(10,2),

    yearly_price numeric(10,2)
);

-- =====================================================
-- 3. SUBSCRIPTION STATE (BUSINESS STATE ONLY)
-- =====================================================

create table if not exists subscriptions_commerce (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    plan_id uuid not null references product_plans(id),

    status payment_status default 'pending',
    -- pending | active | suspended | cancelled

    started_at timestamptz,

    ends_at timestamptz,

    created_at timestamptz default now()
);

create index if not exists idx_subscriptions_commerce_tenant
on subscriptions_commerce (tenant_id);

-- =====================================================
-- 4. FEATURE ENTITLEMENTS (WHAT CUSTOMER CAN USE)
-- =====================================================

create table if not exists feature_entitlements (
    id uuid primary key default gen_random_uuid(),

    plan_id uuid not null references product_plans(id) on delete cascade,

    feature_key text not null,
    -- e.g. auto_door_code, energy_reports, guest_messaging

    enabled boolean default true
);

create index if not exists idx_feature_entitlements_plan
on feature_entitlements (plan_id);

-- =====================================================
-- 5. UPSELL RULES (DEFINITION ONLY, NO EXECUTION)
-- =====================================================

create table if not exists upsell_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    trigger_event text,
    -- onboarding_completed, device_added, booking_created

    recommended_plan_id uuid references product_plans(id),

    rule_config jsonb,

    is_active boolean default true
);

-- =====================================================
-- END 009 COMMERCE ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================