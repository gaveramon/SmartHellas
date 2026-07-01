-- =====================================================
-- 007 PRECONFIG ENGINE (CLEAN PROVISIONING BLUEPRINT LAYER)
-- NO EXECUTION / NO LOGGING / NO RUNTIME STATE
-- =====================================================
--
-- SSOT HIERARCHY
-- device_bundles          — hardware package catalog (007 SSOT for install BOM)
-- onboarding_blueprints   — customer preparation flow definition
-- preconfig_templates     — master blueprint (links bundle + onboarding flow)
-- preconfig_device_map    — install map: device category → room type
--
-- LINKS (definitions only): 013 proposals → template; 011 sessions (future blueprint_id)
-- EXECUTION: device provisioning, QR generation, shipping → 000 / app layer
-- =====================================================

-- =====================================================
-- 1. DEVICE BUNDLES (HARDWARE PACKAGE CATALOG — SSOT)
-- =====================================================

create table if not exists device_bundles (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    description text,

    created_at timestamptz default now()
);

comment on table public.device_bundles is
    'Hardware BOM catalog. 008 logistics and 013 proposals should reference this SSOT.';

-- =====================================================
-- 2. BUNDLE DEVICES (DEVICES IN A PACKAGE)
-- =====================================================

create table if not exists bundle_devices (
    id uuid primary key default gen_random_uuid(),

    bundle_id uuid not null references device_bundles(id) on delete cascade,

    device_category device_category not null,

    quantity int not null default 1,

    unique (bundle_id, device_category),

    constraint chk_bundle_devices_quantity check (quantity > 0)
);

create index if not exists idx_bundle_devices_bundle
on bundle_devices (bundle_id);

-- =====================================================
-- 3. ONBOARDING BLUEPRINTS (CUSTOMER PREPARATION FLOW)
-- =====================================================

create table if not exists onboarding_blueprints (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    property_type property_type,

    steps jsonb not null default '[]'::jsonb,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

comment on table public.onboarding_blueprints is
    'High-level preparation flow. steps jsonb aligns with 001 onboarding_step_type values.';

comment on column public.onboarding_blueprints.steps is
    'Ordered step keys e.g. wifi_setup, device_assignment, room_mapping — definition only.';

create trigger trg_onboarding_blueprints_updated_at
before update on onboarding_blueprints
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. PRECONFIG TEMPLATES (MASTER BLUEPRINTS)
-- =====================================================

create table if not exists preconfig_templates (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    device_bundle_id uuid references device_bundles(id) on delete set null,

    onboarding_blueprint_id uuid references onboarding_blueprints(id) on delete set null,

    name text not null,

    description text,

    property_type property_type,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_preconfig_templates_tenant
on preconfig_templates (tenant_id);

create index if not exists idx_preconfig_templates_property_type
on preconfig_templates (property_type)
where is_active = true;

comment on table public.preconfig_templates is
    'Install blueprint: hardware bundle + onboarding flow + device/room map.';

create trigger trg_preconfig_templates_updated_at
before update on preconfig_templates
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5. PRECONFIG DEVICE MAP (DEFAULT ROOM ASSIGNMENTS)
-- =====================================================

create table if not exists preconfig_device_map (
    id uuid primary key default gen_random_uuid(),

    template_id uuid not null references preconfig_templates(id) on delete cascade,

    device_category device_category not null,

    room_type room_type not null,

    recommended_protocol device_protocol,

    default_config jsonb default '{}'::jsonb,

    unique (template_id, device_category, room_type)
);

create index if not exists idx_preconfig_device_map_template
on preconfig_device_map (template_id);

comment on column public.preconfig_device_map.default_config is
    'Static provisioning hints only — no runtime telemetry or live device state.';

-- =====================================================
-- 6. TENANT FK (DEFERRED — TENANTS EXIST FROM 002)
-- =====================================================

do $$
begin
    alter table public.preconfig_templates
        add constraint fk_preconfig_templates_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 7. RLS — GLOBAL CATALOG (device_bundles, bundle_devices, onboarding_blueprints)
-- =====================================================

alter table public.device_bundles enable row level security;

drop policy if exists device_bundles_select on public.device_bundles;
drop policy if exists device_bundles_insert on public.device_bundles;
drop policy if exists device_bundles_update on public.device_bundles;
drop policy if exists device_bundles_delete on public.device_bundles;

create policy device_bundles_select on public.device_bundles
    for select to authenticated
    using (true);

create policy device_bundles_insert on public.device_bundles
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy device_bundles_update on public.device_bundles
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy device_bundles_delete on public.device_bundles
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.bundle_devices enable row level security;

drop policy if exists bundle_devices_select on public.bundle_devices;
drop policy if exists bundle_devices_insert on public.bundle_devices;
drop policy if exists bundle_devices_update on public.bundle_devices;
drop policy if exists bundle_devices_delete on public.bundle_devices;

create policy bundle_devices_select on public.bundle_devices
    for select to authenticated
    using (true);

create policy bundle_devices_insert on public.bundle_devices
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy bundle_devices_update on public.bundle_devices
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy bundle_devices_delete on public.bundle_devices
    for delete to authenticated
    using (platform.is_platform_admin());

alter table public.onboarding_blueprints enable row level security;

drop policy if exists onboarding_blueprints_select on public.onboarding_blueprints;
drop policy if exists onboarding_blueprints_insert on public.onboarding_blueprints;
drop policy if exists onboarding_blueprints_update on public.onboarding_blueprints;
drop policy if exists onboarding_blueprints_delete on public.onboarding_blueprints;

create policy onboarding_blueprints_select on public.onboarding_blueprints
    for select to authenticated
    using (true);

create policy onboarding_blueprints_insert on public.onboarding_blueprints
    for insert to authenticated
    with check (platform.is_platform_admin());

create policy onboarding_blueprints_update on public.onboarding_blueprints
    for update to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

create policy onboarding_blueprints_delete on public.onboarding_blueprints
    for delete to authenticated
    using (platform.is_platform_admin());

-- =====================================================
-- 8. RLS — TENANT TEMPLATES + CHILD MAP
-- preconfig_templates: nullable tenant_id (explicit policies above)
-- =====================================================

alter table public.preconfig_templates enable row level security;

drop policy if exists preconfig_templates_select on public.preconfig_templates;
drop policy if exists preconfig_templates_insert on public.preconfig_templates;
drop policy if exists preconfig_templates_update on public.preconfig_templates;
drop policy if exists preconfig_templates_delete on public.preconfig_templates;

create policy preconfig_templates_select on public.preconfig_templates
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy preconfig_templates_insert on public.preconfig_templates
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy preconfig_templates_update on public.preconfig_templates
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy preconfig_templates_delete on public.preconfig_templates
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

alter table public.preconfig_device_map enable row level security;

drop policy if exists preconfig_device_map_select on public.preconfig_device_map;
drop policy if exists preconfig_device_map_insert on public.preconfig_device_map;
drop policy if exists preconfig_device_map_update on public.preconfig_device_map;
drop policy if exists preconfig_device_map_delete on public.preconfig_device_map;

create policy preconfig_device_map_select on public.preconfig_device_map
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.preconfig_templates pt
            where pt.id = preconfig_device_map.template_id
              and (pt.tenant_id is null or public.has_tenant_access(pt.tenant_id))
        )
    );

create policy preconfig_device_map_insert on public.preconfig_device_map
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.preconfig_templates pt
            where pt.id = preconfig_device_map.template_id
              and pt.tenant_id is not null
              and public.has_tenant_access(pt.tenant_id)
        )
    );

create policy preconfig_device_map_update on public.preconfig_device_map
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.preconfig_templates pt
            where pt.id = preconfig_device_map.template_id
              and pt.tenant_id is not null
              and public.has_tenant_access(pt.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.preconfig_templates pt
            where pt.id = preconfig_device_map.template_id
              and pt.tenant_id is not null
              and public.has_tenant_access(pt.tenant_id)
        )
    );

create policy preconfig_device_map_delete on public.preconfig_device_map
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.preconfig_templates pt
            where pt.id = preconfig_device_map.template_id
              and pt.tenant_id is not null
              and public.has_tenant_access(pt.tenant_id)
        )
    );

-- =====================================================
-- END 007 PRECONFIG ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
