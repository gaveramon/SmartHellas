-- =====================================================
-- 008 LOGISTICS ENGINE (CLEAN FULFILMENT DEFINITION LAYER)
-- NO SHIPPING EXECUTION / NO TRACKING / NO EVENTS / NO LABEL GENERATION
-- =====================================================
--
-- SSOT HIERARCHY
-- device_bundles (007)     — hardware BOM (package contents live there)
-- logistics_templates      — delivery blueprint per tenant or platform
-- package_definitions      — shipment package = template + device_bundle
-- shipping_carriers        — carrier catalog
-- shipping_rules           — routing/pricing rules (definition only)
-- warehouses               — fulfilment origin locations (definition only)
-- shipping_label_templates — label format/service codes per carrier
-- fulfilment_orders        — shipment intent (business status only, no tracking)
--
-- EXECUTION (000): shipment_dispatch_queue, shipment_tracking_events, carrier API
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

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_logistics_templates_tenant
on logistics_templates (tenant_id);

create trigger trg_logistics_templates_updated_at
before update on logistics_templates
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. PACKAGE DEFINITIONS (LINK TO 007 device_bundles — NO DUPLICATE BOM)
-- =====================================================

create table if not exists package_definitions (
    id uuid primary key default gen_random_uuid(),

    template_id uuid not null references logistics_templates(id) on delete cascade,

    device_bundle_id uuid not null references device_bundles(id) on delete restrict,

    name text not null,

    description text,

    unique (template_id, device_bundle_id)
);

create index if not exists idx_package_definitions_template
on package_definitions (template_id);

create index if not exists idx_package_definitions_bundle
on package_definitions (device_bundle_id);

comment on table public.package_definitions is
    'Shipment package definition. BOM contents come from 007 device_bundles / bundle_devices.';

-- =====================================================
-- 3. SHIPPING CARRIERS (CATALOG — DEFINITION ONLY)
-- =====================================================

create table if not exists shipping_carriers (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    api_provider integration_provider,

    is_active boolean default true,

    created_at timestamptz default now(),

    unique (name)
);

comment on table public.shipping_carriers is
    'Carrier catalog. API dispatch and tracking ingest belong in platform layer (000).';

-- =====================================================
-- 3B. WAREHOUSES (FULFILMENT ORIGIN — DEFINITION ONLY)
-- =====================================================

create table if not exists warehouses (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    name text not null,

    address text,

    country_code text not null default 'GR',

    default_carrier_id uuid references shipping_carriers(id) on delete set null,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_warehouses_tenant
on warehouses (tenant_id);

comment on table public.warehouses is
    'Fulfilment origin locations. Stock movements and inventory execution belong in 000.';

create trigger trg_warehouses_updated_at
before update on warehouses
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3C. SHIPPING LABEL TEMPLATES (FORMAT DEFINITION ONLY)
-- =====================================================

create table if not exists shipping_label_templates (
    id uuid primary key default gen_random_uuid(),

    carrier_id uuid not null references shipping_carriers(id) on delete cascade,

    name text not null,

    label_format text not null default 'pdf',

    service_code text,

    config jsonb not null default '{}'::jsonb,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (carrier_id, name),

    constraint chk_shipping_label_templates_format check (
        label_format in ('pdf', 'zpl', 'png')
    )
);

create index if not exists idx_shipping_label_templates_carrier
on shipping_label_templates (carrier_id);

comment on table public.shipping_label_templates is
    'Label format and carrier service codes. Generated artifacts stored via platform.shipment_dispatch_queue (000).';

comment on column public.shipping_label_templates.config is
    'Non-secret template options: { paper_size, orientation, margin_mm }.';

create trigger trg_shipping_label_templates_updated_at
before update on shipping_label_templates
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. SHIPPING RULES (LOGIC ONLY, NO EXECUTION)
-- =====================================================

create table if not exists shipping_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    carrier_id uuid references shipping_carriers(id) on delete set null,

    rule_name text not null,

    rule_config jsonb not null default '{}'::jsonb,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_shipping_rules_tenant
on shipping_rules (tenant_id);

create index if not exists idx_shipping_rules_carrier
on shipping_rules (carrier_id)
where carrier_id is not null;

comment on column public.shipping_rules.rule_config is
    'Non-secret routing rules: { country, min_weight, max_weight, service_level, priority }.';

create trigger trg_shipping_rules_updated_at
before update on shipping_rules
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5. FULFILMENT ORDERS (SHIPMENT INTENT — NO TRACKING)
-- Business lifecycle only. Carrier tracking and labels live in 000.
-- =====================================================

create table if not exists fulfilment_orders (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete restrict,

    package_definition_id uuid references package_definitions(id) on delete restrict,

    device_bundle_id uuid references device_bundles(id) on delete restrict,

    carrier_id uuid references shipping_carriers(id) on delete set null,

    warehouse_id uuid references warehouses(id) on delete set null,

    label_template_id uuid references shipping_label_templates(id) on delete set null,

    customer_proposal_id uuid,

    status fulfilment_status not null default 'draft',

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    constraint chk_fulfilment_orders_package check (
        package_definition_id is not null
        or device_bundle_id is not null
    )
);

create index if not exists idx_fulfilment_orders_tenant
on fulfilment_orders (tenant_id);

create index if not exists idx_fulfilment_orders_tenant_status
on fulfilment_orders (tenant_id, status);

create index if not exists idx_fulfilment_orders_property
on fulfilment_orders (property_id);

comment on table public.fulfilment_orders is
    'Domain shipment intent. No tracking numbers or label URLs — those belong in platform layer (000).';

comment on column public.fulfilment_orders.customer_proposal_id is
    'Optional link to 013 customer_proposals. FK added in 013 after proposals table exists.';

create trigger trg_fulfilment_orders_updated_at
before update on fulfilment_orders
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5B. FULFILMENT ORDER CONSISTENCY
-- =====================================================

create or replace function public.enforce_fulfilment_order_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_property_tenant uuid;
    v_package_bundle uuid;
begin
    select p.tenant_id
    into v_property_tenant
    from public.properties p
    where p.id = new.property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if new.tenant_id <> v_property_tenant then
        raise exception 'fulfilment order tenant_id must match property tenant_id';
    end if;

    if new.package_definition_id is not null then
        select pd.device_bundle_id
        into v_package_bundle
        from public.package_definitions pd
        where pd.id = new.package_definition_id;

        if not found then
            raise exception 'package definition not found';
        end if;

        if new.device_bundle_id is not null
           and new.device_bundle_id <> v_package_bundle then
            raise exception 'device_bundle_id must match package_definition device_bundle_id';
        end if;

        new.device_bundle_id := coalesce(new.device_bundle_id, v_package_bundle);
    end if;

    if new.label_template_id is not null and new.carrier_id is not null then
        if not exists (
            select 1
            from public.shipping_label_templates slt
            where slt.id = new.label_template_id
              and slt.carrier_id = new.carrier_id
        ) then
            raise exception 'label_template_id must belong to the selected carrier';
        end if;
    end if;

    if new.warehouse_id is not null then
        if exists (
            select 1
            from public.warehouses w
            where w.id = new.warehouse_id
              and w.tenant_id is not null
              and w.tenant_id <> new.tenant_id
        ) then
            raise exception 'warehouse must belong to the fulfilment order tenant';
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_fulfilment_orders_consistency
before insert or update on public.fulfilment_orders
for each row execute function public.enforce_fulfilment_order_consistency();

-- =====================================================
-- 6. TENANT FKs (DEFERRED — TENANTS EXIST FROM 002)
-- =====================================================

do $$
begin
    alter table public.logistics_templates
        add constraint fk_logistics_templates_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.shipping_rules
        add constraint fk_shipping_rules_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.fulfilment_orders
        add constraint fk_fulfilment_orders_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.warehouses
        add constraint fk_warehouses_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 6B. PLATFORM EXECUTION BINDING (000 SHIPMENT QUEUES)
-- =====================================================

do $$
begin
    alter table platform.shipment_dispatch_queue
        add constraint fk_shipment_dispatch_fulfilment_order
        foreign key (fulfilment_order_id) references public.fulfilment_orders(id) on delete restrict;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table platform.shipment_tracking_events
        add constraint fk_shipment_tracking_fulfilment_order
        foreign key (fulfilment_order_id) references public.fulfilment_orders(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

comment on constraint fk_shipment_dispatch_fulfilment_order on platform.shipment_dispatch_queue is
    'Domain fulfilment intent (008) is SSOT; restrict delete while dispatch may exist.';

-- =====================================================
-- 7. RLS — GLOBAL CATALOG (shipping_carriers, label templates)
-- =====================================================

alter table public.shipping_carriers enable row level security;

drop policy if exists shipping_carriers_select on public.shipping_carriers;
drop policy if exists shipping_carriers_insert on public.shipping_carriers;
drop policy if exists shipping_carriers_update on public.shipping_carriers;
drop policy if exists shipping_carriers_delete on public.shipping_carriers;

create policy shipping_carriers_select on public.shipping_carriers
    for select to authenticated
    using (true);

create policy shipping_carriers_insert on public.shipping_carriers
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy shipping_carriers_update on public.shipping_carriers
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy shipping_carriers_delete on public.shipping_carriers
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.shipping_label_templates enable row level security;

drop policy if exists shipping_label_templates_select on public.shipping_label_templates;
drop policy if exists shipping_label_templates_insert on public.shipping_label_templates;
drop policy if exists shipping_label_templates_update on public.shipping_label_templates;
drop policy if exists shipping_label_templates_delete on public.shipping_label_templates;

create policy shipping_label_templates_select on public.shipping_label_templates
    for select to authenticated
    using (true);

create policy shipping_label_templates_insert on public.shipping_label_templates
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy shipping_label_templates_update on public.shipping_label_templates
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy shipping_label_templates_delete on public.shipping_label_templates
    for delete to authenticated
    using (platform.is_platform_admin());

-- =====================================================
-- 8. RLS — TENANT WAREHOUSES + TEMPLATES + RULES
-- warehouses / logistics_templates / shipping_rules: nullable tenant_id (explicit policies above)
-- fulfilment_orders → generic tenant RLS via 014 bootstrap
-- =====================================================

alter table public.warehouses enable row level security;

drop policy if exists warehouses_select on public.warehouses;
drop policy if exists warehouses_insert on public.warehouses;
drop policy if exists warehouses_update on public.warehouses;
drop policy if exists warehouses_delete on public.warehouses;

create policy warehouses_select on public.warehouses
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy warehouses_insert on public.warehouses
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy warehouses_update on public.warehouses
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy warehouses_delete on public.warehouses
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

-- =====================================================
-- 9. RLS — LOGISTICS TEMPLATES + PACKAGES + RULES
-- =====================================================

alter table public.logistics_templates enable row level security;

drop policy if exists logistics_templates_select on public.logistics_templates;
drop policy if exists logistics_templates_insert on public.logistics_templates;
drop policy if exists logistics_templates_update on public.logistics_templates;
drop policy if exists logistics_templates_delete on public.logistics_templates;

create policy logistics_templates_select on public.logistics_templates
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy logistics_templates_insert on public.logistics_templates
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy logistics_templates_update on public.logistics_templates
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy logistics_templates_delete on public.logistics_templates
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

alter table public.package_definitions enable row level security;

drop policy if exists package_definitions_select on public.package_definitions;
drop policy if exists package_definitions_insert on public.package_definitions;
drop policy if exists package_definitions_update on public.package_definitions;
drop policy if exists package_definitions_delete on public.package_definitions;

create policy package_definitions_select on public.package_definitions
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.logistics_templates lt
            where lt.id = package_definitions.template_id
              and (lt.tenant_id is null or public.has_tenant_access(lt.tenant_id))
        )
    );

create policy package_definitions_insert on public.package_definitions
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.logistics_templates lt
            where lt.id = package_definitions.template_id
              and lt.tenant_id is not null
              and public.has_tenant_access(lt.tenant_id)
        )
    );

create policy package_definitions_update on public.package_definitions
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.logistics_templates lt
            where lt.id = package_definitions.template_id
              and lt.tenant_id is not null
              and public.has_tenant_access(lt.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.logistics_templates lt
            where lt.id = package_definitions.template_id
              and lt.tenant_id is not null
              and public.has_tenant_access(lt.tenant_id)
        )
    );

create policy package_definitions_delete on public.package_definitions
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.logistics_templates lt
            where lt.id = package_definitions.template_id
              and lt.tenant_id is not null
              and public.has_tenant_access(lt.tenant_id)
        )
    );

alter table public.shipping_rules enable row level security;

drop policy if exists shipping_rules_select on public.shipping_rules;
drop policy if exists shipping_rules_insert on public.shipping_rules;
drop policy if exists shipping_rules_update on public.shipping_rules;
drop policy if exists shipping_rules_delete on public.shipping_rules;

create policy shipping_rules_select on public.shipping_rules
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy shipping_rules_insert on public.shipping_rules
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy shipping_rules_update on public.shipping_rules
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy shipping_rules_delete on public.shipping_rules
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

-- =====================================================
-- END 008 LOGISTICS ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
