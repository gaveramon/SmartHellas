-- =====================================================
-- 009 COMMERCE ENGINE (CLEAN COMMERCIAL DOMAIN LAYER)
-- NO PAYMENT EXECUTION / NO WEBHOOKS / NO TRANSACTIONS
-- =====================================================

-- =====================================================
-- 1. PRODUCT PLANS (COMMERCIAL OFFERING MODEL)
-- Platform catalog — tier SSOT lives on plan; subscriptions sync via trigger.
-- =====================================================

create table if not exists product_plans (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    tier subscription_tier not null,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create trigger trg_product_plans_updated_at
before update on product_plans
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. PLAN PRICING (STATIC PRICING MODEL)
-- =====================================================

create table if not exists plan_pricing (
    id uuid primary key default gen_random_uuid(),

    plan_id uuid not null references product_plans(id) on delete cascade,

    currency text not null default 'EUR',

    monthly_price numeric(10,2),

    yearly_price numeric(10,2),

    effective_from timestamptz not null default now(),

    created_at timestamptz default now(),

    constraint chk_plan_pricing_currency_iso
        check (char_length(currency) = 3),

    constraint chk_plan_pricing_has_amount
        check (monthly_price is not null or yearly_price is not null),

    unique (plan_id, currency)
);

create index if not exists idx_plan_pricing_plan
on plan_pricing (plan_id);

-- =====================================================
-- 3. SUBSCRIPTION ↔ PLAN BINDING (002 subscriptions SSOT)
-- plan_id FK added here after product_plans exists
-- =====================================================

alter table public.subscriptions
    add column if not exists plan_id uuid references product_plans(id);

create index if not exists idx_subscriptions_plan
on public.subscriptions (plan_id);

create index if not exists idx_subscriptions_tenant_created
on public.subscriptions (tenant_id, created_at desc);

drop index if exists public.uq_subscriptions_active_tenant;

create unique index uq_subscriptions_active_tenant
on public.subscriptions (tenant_id)
where status in ('trial', 'pending', 'active', 'past_due');

create or replace function public.sync_subscription_tier_from_plan()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.plan_id is not null then
        select pp.tier
        into new.tier
        from public.product_plans pp
        where pp.id = new.plan_id;

        if not found then
            raise exception 'plan_id % not found in product_plans', new.plan_id;
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_subscriptions_sync_tier_from_plan on public.subscriptions;

create trigger trg_subscriptions_sync_tier_from_plan
before insert or update of plan_id on public.subscriptions
for each row execute function public.sync_subscription_tier_from_plan();

comment on column public.subscriptions.tier is
    'Denormalized from product_plans.tier when plan_id is set. Do not edit independently.';

-- =====================================================
-- 4. FEATURE ENTITLEMENTS (WHAT CUSTOMER CAN USE)
-- =====================================================

create table if not exists feature_entitlements (
    id uuid primary key default gen_random_uuid(),

    plan_id uuid not null references product_plans(id) on delete cascade,

    feature_key text not null,
    -- e.g. auto_door_code, energy_reports, guest_messaging

    enabled boolean default true,

    unique (plan_id, feature_key)
);

create index if not exists idx_feature_entitlements_plan
on feature_entitlements (plan_id);

-- =====================================================
-- 5. UPSELL RULES (DEFINITION ONLY, NO EXECUTION)
-- Subscription/plan upgrades only — package upsells live in 013.upsell_campaigns.
-- =====================================================

create table if not exists upsell_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid references tenants(id) on delete cascade,

    trigger_event upsell_trigger,

    recommended_plan_id uuid references product_plans(id),

    rule_config jsonb,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_upsell_rules_tenant
on upsell_rules (tenant_id);

create index if not exists idx_upsell_rules_trigger_active
on upsell_rules (trigger_event)
where is_active;

-- =====================================================
-- 6. PLATFORM CATALOG RLS (READ-ALL, WRITE ADMIN)
-- =====================================================

alter table public.product_plans enable row level security;

drop policy if exists product_plans_select on public.product_plans;
drop policy if exists product_plans_insert on public.product_plans;
drop policy if exists product_plans_update on public.product_plans;
drop policy if exists product_plans_delete on public.product_plans;

create policy product_plans_select on public.product_plans
    for select to authenticated
    using (true);

create policy product_plans_insert on public.product_plans
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy product_plans_update on public.product_plans
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy product_plans_delete on public.product_plans
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.plan_pricing enable row level security;

drop policy if exists plan_pricing_select on public.plan_pricing;
drop policy if exists plan_pricing_insert on public.plan_pricing;
drop policy if exists plan_pricing_update on public.plan_pricing;
drop policy if exists plan_pricing_delete on public.plan_pricing;

create policy plan_pricing_select on public.plan_pricing
    for select to authenticated
    using (true);

create policy plan_pricing_insert on public.plan_pricing
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy plan_pricing_update on public.plan_pricing
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy plan_pricing_delete on public.plan_pricing
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.feature_entitlements enable row level security;

drop policy if exists feature_entitlements_select on public.feature_entitlements;
drop policy if exists feature_entitlements_insert on public.feature_entitlements;
drop policy if exists feature_entitlements_update on public.feature_entitlements;
drop policy if exists feature_entitlements_delete on public.feature_entitlements;

create policy feature_entitlements_select on public.feature_entitlements
    for select to authenticated
    using (true);

create policy feature_entitlements_insert on public.feature_entitlements
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy feature_entitlements_update on public.feature_entitlements
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy feature_entitlements_delete on public.feature_entitlements
    for delete to authenticated
    using (platform.is_platform_admin());

-- nullable tenant_id (platform-wide plan upsell blueprints)
alter table public.upsell_rules enable row level security;

drop policy if exists upsell_rules_select on public.upsell_rules;
drop policy if exists upsell_rules_insert on public.upsell_rules;
drop policy if exists upsell_rules_update on public.upsell_rules;
drop policy if exists upsell_rules_delete on public.upsell_rules;

create policy upsell_rules_select on public.upsell_rules
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy upsell_rules_insert on public.upsell_rules
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy upsell_rules_update on public.upsell_rules
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy upsell_rules_delete on public.upsell_rules
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

-- =====================================================
-- 7. ALIGN 000 PAYMENT SKELETON WITH 001 ENUMS
-- =====================================================

do $$
begin
    alter table platform.payment_intents
        alter column provider drop default;

    alter table platform.payment_intents
        alter column provider type integration_provider using provider::integration_provider;

    alter table platform.payment_intents
        alter column status drop default;

    alter table platform.payment_intents
        alter column status type payment_status using status::payment_status;

    alter table platform.payment_intents
        alter column status set default 'pending'::payment_status;

    alter table platform.payment_events
        alter column old_status type payment_status using old_status::payment_status;

    alter table platform.payment_events
        alter column new_status type payment_status using new_status::payment_status;

    alter table platform.payment_provider_refs
        alter column provider type integration_provider using provider::integration_provider;
exception
    when undefined_table then null;
    when undefined_object then null;
end $$;

-- =====================================================
-- END 009 COMMERCE ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
