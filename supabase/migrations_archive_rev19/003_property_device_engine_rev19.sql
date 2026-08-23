
-- =====================================================
-- 003 PROPERTY & DEVICE ENGINE (CLEAN DOMAIN MODEL)
-- NO RUNTIME / NO LOGGING / NO EXECUTION STATE
-- =====================================================

-- =====================================================
-- 1. PROPERTIES (AIRBNB UNITS)
-- =====================================================

create table if not exists properties (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    address text,

    property_type property_type not null,

    timezone text default 'UTC',

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_properties_tenant
on properties (tenant_id);

create index if not exists idx_properties_tenant_created
on properties (tenant_id, created_at desc);

create trigger trg_properties_updated_at
before update on properties
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. ROOMS (LOGICAL STRUCTURE INSIDE PROPERTY)
-- =====================================================

create table if not exists rooms (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,

    name text not null,

    room_type room_type not null,

    floor int,

    created_at timestamptz default now()
);

create index if not exists idx_rooms_property
on rooms (property_id);

-- =====================================================
-- 3. DEVICE CATEGORIES (HARDWARE TAXONOMY / SSOT)
-- =====================================================

create table if not exists public.device_categories (
    code text primary key,
    name text not null,
    description text,
    is_gateway boolean not null default false,
    is_lock boolean not null default false,
    is_active boolean not null default true,
    sort_order int not null default 0,
    created_at timestamptz not null default now()
);

comment on table public.device_categories is
    'Hardware device taxonomy. code is the stable FK target for category_code columns. Seed: 003 (015 re-upserts).';

insert into public.device_categories (code, name, is_gateway, is_lock, sort_order)
values
    ('sensor', 'Sensor', false, false, 10),
    ('switch', 'Switch', false, false, 20),
    ('lock', 'Lock', false, true, 30),
    ('thermostat', 'Thermostat', false, false, 40),
    ('ir_controller', 'IR Controller', false, false, 50),
    ('gateway', 'Gateway', true, false, 60),
    ('other', 'Other', false, false, 99)
on conflict (code) do update set
    name = excluded.name,
    is_gateway = excluded.is_gateway,
    is_lock = excluded.is_lock,
    sort_order = excluded.sort_order;

-- =====================================================
-- 4. DEVICES (MASTER DEVICE REGISTRY)
-- parent_device_id → gateway hub (Aqara, Matter bridge, etc.)
-- =====================================================

create table if not exists devices (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    parent_device_id uuid references devices(id) on delete set null,

    device_name text not null,

    category_code text not null references public.device_categories(code),

    protocol device_protocol not null,

    model text,

    manufacturer text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_devices_tenant
on devices (tenant_id);

create index if not exists idx_devices_tenant_created
on devices (tenant_id, created_at desc);

create index if not exists idx_devices_category
on devices (category_code);

create index if not exists idx_devices_parent
on devices (parent_device_id)
where parent_device_id is not null;

-- =====================================================
-- 4B. DEVICE HIERARCHY INVARIANT (GATEWAY → CHILD)
-- =====================================================

create or replace function public.enforce_device_hierarchy()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_new_category record;
    v_parent record;
begin
    select dc.is_gateway
    into v_new_category
    from public.device_categories dc
    where dc.code = new.category_code;

    if not found then
        raise exception 'device category not found';
    end if;

    if v_new_category.is_gateway and new.parent_device_id is not null then
        raise exception 'gateway devices cannot have a parent device';
    end if;

    if new.parent_device_id is null then
        return new;
    end if;

    if tg_op = 'UPDATE' and new.parent_device_id = new.id then
        raise exception 'device cannot be its own parent';
    end if;

    select d.tenant_id, dc.is_gateway
    into v_parent
    from public.devices d
    join public.device_categories dc on dc.code = d.category_code
    where d.id = new.parent_device_id;

    if not found then
        raise exception 'parent device not found';
    end if;

    if not v_parent.is_gateway then
        raise exception 'parent device must be a gateway';
    end if;

    if v_parent.tenant_id <> new.tenant_id then
        raise exception 'parent device must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_devices_hierarchy
before insert or update on public.devices
for each row execute function public.enforce_device_hierarchy();

-- =====================================================
-- 4. DEVICE ASSIGNMENT (DEVICE ↔ ROOM LINK)
-- =====================================================

create table if not exists device_assignments (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    room_id uuid not null references rooms(id) on delete cascade,

    assigned_at timestamptz default now(),

    unique (device_id)
);

create index if not exists idx_device_assignments_room
on device_assignments (room_id);

create index if not exists idx_device_assignments_device_assigned
on device_assignments (device_id, assigned_at desc);

-- =====================================================
-- 4B. ASSIGNMENT TENANT CONSISTENCY (DEVICE ↔ ROOM)
-- =====================================================

create or replace function public.enforce_device_assignment_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_device_tenant uuid;
    v_room_tenant uuid;
begin
    select d.tenant_id
    into v_device_tenant
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    select p.tenant_id
    into v_room_tenant
    from public.rooms r
    join public.properties p on p.id = r.property_id
    where r.id = new.room_id;

    if not found then
        raise exception 'room not found';
    end if;

    if v_device_tenant <> v_room_tenant then
        raise exception 'device and room must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_device_assignment_tenant_consistency
before insert or update on public.device_assignments
for each row execute function public.enforce_device_assignment_tenant_consistency();

-- =====================================================
-- 5. DEVICE CONFIGURATION (STATIC SETUP ONLY)
-- =====================================================

create table if not exists device_configurations (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    config jsonb not null,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (device_id)
);

create index if not exists idx_device_configurations_device_created
on device_configurations (device_id, created_at desc);

create trigger trg_device_configurations_updated_at
before update on device_configurations
for each row execute function platform.set_updated_at();

comment on table public.device_configurations is
    'Static provisioning config only — do not store runtime telemetry or live state.';

-- =====================================================
-- 6. PLATFORM EXECUTION BINDING + TENANT FKs
-- Links domain registry to platform.device_commands (000)
-- =====================================================

do $$
begin
    alter table public.properties
        add constraint fk_properties_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.devices
        add constraint fk_devices_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table platform.device_commands
        add constraint fk_device_commands_device
        foreign key (device_id) references public.devices(id) on delete restrict;
exception
    when duplicate_object then null;
end $$;

comment on constraint fk_device_commands_device on platform.device_commands is
    'Domain device registry (003) is SSOT; restrict delete while commands may exist.';

-- =====================================================
-- 7. RLS
-- =====================================================

-- 7A. GLOBAL CATALOG (device_categories)
alter table public.device_categories enable row level security;

drop policy if exists device_categories_select on public.device_categories;
drop policy if exists device_categories_write on public.device_categories;

create policy device_categories_select on public.device_categories
    for select to authenticated
    using (true);

create policy device_categories_write on public.device_categories
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

-- 7B. TENANT-TABLE RLS (properties, devices)
alter table public.properties enable row level security;

drop policy if exists properties_select on public.properties;
drop policy if exists properties_insert on public.properties;
drop policy if exists properties_update on public.properties;
drop policy if exists properties_delete on public.properties;

create policy properties_select on public.properties
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy properties_insert on public.properties
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy properties_update on public.properties
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy properties_delete on public.properties
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

alter table public.devices enable row level security;

drop policy if exists devices_select on public.devices;
drop policy if exists devices_insert on public.devices;
drop policy if exists devices_update on public.devices;
drop policy if exists devices_delete on public.devices;

create policy devices_select on public.devices
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy devices_insert on public.devices
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy devices_update on public.devices
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy devices_delete on public.devices
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

-- 7C. CHILD-TABLE RLS (NO tenant_id COLUMN — EXPLICIT POLICIES)
-- =====================================================

alter table public.rooms enable row level security;

drop policy if exists rooms_select on public.rooms;
drop policy if exists rooms_insert on public.rooms;
drop policy if exists rooms_update on public.rooms;
drop policy if exists rooms_delete on public.rooms;

create policy rooms_select on public.rooms
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = rooms.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy rooms_insert on public.rooms
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = rooms.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy rooms_update on public.rooms
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = rooms.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = rooms.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy rooms_delete on public.rooms
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = rooms.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

alter table public.device_assignments enable row level security;

drop policy if exists device_assignments_select on public.device_assignments;
drop policy if exists device_assignments_insert on public.device_assignments;
drop policy if exists device_assignments_update on public.device_assignments;
drop policy if exists device_assignments_delete on public.device_assignments;

create policy device_assignments_select on public.device_assignments
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_assignments.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_assignments_insert on public.device_assignments
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_assignments.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_assignments_update on public.device_assignments
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_assignments.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_assignments.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_assignments_delete on public.device_assignments
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_assignments.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

alter table public.device_configurations enable row level security;

drop policy if exists device_configurations_select on public.device_configurations;
drop policy if exists device_configurations_insert on public.device_configurations;
drop policy if exists device_configurations_update on public.device_configurations;
drop policy if exists device_configurations_delete on public.device_configurations;

create policy device_configurations_select on public.device_configurations
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_configurations.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_configurations_insert on public.device_configurations
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_configurations.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_configurations_update on public.device_configurations
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_configurations.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_configurations.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_configurations_delete on public.device_configurations
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_configurations.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

-- =====================================================
-- END 003 PROPERTY & DEVICE ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('003_property_device_engine_rev19', 'REV19.PROPERTY.DEVICE', false)
on conflict (version) do nothing;
