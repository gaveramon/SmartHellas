-- REV22 greenfield baseline: 012_optimization_engine.sql
-- Consolidated from migrations_archive_rev19 (000-053)


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



create index if not exists idx_insight_events_tenant_created
on insight_events (tenant_id, created_at desc);



create index if not exists idx_insight_events_property
on insight_events (property_id);



create unique index if not exists idx_insight_events_tenant_dedup
on insight_events (tenant_id, dedup_key)
where dedup_key is not null;



comment on table public.insight_events is
    'Non-actionable analytics insights. Detection output only; no side effects.';



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



create index if not exists idx_device_usage_scores_tenant_calculated
on device_usage_scores (tenant_id, calculated_at desc);



create index if not exists idx_device_usage_scores_device
on device_usage_scores (device_id);



comment on table public.device_usage_scores is
    'Historical device scoring snapshots. Analytics only; one row per device/category/day.';



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



-- =====================================================
-- 7. RLS
-- =====================================================

alter table public.optimization_rules enable row level security;



drop policy if exists optimization_rules_select on public.optimization_rules;


drop policy if exists optimization_rules_insert on public.optimization_rules;


drop policy if exists optimization_rules_update on public.optimization_rules;


drop policy if exists optimization_rules_delete on public.optimization_rules;



alter table public.insight_events enable row level security;



drop policy if exists insight_events_select on public.insight_events;


drop policy if exists insight_events_insert on public.insight_events;


drop policy if exists insight_events_update on public.insight_events;


drop policy if exists insight_events_delete on public.insight_events;



revoke insert, update, delete on table public.insight_events from authenticated, anon;


grant select on table public.insight_events to authenticated;


grant insert, update, delete on table public.insight_events to service_role;



alter table public.optimization_recommendations enable row level security;



drop policy if exists optimization_recommendations_select on public.optimization_recommendations;


drop policy if exists optimization_recommendations_insert on public.optimization_recommendations;


drop policy if exists optimization_recommendations_update on public.optimization_recommendations;


drop policy if exists optimization_recommendations_delete on public.optimization_recommendations;



revoke insert on table public.optimization_recommendations from authenticated, anon;


grant insert on table public.optimization_recommendations to service_role;



alter table public.device_usage_scores enable row level security;



drop policy if exists device_usage_scores_select on public.device_usage_scores;


drop policy if exists device_usage_scores_insert on public.device_usage_scores;


drop policy if exists device_usage_scores_update on public.device_usage_scores;


drop policy if exists device_usage_scores_delete on public.device_usage_scores;



alter table public.energy_profiles enable row level security;



drop policy if exists energy_profiles_select on public.energy_profiles;


drop policy if exists energy_profiles_insert on public.energy_profiles;


drop policy if exists energy_profiles_update on public.energy_profiles;


drop policy if exists energy_profiles_delete on public.energy_profiles;






create or replace function public.optimization_domain(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_row record;
    v_result jsonb;
    v_avg numeric;
    v_count int;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_rules' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at
            from public.optimization_rules r where r.tenant_id = v_tid
        ) t;

    when 'get_rule' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at
            from public.optimization_rules r
            where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Optimization rule not found'; end if;

    when 'create_rule' then
        v_tid := platform.current_tenant_id();
        insert into public.optimization_rules (tenant_id, rule_name, description, category, rule_config, is_active)
        values (
            v_tid,
            p_payload->>'rule_name',
            p_payload->>'description',
            case when p_payload ? 'category' and p_payload->>'category' is not null
                then (p_payload->>'category')::public.optimization_category else null end,
            p_payload->'rule_config',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, rule_name, description, category, rule_config, is_active, created_at into v_row;
        perform platform.log_audit('optimization_rule.created', 'optimization_rule', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_rule' then
        v_tid := platform.current_tenant_id();
        update public.optimization_rules r set
            rule_name = case when p_payload ? 'rule_name' then p_payload->>'rule_name' else r.rule_name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else r.description end,
            category = case when p_payload ? 'category'
                then case when p_payload->>'category' is null then null else (p_payload->>'category')::public.optimization_category end
                else r.category end,
            rule_config = case when p_payload ? 'rule_config' then p_payload->'rule_config' else r.rule_config end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else r.is_active end
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid
        returning r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at into v_row;
        if not found then raise exception 'Optimization rule not found'; end if;
        perform platform.log_audit('optimization_rule.updated', 'optimization_rule', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_rule' then
        v_tid := platform.current_tenant_id();
        delete from public.optimization_rules r
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid;
        if not found then raise exception 'Optimization rule not found'; end if;
        perform platform.log_audit('optimization_rule.deleted', 'optimization_rule', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_insight_events' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select i.id, i.tenant_id, i.property_id, i.insight_type, i.severity, i.message, i.metadata,
                   i.dedup_key, i.confidence, i.ai_metadata, i.related_recommendation_id, i.created_at
            from public.insight_events i
            where i.tenant_id = v_tid
              and (p_payload->>'property_id' is null or i.property_id = (p_payload->>'property_id')::uuid)
              and (p_payload->>'insight_type' is null or i.insight_type::text = p_payload->>'insight_type')
        ) t;

    when 'get_insight_event' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select i.id, i.tenant_id, i.property_id, i.insight_type, i.severity, i.message, i.metadata,
                   i.dedup_key, i.confidence, i.ai_metadata, i.related_recommendation_id, i.created_at
            from public.insight_events i
            where i.id = (p_payload->>'id')::uuid and i.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Insight event not found'; end if;

    when 'list_recommendations' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                   rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                   rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at
            from public.optimization_recommendations rec
            where rec.tenant_id = v_tid
              and (p_payload->>'status' is null or rec.status::text = p_payload->>'status')
              and (p_payload->>'property_id' is null or rec.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_recommendation' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                   rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                   rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at
            from public.optimization_recommendations rec
            where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Recommendation not found'; end if;

    when 'update_recommendation' then
        v_tid := platform.current_tenant_id();
        update public.optimization_recommendations rec set
            status = (p_payload->>'status')::public.recommendation_status
        where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid
        returning rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                  rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                  rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at into v_row;
        if not found then raise exception 'Recommendation not found'; end if;
        perform platform.log_audit('optimization_recommendation.updated', 'optimization_recommendation', v_row.id,
            jsonb_build_object('status', v_row.status));
        v_result := to_jsonb(v_row);

    when 'delete_recommendation' then
        v_tid := platform.current_tenant_id();
        delete from public.optimization_recommendations rec
        where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid;
        if not found then raise exception 'Recommendation not found'; end if;
        perform platform.log_audit('optimization_recommendation.deleted', 'optimization_recommendation', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_usage_scores' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.calculated_at desc), '[]'::jsonb) into v_result
        from (
            select s.id, s.tenant_id, s.device_id, s.score, s.category, s.score_period, s.calculated_at
            from public.device_usage_scores s
            where s.tenant_id = v_tid
              and (p_payload->>'device_id' is null or s.device_id = (p_payload->>'device_id')::uuid)
        ) t;

    when 'list_energy_profiles' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.computed_at desc), '[]'::jsonb) into v_result
        from (
            select e.id, e.tenant_id, e.property_id, e.period_start, e.period_end, e.consumption_unit,
                   e.baseline_consumption, e.optimized_consumption, e.potential_savings_percent, e.computed_at
            from public.energy_profiles e
            where e.tenant_id = v_tid
              and (p_payload->>'property_id' is null or e.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_energy_profile' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select e.id, e.tenant_id, e.property_id, e.period_start, e.period_end, e.consumption_unit,
                   e.baseline_consumption, e.optimized_consumption, e.potential_savings_percent, e.computed_at
            from public.energy_profiles e
            where e.id = (p_payload->>'id')::uuid and e.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Energy profile not found'; end if;

    when 'calculate_property_score' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        select avg(s.score)::numeric, count(*)::int
        into v_avg, v_count
        from public.device_usage_scores s
        join public.devices d on d.id = s.device_id
        join public.device_assignments da on da.device_id = d.id
        join public.rooms r on r.id = da.room_id
        where s.tenant_id = v_tid
          and r.property_id = (p_payload->>'property_id')::uuid;
        v_result := jsonb_build_object(
            'property_id', p_payload->>'property_id',
            'score', coalesce(v_avg, 0),
            'device_count', coalesce(v_count, 0),
            'calculated_at', now()
        );

    else
        raise exception 'unknown optimization_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;



create policy device_usage_scores_delete on public.device_usage_scores
    for delete to authenticated
    using (platform.is_platform_admin());



create policy device_usage_scores_insert on public.device_usage_scores
    for insert to authenticated
    with check (platform.is_platform_admin());



create policy device_usage_scores_select on public.device_usage_scores
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy device_usage_scores_update on public.device_usage_scores
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());



create policy energy_profiles_delete on public.energy_profiles
    for delete to authenticated
    using (platform.is_platform_admin());



create policy energy_profiles_insert on public.energy_profiles
    for insert to authenticated
    with check (platform.is_platform_admin());



create policy energy_profiles_select on public.energy_profiles
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy energy_profiles_update on public.energy_profiles
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());



create policy insight_events_select on public.insight_events
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy optimization_recommendations_delete on public.optimization_recommendations
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy optimization_recommendations_select on public.optimization_recommendations
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



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



create policy optimization_rules_delete on public.optimization_rules
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy optimization_rules_insert on public.optimization_rules
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy optimization_rules_select on public.optimization_rules
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



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



create trigger trg_optimization_recommendations_property_tenant
before insert or update on public.optimization_recommendations
for each row execute function public.enforce_property_tenant_consistency();



create trigger trg_energy_profiles_property_tenant
before insert or update on public.energy_profiles
for each row execute function public.enforce_property_tenant_consistency();


-- =====================================================
-- END 012 OPTIMIZATION ENGINE (CLEAN INTELLIGENCE ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('012_optimization_engine', 'REV22.OPTIMIZATION', false)
on conflict (version) do nothing;

