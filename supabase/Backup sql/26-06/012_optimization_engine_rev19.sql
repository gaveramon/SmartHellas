-- =====================================================
-- 012 OPTIMIZATION ENGINE (CLEAN INTELLIGENCE LAYER)
-- NO EXECUTION / NO ACTIONS / NO SIDE EFFECTS
-- =====================================================

-- =====================================================
-- 1. OPTIMIZATION RULES (CORE INTELLIGENCE MODEL)
-- =====================================================

create table if not exists optimization_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    rule_name text not null,

    description text,

    category text,
    -- energy | security | efficiency | cost

    rule_config jsonb not null,
    -- conditions + thresholds + scoring weights

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_optimization_rules_tenant
on optimization_rules (tenant_id);

-- =====================================================
-- 2. RECOMMENDATION ENGINE OUTPUTS (NO ACTIONS)
-- =====================================================

create table if not exists optimization_recommendations (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid,

    recommendation_type text,
    -- reduce_energy | improve_security | optimize_devices

    severity text,
    -- low | medium | high

    payload jsonb,
    -- explanation + suggested changes (NOT executed)

    created_at timestamptz default now()
);

create index if not exists idx_optimization_recommendations_tenant
on optimization_recommendations (tenant_id);

-- =====================================================
-- 3. DEVICE USAGE SCORING (ANALYTICS ONLY)
-- =====================================================

create table if not exists device_usage_scores (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    score numeric(5,2),

    category text,
    -- efficiency | usage | energy | reliability

    calculated_at timestamptz default now()
);

create index if not exists idx_device_usage_scores_device
on device_usage_scores (device_id);

-- =====================================================
-- 4. ENERGY PROFILE MODEL (ANALYTICAL ONLY)
-- =====================================================

create table if not exists energy_profiles (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null,

    baseline_consumption numeric,

    optimized_consumption numeric,

    potential_savings_percent numeric,

    computed_at timestamptz default now()
);

create index if not exists idx_energy_profiles_property
on energy_profiles (property_id);

-- =====================================================
-- 5. INSIGHT EVENTS (NON-ACTIONABLE INSIGHTS ONLY)
-- =====================================================

create table if not exists insight_events (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    insight_type text,
    -- anomaly_detected | optimization_opportunity | usage_pattern

    message text,

    metadata jsonb,

    created_at timestamptz default now()
);

-- =====================================================
-- END 012 OPTIMIZATION ENGINE (CLEAN INTELLIGENCE ONLY)
-- =====================================================