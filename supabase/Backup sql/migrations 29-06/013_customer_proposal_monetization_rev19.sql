-- =====================================================
-- 013 CUSTOMER PROPOSAL & MONETIZATION ENGINE
-- CLEAN COMMERCIAL + CONVERSION LOGIC LAYER
-- NO EXECUTION / NO PAYMENT / NO COMMUNICATION SIDE EFFECTS
-- Campaign SSOT: upsell_campaigns (in-product package upsells) only.
-- Plan upsells → 009.upsell_rules. Marketing → 015.crm_campaigns.
-- =====================================================

-- =====================================================
-- 1. CUSTOMER PROPOSALS (DATA MODEL ONLY)
-- =====================================================

create table if not exists customer_proposals (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete set null,

    status proposal_status not null default 'draft',

    total_estimated_value numeric,

    presented_at timestamptz,

    accepted_at timestamptz,

    expires_at timestamptz,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create index if not exists idx_customer_proposals_tenant_created
on customer_proposals (tenant_id, created_at desc);

create index if not exists idx_customer_proposals_tenant_status
on customer_proposals (tenant_id, status);

create trigger trg_customer_proposals_updated_at
before update on customer_proposals
for each row execute function platform.set_updated_at();

comment on table public.customer_proposals is
    'Commercial proposal intent. Payment checkout uses platform.payment_intents (target_type=proposal, target_id=id).';

comment on column public.customer_proposals.accepted_at is
    'Set when status becomes accepted. Worker in 000 may create payment_intent / fulfilment intent.';

-- =====================================================
-- 2. MONETIZATION PACKAGES (COMMERCIAL WRAPPER OVER 007 BOM)
-- Hardware BOM SSOT: device_bundles (007). Subscription tiers: product_plans (009).
-- =====================================================

create table if not exists monetization_packages (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    package_type package_type not null,

    device_bundle_id uuid references device_bundles(id) on delete restrict,

    base_price numeric,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint chk_monetization_package_hardware_bundle check (
        package_type = 'service' or device_bundle_id is not null
    )
);

create index if not exists idx_monetization_packages_bundle
on monetization_packages (device_bundle_id)
where device_bundle_id is not null;

create trigger trg_monetization_packages_updated_at
before update on monetization_packages
for each row execute function platform.set_updated_at();

comment on table public.monetization_packages is
    'Commercial packaging layer for proposals. Hardware contents SSOT: 007 device_bundles via device_bundle_id.';

alter table public.monetization_packages enable row level security;

drop policy if exists monetization_packages_select on public.monetization_packages;
drop policy if exists monetization_packages_insert on public.monetization_packages;
drop policy if exists monetization_packages_update on public.monetization_packages;
drop policy if exists monetization_packages_delete on public.monetization_packages;

create policy monetization_packages_select on public.monetization_packages
    for select to authenticated
    using (true);

create policy monetization_packages_insert on public.monetization_packages
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy monetization_packages_update on public.monetization_packages
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy monetization_packages_delete on public.monetization_packages
    for delete to authenticated
    using (platform.is_platform_admin());

-- =====================================================
-- 3. PROPOSAL ITEMS (WHAT IS OFFERED)
-- =====================================================

create table if not exists proposal_items (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    proposal_id uuid not null references customer_proposals(id) on delete cascade,

    item_type proposal_item_type not null,

    plan_id uuid references product_plans(id) on delete restrict,

    monetization_package_id uuid references monetization_packages(id) on delete restrict,

    reference_id uuid,

    quantity int not null default 1,

    price_estimate numeric,

    created_at timestamptz not null default now(),

    constraint chk_proposal_items_quantity check (quantity > 0),

    constraint chk_proposal_items_subscription check (
        item_type <> 'subscription' or plan_id is not null
    ),

    constraint chk_proposal_items_device_package check (
        item_type <> 'device_package' or monetization_package_id is not null
    ),

    constraint chk_proposal_items_service check (
        item_type <> 'service' or reference_id is not null
    )
);

create index if not exists idx_proposal_items_proposal
on proposal_items (proposal_id);

create index if not exists idx_proposal_items_tenant_created
on proposal_items (tenant_id, created_at desc);

create or replace function public.enforce_proposal_items_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_proposal_tenant uuid;
begin
    select cp.tenant_id
    into v_proposal_tenant
    from public.customer_proposals cp
    where cp.id = new.proposal_id;

    if not found then
        raise exception 'customer proposal not found';
    end if;

    if new.tenant_id <> v_proposal_tenant then
        raise exception 'proposal_items tenant_id must match customer_proposals tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_proposal_items_tenant_consistency
before insert or update on public.proposal_items
for each row execute function public.enforce_proposal_items_tenant_consistency();

comment on column public.proposal_items.plan_id is
    'Required when item_type=subscription. References 009 product_plans.';

comment on column public.proposal_items.monetization_package_id is
    'Required when item_type=device_package. References 013 monetization_packages (linked to 007 device_bundles).';

comment on column public.proposal_items.reference_id is
    'Required when item_type=service. Polymorphic service entity id only.';

-- =====================================================
-- 4. UPSELL CAMPAIGNS (CONVERSION LOGIC ONLY)
-- Subscription/plan upgrades live in 009 upsell_rules.
-- =====================================================

create table if not exists upsell_campaigns (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid references tenants(id) on delete cascade,

    trigger_event upsell_package_trigger,

    target_package_id uuid references monetization_packages(id),

    campaign_rules jsonb,

    is_active boolean not null default true,

    created_at timestamptz not null default now()
);

create index if not exists idx_upsell_campaigns_tenant_created
on upsell_campaigns (tenant_id, created_at desc);

alter table public.customer_proposals
    add column if not exists source_campaign_id uuid references upsell_campaigns(id) on delete set null;

create index if not exists idx_customer_proposals_source_campaign
on customer_proposals (source_campaign_id)
where source_campaign_id is not null;

-- =====================================================
-- 5. SERVICE ACTIVATION PROJECTION (WORKER-MAINTAINED CACHE)
-- SSOT: subscriptions (002) + feature_entitlements (009). Not app-writable truth.
-- =====================================================

create table if not exists service_activation_state (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete set null,

    service_type service_type not null,

    status service_activation_status not null default 'inactive',

    source_proposal_id uuid references customer_proposals(id) on delete set null,

    source_subscription_id uuid references subscriptions(id) on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint chk_service_activation_source check (
        source_proposal_id is not null or source_subscription_id is not null
    )
);

create unique index if not exists uq_service_activation_state_property
on service_activation_state (tenant_id, property_id, service_type)
where property_id is not null;

create unique index if not exists uq_service_activation_state_tenant
on service_activation_state (tenant_id, service_type)
where property_id is null;

create index if not exists idx_service_activation_state_tenant_created
on service_activation_state (tenant_id, created_at desc);

create index if not exists idx_service_activation_state_source_subscription
on service_activation_state (source_subscription_id)
where source_subscription_id is not null;

create trigger trg_service_activation_state_updated_at
before update on service_activation_state
for each row execute function platform.set_updated_at();

-- =====================================================
-- 6. CONVERSION EVENTS (FUNNEL DATA ONLY)
-- =====================================================

create table if not exists conversion_events (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete set null,

    proposal_id uuid references customer_proposals(id) on delete set null,

    event_type conversion_event_type not null,

    source text not null default 'portal',

    metadata jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now()
);

create index if not exists idx_conversion_events_tenant_created
on conversion_events (tenant_id, created_at desc);

create index if not exists idx_conversion_events_proposal
on conversion_events (proposal_id, created_at desc)
where proposal_id is not null;

create index if not exists idx_conversion_events_type
on conversion_events (tenant_id, event_type, created_at desc);

comment on table public.conversion_events is
    'Append-only commercial funnel events. Checkout/charge execution uses platform.payment_intents in 000.';

-- =====================================================
-- 7. CONVERSION SCORING (ANALYTICAL ONLY)
-- =====================================================

create table if not exists conversion_scores (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    property_id uuid references properties(id) on delete set null,

    score numeric(5,2),

    factors jsonb,

    calculated_at timestamptz not null default now()
);

create index if not exists idx_conversion_scores_tenant_created
on conversion_scores (tenant_id, calculated_at desc);

-- =====================================================
-- 8. UPSELL CAMPAIGNS RLS (nullable tenant_id — platform blueprints)
-- =====================================================

alter table public.upsell_campaigns enable row level security;

drop policy if exists upsell_campaigns_select on public.upsell_campaigns;
drop policy if exists upsell_campaigns_insert on public.upsell_campaigns;
drop policy if exists upsell_campaigns_update on public.upsell_campaigns;
drop policy if exists upsell_campaigns_delete on public.upsell_campaigns;

create policy upsell_campaigns_select on public.upsell_campaigns
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy upsell_campaigns_insert on public.upsell_campaigns
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy upsell_campaigns_update on public.upsell_campaigns
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy upsell_campaigns_delete on public.upsell_campaigns
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

comment on table public.service_activation_state is
    'Worker-maintained activation projection (read-only for tenants). SSOT: subscriptions (002) + feature_entitlements (009). Writes: platform.sync_service_activation_state() via service_role only.';

alter table public.fulfilment_orders
    add column if not exists customer_proposal_id uuid references public.customer_proposals(id) on delete set null;

create index if not exists idx_fulfilment_orders_proposal
on public.fulfilment_orders (customer_proposal_id)
where customer_proposal_id is not null;

alter table public.optimization_recommendations
    add column if not exists customer_proposal_id uuid references public.customer_proposals(id) on delete set null;

create index if not exists idx_optimization_recommendations_proposal
on public.optimization_recommendations (customer_proposal_id)
where customer_proposal_id is not null;

create trigger trg_customer_proposals_property_tenant
before insert or update on public.customer_proposals
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_service_activation_state_property_tenant
before insert or update on public.service_activation_state
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_conversion_events_property_tenant
before insert or update on public.conversion_events
for each row execute function public.enforce_property_tenant_consistency();

-- =====================================================
-- 9. RLS (TENANT TABLES)
-- =====================================================

alter table public.customer_proposals enable row level security;

drop policy if exists customer_proposals_select on public.customer_proposals;
drop policy if exists customer_proposals_insert on public.customer_proposals;
drop policy if exists customer_proposals_update on public.customer_proposals;
drop policy if exists customer_proposals_delete on public.customer_proposals;

create policy customer_proposals_select on public.customer_proposals
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy customer_proposals_insert on public.customer_proposals
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy customer_proposals_update on public.customer_proposals
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

create policy customer_proposals_delete on public.customer_proposals
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.proposal_items enable row level security;

drop policy if exists proposal_items_select on public.proposal_items;
drop policy if exists proposal_items_insert on public.proposal_items;
drop policy if exists proposal_items_update on public.proposal_items;
drop policy if exists proposal_items_delete on public.proposal_items;

create policy proposal_items_select on public.proposal_items
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy proposal_items_insert on public.proposal_items
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy proposal_items_update on public.proposal_items
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

create policy proposal_items_delete on public.proposal_items
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.service_activation_state enable row level security;

drop policy if exists service_activation_state_select on public.service_activation_state;
drop policy if exists service_activation_state_insert on public.service_activation_state;
drop policy if exists service_activation_state_update on public.service_activation_state;
drop policy if exists service_activation_state_delete on public.service_activation_state;

create policy service_activation_state_select on public.service_activation_state
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy service_activation_state_insert on public.service_activation_state
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy service_activation_state_update on public.service_activation_state
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy service_activation_state_delete on public.service_activation_state
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.conversion_events enable row level security;

drop policy if exists conversion_events_select on public.conversion_events;
drop policy if exists conversion_events_insert on public.conversion_events;
drop policy if exists conversion_events_update on public.conversion_events;
drop policy if exists conversion_events_delete on public.conversion_events;

create policy conversion_events_select on public.conversion_events
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy conversion_events_insert on public.conversion_events
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy conversion_events_update on public.conversion_events
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy conversion_events_delete on public.conversion_events
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.conversion_scores enable row level security;

drop policy if exists conversion_scores_select on public.conversion_scores;
drop policy if exists conversion_scores_insert on public.conversion_scores;
drop policy if exists conversion_scores_update on public.conversion_scores;
drop policy if exists conversion_scores_delete on public.conversion_scores;

create policy conversion_scores_select on public.conversion_scores
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy conversion_scores_insert on public.conversion_scores
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy conversion_scores_update on public.conversion_scores
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy conversion_scores_delete on public.conversion_scores
    for delete to authenticated
    using (platform.is_platform_admin());

-- =====================================================
-- END 013 MONETIZATION ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('013_customer_proposal_monetization_rev19', 'REV19.MONETIZATION', false)
on conflict (version) do nothing;
