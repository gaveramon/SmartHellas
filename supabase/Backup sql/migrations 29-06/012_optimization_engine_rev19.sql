-- =====================================================
-- 012 OPTIMIZATION ENGINE (CLEAN INTELLIGENCE LAYER)
-- NO EXECUTION / NO ACTIONS / NO SIDE EFFECTS
-- Advisory outputs only; execution via 000 operation_contexts after explicit approval.
-- Not operational blueprints — those live in 006.operation_templates / operation_workflows.
-- =====================================================

-- =====================================================
-- 1. OPTIMIZATION RULES (CORE INTELLIGENCE MODEL)
-- =====================================================

create table if not exists optimization_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    rule_name text not null,

    description text,

    category optimization_category,

    rule_config jsonb not null,
    -- conditions + thresholds + scoring weights

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_optimization_rules_tenant
on optimization_rules (tenant_id);

create index if not exists idx_optimization_rules_tenant_created
on optimization_rules (tenant_id, created_at desc);

comment on table public.optimization_rules is
    'Tenant-scoped scoring and threshold rules. Defines WHAT to evaluate; never executes actions.';

-- =====================================================
-- 2. INSIGHT EVENTS (NON-ACTIONABLE INSIGHTS ONLY)
-- =====================================================

create table if not exists insight_events (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete cascade,

    insight_type optimization_insight_type not null,

    severity recommendation_severity not null default 'medium',

    message text,

    metadata jsonb,

    dedup_key text,

    confidence numeric(4,3),

    ai_metadata jsonb,
    -- model name/version, prompt version (trace only; run logs live in 000)

    created_at timestamptz default now()
);

create index if not exists idx_insight_events_tenant_created
on insight_events (tenant_id, created_at desc);

create index if not exists idx_insight_events_property
on insight_events (property_id);

create unique index if not exists idx_insight_events_tenant_dedup
on insight_events (tenant_id, dedup_key)
where dedup_key is not null;

comment on table public.insight_events is
    'Non-actionable analytics insights. Detection output only; no side effects.';

-- =====================================================
-- 3. RECOMMENDATION ENGINE OUTPUTS (NO ACTIONS)
-- =====================================================

create table if not exists optimization_recommendations (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete cascade,

    source_rule_id uuid references optimization_rules(id) on delete set null,

    source_insight_id uuid references insight_events(id) on delete set null,

    recommendation_type optimization_recommendation_type not null,

    severity recommendation_severity not null default 'medium',

    status recommendation_status not null default 'open',

    explanation jsonb,

    suggested_changes jsonb,
    -- advisory parameter hints only; must not reference workflow steps or action types

    confidence numeric(4,3),

    dedup_key text,

    ai_metadata jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_optimization_recommendations_tenant_created
on optimization_recommendations (tenant_id, created_at desc);

create index if not exists idx_optimization_recommendations_property
on optimization_recommendations (property_id);

create index if not exists idx_optimization_recommendations_status
on optimization_recommendations (tenant_id, status);

create unique index if not exists idx_optimization_recommendations_tenant_dedup
on optimization_recommendations (tenant_id, dedup_key)
where dedup_key is not null;

comment on table public.optimization_recommendations is
    'Advisory outputs only. suggested_changes are non-executable hints; execution via 000 after explicit approval.';

comment on column public.optimization_recommendations.suggested_changes is
    'Advisory hints only. Must not store workflow_step_id, device commands, or automation_action_type values.';

-- =====================================================
-- 4. INSIGHT → RECOMMENDATION BACK-LINK (OPTIONAL)
-- =====================================================

alter table insight_events
    add column if not exists related_recommendation_id uuid references optimization_recommendations(id) on delete set null;

create index if not exists idx_insight_events_recommendation
on insight_events (related_recommendation_id)
where related_recommendation_id is not null;

-- =====================================================
-- 5. DEVICE USAGE SCORING (ANALYTICS ONLY)
-- =====================================================

create table if not exists device_usage_scores (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    device_id uuid not null references devices(id) on delete cascade,

    score numeric(5,2),

    category device_usage_score_category not null,

    score_period date not null default current_date,

    calculated_at timestamptz default now(),

    unique (tenant_id, device_id, category, score_period)
);

create index if not exists idx_device_usage_scores_tenant_calculated
on device_usage_scores (tenant_id, calculated_at desc);

create index if not exists idx_device_usage_scores_device
on device_usage_scores (device_id);

comment on table public.device_usage_scores is
    'Historical device scoring snapshots. Analytics only; one row per device/category/day.';

-- =====================================================
-- 6. ENERGY PROFILE MODEL (ANALYTICAL ONLY)
-- =====================================================

create table if not exists energy_profiles (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid not null references properties(id) on delete cascade,

    period_start timestamptz not null,

    period_end timestamptz not null,

    consumption_unit text not null default 'kwh',

    baseline_consumption numeric,

    optimized_consumption numeric,

    potential_savings_percent numeric,

    computed_at timestamptz default now(),

    check (period_end > period_start)
);

create index if not exists idx_energy_profiles_tenant_computed
on energy_profiles (tenant_id, computed_at desc);

create index if not exists idx_energy_profiles_property
on energy_profiles (property_id);

create index if not exists idx_energy_profiles_tenant_property_period
on energy_profiles (tenant_id, property_id, period_start desc);

comment on table public.energy_profiles is
    'Property energy baselines and savings estimates. Analytical snapshots only; no device control.';

-- =====================================================
-- 6B. PROPERTY ↔ TENANT CONSISTENCY (004 SSOT TRIGGER)
-- =====================================================

create trigger trg_insight_events_property_tenant
before insert or update on public.insight_events
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_optimization_recommendations_property_tenant
before insert or update on public.optimization_recommendations
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_energy_profiles_property_tenant
before insert or update on public.energy_profiles
for each row execute function public.enforce_property_tenant_consistency();

-- =====================================================
-- 7. RLS
-- =====================================================

alter table public.optimization_rules enable row level security;

drop policy if exists optimization_rules_select on public.optimization_rules;
drop policy if exists optimization_rules_insert on public.optimization_rules;
drop policy if exists optimization_rules_update on public.optimization_rules;
drop policy if exists optimization_rules_delete on public.optimization_rules;

create policy optimization_rules_select on public.optimization_rules
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy optimization_rules_insert on public.optimization_rules
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy optimization_rules_update on public.optimization_rules
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy optimization_rules_delete on public.optimization_rules
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.insight_events enable row level security;

drop policy if exists insight_events_select on public.insight_events;
drop policy if exists insight_events_insert on public.insight_events;
drop policy if exists insight_events_update on public.insight_events;
drop policy if exists insight_events_delete on public.insight_events;

create policy insight_events_select on public.insight_events
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

revoke insert, update, delete on table public.insight_events from authenticated, anon;
grant select on table public.insight_events to authenticated;
grant insert, update, delete on table public.insight_events to service_role;

alter table public.optimization_recommendations enable row level security;

drop policy if exists optimization_recommendations_select on public.optimization_recommendations;
drop policy if exists optimization_recommendations_insert on public.optimization_recommendations;
drop policy if exists optimization_recommendations_update on public.optimization_recommendations;
drop policy if exists optimization_recommendations_delete on public.optimization_recommendations;

create policy optimization_recommendations_select on public.optimization_recommendations
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

revoke insert on table public.optimization_recommendations from authenticated, anon;
grant insert on table public.optimization_recommendations to service_role;

create policy optimization_recommendations_update on public.optimization_recommendations
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy optimization_recommendations_delete on public.optimization_recommendations
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.device_usage_scores enable row level security;

drop policy if exists device_usage_scores_select on public.device_usage_scores;
drop policy if exists device_usage_scores_insert on public.device_usage_scores;
drop policy if exists device_usage_scores_update on public.device_usage_scores;
drop policy if exists device_usage_scores_delete on public.device_usage_scores;

create policy device_usage_scores_select on public.device_usage_scores
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy device_usage_scores_insert on public.device_usage_scores
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy device_usage_scores_update on public.device_usage_scores
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy device_usage_scores_delete on public.device_usage_scores
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.energy_profiles enable row level security;

drop policy if exists energy_profiles_select on public.energy_profiles;
drop policy if exists energy_profiles_insert on public.energy_profiles;
drop policy if exists energy_profiles_update on public.energy_profiles;
drop policy if exists energy_profiles_delete on public.energy_profiles;

create policy energy_profiles_select on public.energy_profiles
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy energy_profiles_insert on public.energy_profiles
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy energy_profiles_update on public.energy_profiles
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy energy_profiles_delete on public.energy_profiles
    for delete to authenticated
    using (platform.is_platform_admin());

-- =====================================================
-- END 012 OPTIMIZATION ENGINE (CLEAN INTELLIGENCE ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('012_optimization_engine_rev19', 'REV19.OPTIMIZATION', false)
on conflict (version) do nothing;
