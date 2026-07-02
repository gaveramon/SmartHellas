

-- =====================================================

-- 007 PRECONFIG ENGINE (REV19)

-- PHYSICAL DEPLOYMENT / HARDWARE / INSTALLATION LAYER

-- GLOBAL BLUEPRINTS ONLY — NO TENANT DATA / NO RUNTIME STATE

-- =====================================================



-- =====================================================

-- 1. DEVICE BUNDLES (VERSIONED HARDWARE BOM CATALOG)

-- =====================================================



create table if not exists device_bundles (



    id uuid primary key default gen_random_uuid(),



    code text not null,



    version int not null default 1,



    name text not null,



    description text,



    property_type property_type,



    is_active boolean not null default true,



    is_system boolean not null default false,



    created_at timestamptz not null default now(),



    updated_at timestamptz not null default now(),



    constraint uq_device_bundles_code_version

        unique (code, version)

);



create index if not exists idx_device_bundles_code

    on device_bundles (code);



create index if not exists idx_device_bundles_active

    on device_bundles (is_active);



create trigger trg_device_bundles_updated_at

before update on device_bundles

for each row execute function platform.set_updated_at();



-- =====================================================

-- 2. BUNDLE DEVICES (HARDWARE COMPONENT LIST)

-- =====================================================



create table if not exists bundle_devices (



    id uuid primary key default gen_random_uuid(),



    bundle_id uuid not null references device_bundles(id) on delete cascade,



    category_code text not null references public.device_categories(code),



    quantity int not null default 1,



    is_required boolean not null default true,



    config_hint jsonb not null default '{}'::jsonb,



    created_at timestamptz not null default now(),



    constraint uq_bundle_device unique (bundle_id, category_code),



    constraint chk_bundle_device_qty check (quantity > 0)

);



create index if not exists idx_bundle_devices_bundle

    on bundle_devices (bundle_id);



-- =====================================================

-- 3. ONBOARDING BLUEPRINTS (INSTALLATION FLOW SPEC)

-- =====================================================



create table if not exists onboarding_blueprints (



    id uuid primary key default gen_random_uuid(),



    code text not null unique,



    name text not null,



    description text,



    property_type property_type,



    is_system boolean not null default false,



    is_active boolean not null default true,



    created_at timestamptz not null default now(),



    updated_at timestamptz not null default now()

);



-- =====================================================

-- 4. ONBOARDING STEPS (ORDERED SPECIFICATION)

-- =====================================================



create table if not exists onboarding_blueprint_steps (



    id uuid primary key default gen_random_uuid(),



    blueprint_id uuid not null references onboarding_blueprints(id) on delete cascade,



    step_order int not null,



    step_type onboarding_step_type not null,



    config jsonb not null default '{}'::jsonb,



    created_at timestamptz not null default now(),



    unique (blueprint_id, step_order),



    constraint chk_step_order check (step_order > 0)

);



create index if not exists idx_onboarding_steps_blueprint

    on onboarding_blueprint_steps (blueprint_id);



-- =====================================================

-- 5. PRECONFIG TEMPLATES (GLOBAL INSTALL BLUEPRINT)

-- Tenant template selection lives in 011 onboarding_sessions.

-- =====================================================



create table if not exists preconfig_templates (



    id uuid primary key default gen_random_uuid(),



    device_bundle_id uuid not null references device_bundles(id) on delete restrict,



    onboarding_blueprint_id uuid references onboarding_blueprints(id) on delete set null,



    name text not null,



    description text,



    property_type property_type,



    is_active boolean not null default true,



    version int not null default 1,



    created_at timestamptz not null default now(),



    updated_at timestamptz not null default now()

);



create index if not exists idx_preconfig_templates_bundle

    on preconfig_templates (device_bundle_id);



create trigger trg_preconfig_templates_updated_at

before update on preconfig_templates

for each row execute function platform.set_updated_at();



comment on table public.preconfig_templates is

    'Global install blueprint catalog. Tenants select via onboarding_sessions.preconfig_template_id (011).';



-- =====================================================

-- 6. DEVICE → ROOM INSTALLATION MAP

-- =====================================================



create table if not exists preconfig_device_map (



    id uuid primary key default gen_random_uuid(),



    template_id uuid not null references preconfig_templates(id) on delete cascade,



    category_code text not null references public.device_categories(code),



    room_type room_type not null,



    recommended_protocol device_protocol,



    default_config jsonb not null default '{}'::jsonb,



    created_at timestamptz not null default now(),



    unique (template_id, category_code, room_type)

);



create index if not exists idx_preconfig_device_map_template

    on preconfig_device_map (template_id);



-- =====================================================

-- 7. RLS (GLOBAL CATALOG — READ ALL, ADMIN WRITE)

-- =====================================================



alter table device_bundles enable row level security;

alter table bundle_devices enable row level security;

alter table onboarding_blueprints enable row level security;

alter table onboarding_blueprint_steps enable row level security;

alter table preconfig_templates enable row level security;

alter table preconfig_device_map enable row level security;



create policy device_bundles_select

on device_bundles for select to authenticated

using (true);



create policy bundle_devices_select

on bundle_devices for select to authenticated

using (true);



create policy bundle_devices_write

on bundle_devices for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



create policy onboarding_blueprints_select

on onboarding_blueprints for select to authenticated

using (true);



create policy onboarding_blueprint_steps_select

on onboarding_blueprint_steps for select to authenticated

using (true);



create policy preconfig_templates_select

on preconfig_templates for select to authenticated

using (true);



create policy preconfig_device_map_select

on preconfig_device_map for select to authenticated

using (true);



create policy device_bundles_write

on device_bundles for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



create policy onboarding_blueprints_write

on onboarding_blueprints for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



create policy onboarding_blueprint_steps_write

on onboarding_blueprint_steps for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



create policy preconfig_templates_write

on preconfig_templates for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



create policy preconfig_device_map_write

on preconfig_device_map for all to authenticated

using (platform.is_platform_admin())

with check (platform.is_platform_admin());



-- =====================================================

-- END 007 PRECONFIG ENGINE (REV19)

-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('007_preconfig_engine_rev19', 'REV19.PRECONFIG', false)
on conflict (version) do nothing;

