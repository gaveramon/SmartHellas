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

-- Link 008 fulfilment_orders → proposals (008 runs before 013)
do $$
begin
    alter table public.fulfilment_orders
        add constraint fk_fulfilment_orders_proposal
        foreign key (customer_proposal_id) references public.customer_proposals(id) on delete set null;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 2. PROPOSAL ITEMS (WHAT IS OFFERED)
-- =====================================================

create table if not exists proposal_items (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    proposal_id uuid not null references customer_proposals(id) on delete cascade,

    item_type proposal_item_type not null,

    plan_id uuid references product_plans(id) on delete restrict,

    reference_id uuid,

    quantity int not null default 1,

    price_estimate numeric,

    created_at timestamptz not null default now(),

    constraint chk_proposal_items_quantity check (quantity > 0),

    constraint chk_proposal_items_subscription check (
        item_type <> 'subscription' or plan_id is not null
    ),

    constraint chk_proposal_items_device_package check (
        item_type <> 'device_package' or reference_id is not null
    ),

    constraint chk_proposal_items_service check (
        item_type <> 'service' or reference_id is not null
    )
);

create index if not exists idx_proposal_items_proposal
on proposal_items (proposal_id);

create index if not exists idx_proposal_items_tenant_created
on proposal_items (tenant_id, created_at desc);

comment on column public.proposal_items.plan_id is
    'Required when item_type=subscription. References 009 product_plans.';

comment on column public.proposal_items.reference_id is
    'Polymorphic ref: device_package → 003/008 bundle; service → domain entity id.';

-- =====================================================
-- 3. MONETIZATION PACKAGES (SERVICE + PRODUCT BUNDLES)
-- Platform catalog — recurring SaaS tiers live in 009 product_plans.
-- =====================================================

create table if not exists monetization_packages (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    package_type package_type not null,

    base_price numeric,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create trigger trg_monetization_packages_updated_at
before update on monetization_packages
for each row execute function platform.set_updated_at();

comment on table public.monetization_packages is
    'Hardware/service/hybrid bundles for proposals. Distinct from 009 product_plans (subscription tiers).';

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
-- 4. UPSELL CAMPAIGNS (CONVERSION LOGIC ONLY)
-- Subscription/plan upgrades live in 009 upsell_rules.
-- =====================================================

create table if not exists upsell_campaigns (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid references tenants(id) on delete cascade,

    trigger_event upsell_trigger,

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
-- 5. SERVICE ACTIVATION STATE (NOT EXECUTION)
-- Provisioning workers in 000 update this table; no triggers here.
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

    updated_at timestamptz not null default now()
);

create unique index if not exists uq_service_activation_state_property
on service_activation_state (tenant_id, property_id, service_type)
where property_id is not null;

create unique index if not exists uq_service_activation_state_tenant
on service_activation_state (tenant_id, service_type)
where property_id is null;

create index if not exists idx_service_activation_state_tenant_created
on service_activation_state (tenant_id, created_at desc);

create trigger trg_service_activation_state_updated_at
before update on service_activation_state
for each row execute function platform.set_updated_at();

comment on table public.service_activation_state is
    'Lifecycle state for managed_service and add-ons. Execution/provisioning stays in 000 workers.';

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
-- Remaining tenant_id tables → generic RLS via 014 bootstrap
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
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy upsell_campaigns_update on public.upsell_campaigns
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy upsell_campaigns_delete on public.upsell_campaigns
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

-- =====================================================
-- END 013 MONETIZATION ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
