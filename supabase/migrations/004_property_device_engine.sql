-- REV22 greenfield baseline: 004_property_device_engine.sql
-- Consolidated from migrations_archive_rev19 (000-053)


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



-- =====================================================
-- 5. DEVICE ASSIGNMENT (DEVICE ↔ ROOM LINK)
-- =====================================================

create table if not exists device_assignments (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    room_id uuid not null references rooms(id) on delete cascade,

    assigned_at timestamptz default now(),

    unique (device_id)
);



-- =====================================================
-- 6. DEVICE CONFIGURATION (STATIC SETUP ONLY)
-- =====================================================

create table if not exists device_configurations (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    config jsonb not null,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (device_id)
);



-- =====================================================
-- 7. INDEXES
-- =====================================================

create index if not exists idx_properties_tenant
on properties (tenant_id);



create index if not exists idx_properties_tenant_created
on properties (tenant_id, created_at desc);



create index if not exists idx_rooms_property
on rooms (property_id);



comment on table public.device_categories is
    'Hardware device taxonomy. code is the stable FK target for category_code columns. Seed: 004 (015 re-upserts).';



create index if not exists idx_devices_tenant
on devices (tenant_id);



create index if not exists idx_devices_tenant_created
on devices (tenant_id, created_at desc);



create index if not exists idx_devices_category
on devices (category_code);



create index if not exists idx_devices_parent
on devices (parent_device_id)
where parent_device_id is not null;



create index if not exists idx_device_assignments_room
on device_assignments (room_id);



create index if not exists idx_device_assignments_device_assigned
on device_assignments (device_id, assigned_at desc);



create index if not exists idx_device_configurations_device_created
on device_configurations (device_id, created_at desc);



comment on table public.device_configurations is
    'Static provisioning config only — do not store runtime telemetry or live state.';



-- =====================================================
-- 8. PLATFORM EXECUTION BINDING + TENANT FKs
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
    'Domain device registry (004) is SSOT; restrict delete while commands may exist.';



-- =====================================================
-- 9. RLS
-- =====================================================

-- 9A. GLOBAL CATALOG (device_categories)
alter table public.device_categories enable row level security;



drop policy if exists device_categories_select on public.device_categories;


drop policy if exists device_categories_write on public.device_categories;



-- 9B. TENANT-TABLE RLS (properties, devices)
alter table public.properties enable row level security;



drop policy if exists properties_select on public.properties;


drop policy if exists properties_insert on public.properties;


drop policy if exists properties_update on public.properties;


drop policy if exists properties_delete on public.properties;



alter table public.devices enable row level security;



drop policy if exists devices_select on public.devices;


drop policy if exists devices_insert on public.devices;


drop policy if exists devices_update on public.devices;


drop policy if exists devices_delete on public.devices;



-- 9C. CHILD-TABLE RLS (NO tenant_id COLUMN — EXPLICIT POLICIES)
-- =====================================================

alter table public.rooms enable row level security;



drop policy if exists rooms_select on public.rooms;


drop policy if exists rooms_insert on public.rooms;


drop policy if exists rooms_update on public.rooms;


drop policy if exists rooms_delete on public.rooms;



alter table public.device_assignments enable row level security;



drop policy if exists device_assignments_select on public.device_assignments;


drop policy if exists device_assignments_insert on public.device_assignments;


drop policy if exists device_assignments_update on public.device_assignments;


drop policy if exists device_assignments_delete on public.device_assignments;



alter table public.device_configurations enable row level security;



drop policy if exists device_configurations_select on public.device_configurations;


drop policy if exists device_configurations_insert on public.device_configurations;


drop policy if exists device_configurations_update on public.device_configurations;


drop policy if exists device_configurations_delete on public.device_configurations;



-- =====================================================
-- 10. DEVICE OVERVIEW
-- =====================================================

create or replace view public.v_devices_overview
with (security_invoker = true)
as
select
    d.id,
    d.tenant_id,
    d.device_name,
    d.category_code,
    dc.name as category_name,
    d.protocol,
    d.model,
    d.manufacturer,
    d.is_active,
    r.id as room_id,
    r.name as room_name,
    r.property_id,
    p.name as property_name,
    d.created_at
from public.devices d
left join public.device_categories dc on dc.code = d.category_code
left join public.device_assignments da on da.device_id = d.id
left join public.rooms r on r.id = da.room_id
left join public.properties p on p.id = r.property_id;



-- =====================================================
-- 11. DEVICE ASSIGNMENT WORKFLOW
-- =====================================================

-- -----------------------------------------------------
-- Standalone device workflow (004 SSOT)
-- -----------------------------------------------------

create or replace function public.devices_assign_device_to_room(
    p_device_id uuid,
    p_room_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_row record;
    v_existing uuid;
begin
    perform public.edge_require_manager();
    v_tid := platform.current_tenant_id();
    if v_tid is null then raise exception 'no active tenant'; end if;

    if not exists (
        select 1
        from public.devices d
        where d.id = p_device_id
          and d.tenant_id = v_tid
    ) then
        raise exception 'Device not found';
    end if;

    if not exists (
        select 1
        from public.rooms r
        join public.properties p on p.id = r.property_id
        where r.id = p_room_id
          and p.tenant_id = v_tid
    ) then
        raise exception 'Room not found';
    end if;

    select da.id into v_existing
    from public.device_assignments da
    where da.device_id = p_device_id;

    if found then
        update public.device_assignments
        set room_id = p_room_id
        where device_id = p_device_id
        returning device_id, room_id, assigned_at
        into v_row;
    else
        insert into public.device_assignments (device_id, room_id)
        values (p_device_id, p_room_id)
        returning device_id, room_id, assigned_at
        into v_row;
    end if;

    return jsonb_build_object(
        'device_id', v_row.device_id,
        'room_id', v_row.room_id,
        'assigned_at', v_row.assigned_at
    );
end;
$$;



-- =====================================================
-- 12. DEVICES DOMAIN API
-- =====================================================

create or replace function public.devices_domain(
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
    v_result jsonb;
    v_row record;
    v_device_id uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_properties' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
        into v_result
        from (
            select p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at
            from public.properties p
            where p.tenant_id = v_tid
        ) t;

    when 'get_property' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        select to_jsonb(t) into v_result
        from (
            select p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at
            from public.properties p
            where p.id = (p_payload->>'id')::uuid
              and p.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Property not found'; end if;

    when 'create_property' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        insert into public.properties (tenant_id, name, address, property_type, timezone)
        values (
            v_tid, p_payload->>'name', p_payload->>'address',
            (p_payload->>'property_type')::public.property_type,
            coalesce(p_payload->>'timezone', 'UTC')
        )
        returning id, tenant_id, name, address, property_type, timezone, created_at, updated_at into v_row;
        v_result := to_jsonb(v_row);

    when 'update_property' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        update public.properties p set
            name = case when p_payload ? 'name' then p_payload->>'name' else p.name end,
            address = case when p_payload ? 'address' then p_payload->>'address' else p.address end,
            property_type = case when p_payload ? 'property_type' then (p_payload->>'property_type')::public.property_type else p.property_type end,
            timezone = case when p_payload ? 'timezone' then p_payload->>'timezone' else p.timezone end
        where p.id = (p_payload->>'id')::uuid
          and p.tenant_id = v_tid
        returning p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at into v_row;
        if not found then raise exception 'Property not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_property' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        delete from public.properties p
        where p.id = (p_payload->>'id')::uuid
          and p.tenant_id = v_tid;
        if not found then raise exception 'Property not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_rooms' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if p_payload ? 'property_id' then
            if not exists (
                select 1
                from public.properties p
                where p.id = (p_payload->>'property_id')::uuid
                  and p.tenant_id = v_tid
            ) then
                raise exception 'Property not found';
            end if;
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at
                from public.rooms r
                join public.properties p on p.id = r.property_id
                where r.property_id = (p_payload->>'property_id')::uuid
                  and p.tenant_id = v_tid
            ) t;
        else
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at
                from public.rooms r
                join public.properties p on p.id = r.property_id
                where p.tenant_id = v_tid
            ) t;
        end if;

    when 'get_room' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        select to_jsonb(t) into v_result
        from (
            select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at
            from public.rooms r
            join public.properties p on p.id = r.property_id
            where r.id = (p_payload->>'id')::uuid
              and p.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Room not found'; end if;

    when 'create_room' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if not exists (
            select 1
            from public.properties p
            where p.id = (p_payload->>'property_id')::uuid
              and p.tenant_id = v_tid
        ) then
            raise exception 'Property not found';
        end if;
        insert into public.rooms (property_id, name, room_type, floor)
        values (
            (p_payload->>'property_id')::uuid, p_payload->>'name',
            (p_payload->>'room_type')::public.room_type,
            case when p_payload ? 'floor' and p_payload->>'floor' is not null then (p_payload->>'floor')::int else null end
        )
        returning id, property_id, name, room_type, floor, created_at into v_row;
        v_result := to_jsonb(v_row);

    when 'update_room' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        update public.rooms r set
            name = case when p_payload ? 'name' then p_payload->>'name' else r.name end,
            room_type = case when p_payload ? 'room_type' then (p_payload->>'room_type')::public.room_type else r.room_type end,
            floor = case when p_payload ? 'floor' then case when p_payload->>'floor' is null then null else (p_payload->>'floor')::int end else r.floor end
        from public.properties p
        where r.id = (p_payload->>'id')::uuid
          and p.id = r.property_id
          and p.tenant_id = v_tid
        returning r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at into v_row;
        if not found then raise exception 'Room not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_room' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        delete from public.rooms r
        using public.properties p
        where r.id = (p_payload->>'id')::uuid
          and p.id = r.property_id
          and p.tenant_id = v_tid;
        if not found then raise exception 'Room not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_categories' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order), '[]'::jsonb) into v_result
        from (
            select dc.code, dc.name, dc.description, dc.is_gateway, dc.is_lock, dc.is_active, dc.sort_order
            from public.device_categories dc where dc.is_active = true
        ) t;

    when 'list_devices' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if p_payload ? 'room_id' then
            if not exists (
                select 1
                from public.rooms r
                join public.properties p on p.id = r.property_id
                where r.id = (p_payload->>'room_id')::uuid
                  and p.tenant_id = v_tid
            ) then
                raise exception 'Room not found';
            end if;
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
                where d.tenant_id = v_tid
                  and d.id in (
                      select da.device_id
                      from public.device_assignments da
                      where da.room_id = (p_payload->>'room_id')::uuid
                  )
            ) t;
        elsif p_payload ? 'property_id' then
            if not exists (
                select 1
                from public.properties p
                where p.id = (p_payload->>'property_id')::uuid
                  and p.tenant_id = v_tid
            ) then
                raise exception 'Property not found';
            end if;
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
                where d.tenant_id = v_tid
                  and d.id in (
                      select da.device_id
                      from public.device_assignments da
                      where da.room_id in (
                          select r.id
                          from public.rooms r
                          join public.properties p on p.id = r.property_id
                          where r.property_id = (p_payload->>'property_id')::uuid
                            and p.tenant_id = v_tid
                      )
                  )
            ) t;
        else
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
                where d.tenant_id = v_tid
            ) t;
        end if;

    when 'get_device' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        v_device_id := (p_payload->>'id')::uuid;
        select jsonb_build_object(
            'id', d.id, 'tenant_id', d.tenant_id, 'parent_device_id', d.parent_device_id,
            'device_name', d.device_name, 'category_code', d.category_code, 'protocol', d.protocol,
            'model', d.model, 'manufacturer', d.manufacturer, 'is_active', d.is_active, 'created_at', d.created_at,
            'assignment', case when da.device_id is not null then jsonb_build_object(
                'room_id', da.room_id, 'assigned_at', da.assigned_at,
                'room', case when rm.id is not null then jsonb_build_object('id', rm.id, 'name', rm.name, 'property_id', rm.property_id) else null end
            ) else null end,
            'config', dc.config
        ) into v_result
        from public.devices d
        left join public.device_assignments da on da.device_id = d.id
        left join public.rooms rm on rm.id = da.room_id
        left join public.device_configurations dc on dc.device_id = d.id
        where d.id = v_device_id
          and d.tenant_id = v_tid;
        if v_result is null then raise exception 'Device not found'; end if;

    when 'create_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if p_payload ? 'parent_device_id' and p_payload->>'parent_device_id' is not null then
            if not exists (
                select 1
                from public.devices pd
                where pd.id = (p_payload->>'parent_device_id')::uuid
                  and pd.tenant_id = v_tid
            ) then
                raise exception 'Parent device not found';
            end if;
        end if;
        insert into public.devices (tenant_id, device_name, category_code, protocol, parent_device_id, model, manufacturer, is_active)
        values (
            v_tid, p_payload->>'device_name', p_payload->>'category_code',
            (p_payload->>'protocol')::public.device_protocol,
            case when p_payload ? 'parent_device_id' and p_payload->>'parent_device_id' is not null then (p_payload->>'parent_device_id')::uuid else null end,
            p_payload->>'model', p_payload->>'manufacturer',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, parent_device_id, device_name, category_code, protocol, model, manufacturer, is_active, created_at into v_row;
        v_result := to_jsonb(v_row);

    when 'update_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if p_payload ? 'parent_device_id' and p_payload->>'parent_device_id' is not null then
            if not exists (
                select 1
                from public.devices pd
                where pd.id = (p_payload->>'parent_device_id')::uuid
                  and pd.tenant_id = v_tid
            ) then
                raise exception 'Parent device not found';
            end if;
        end if;
        update public.devices d set
            device_name = case when p_payload ? 'device_name' then p_payload->>'device_name' else d.device_name end,
            category_code = case when p_payload ? 'category_code' then p_payload->>'category_code' else d.category_code end,
            protocol = case when p_payload ? 'protocol' then (p_payload->>'protocol')::public.device_protocol else d.protocol end,
            parent_device_id = case when p_payload ? 'parent_device_id' then case when p_payload->>'parent_device_id' is null then null else (p_payload->>'parent_device_id')::uuid end else d.parent_device_id end,
            model = case when p_payload ? 'model' then p_payload->>'model' else d.model end,
            manufacturer = case when p_payload ? 'manufacturer' then p_payload->>'manufacturer' else d.manufacturer end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else d.is_active end
        where d.id = (p_payload->>'id')::uuid
          and d.tenant_id = v_tid
        returning d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at into v_row;
        if not found then raise exception 'Device not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        delete from public.devices d
        where d.id = (p_payload->>'id')::uuid
          and d.tenant_id = v_tid;
        if not found then raise exception 'Device not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'assign_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        v_result := public.devices_assign_device_to_room((p_payload->>'device_id')::uuid, (p_payload->>'room_id')::uuid);

    when 'unassign_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if not exists (
            select 1
            from public.devices d
            where d.id = (p_payload->>'device_id')::uuid
              and d.tenant_id = v_tid
        ) then
            raise exception 'Device not found';
        end if;
        delete from public.device_assignments da
        where da.device_id = (p_payload->>'device_id')::uuid;
        v_result := jsonb_build_object('unassigned', true, 'device_id', p_payload->>'device_id');

    when 'get_device_config' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if not exists (
            select 1
            from public.devices d
            where d.id = (p_payload->>'device_id')::uuid
              and d.tenant_id = v_tid
        ) then
            raise exception 'Device not found';
        end if;
        select to_jsonb(t) into v_result
        from (
            select dc.id, dc.device_id, dc.config, dc.created_at, dc.updated_at
            from public.device_configurations dc
            where dc.device_id = (p_payload->>'device_id')::uuid
        ) t;
        if v_result is null then v_result := 'null'::jsonb; end if;

    when 'upsert_device_config' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'no active tenant'; end if;
        if not exists (
            select 1
            from public.devices d
            where d.id = (p_payload->>'device_id')::uuid
              and d.tenant_id = v_tid
        ) then
            raise exception 'Device not found';
        end if;
        insert into public.device_configurations (device_id, config)
        values ((p_payload->>'device_id')::uuid, coalesce(p_payload->'config', '{}'::jsonb))
        on conflict (device_id) do update set config = excluded.config
        returning id, device_id, config, created_at, updated_at into v_row;
        v_result := to_jsonb(v_row);

    else
        raise exception 'unknown devices_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;



-- =====================================================
-- 13. DEVICE ASSIGNMENT TENANT CONSISTENCY
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



-- =====================================================
-- 14. DEVICE HIERARCHY INVARIANT
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



-- =====================================================
-- 15. DEVICE CATEGORY POLICIES
-- =====================================================

create policy device_categories_select on public.device_categories
    for select to authenticated
    using (true);



create policy device_categories_write on public.device_categories
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());



-- =====================================================
-- 16. DEVICE POLICIES
-- =====================================================

create policy devices_delete on public.devices
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy devices_insert on public.devices
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy devices_select on public.devices
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy devices_update on public.devices
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



-- =====================================================
-- 17. PROPERTY POLICIES
-- =====================================================

create policy properties_delete on public.properties
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy properties_insert on public.properties
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy properties_select on public.properties
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy properties_update on public.properties
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



-- =====================================================
-- 18. ROOM POLICIES
-- =====================================================

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



-- =====================================================
-- 19. DEVICE ASSIGNMENT POLICIES
-- =====================================================

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



-- =====================================================
-- 20. DEVICE CONFIGURATION POLICIES
-- =====================================================

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



-- =====================================================
-- 21. TRIGGERS
-- =====================================================

create trigger trg_properties_updated_at
before update on properties
for each row execute function platform.set_updated_at();



create trigger trg_devices_hierarchy
before insert or update on public.devices
for each row execute function public.enforce_device_hierarchy();



create trigger trg_device_assignment_tenant_consistency
before insert or update on public.device_assignments
for each row execute function public.enforce_device_assignment_tenant_consistency();



create trigger trg_device_configurations_updated_at
before update on device_configurations
for each row execute function platform.set_updated_at();



-- =====================================================
-- 22. DEVICE CATEGORY SEED
-- =====================================================

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
-- END 004 PROPERTY & DEVICE ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('004_property_device_engine', 'REV22.PROPERTY.DEVICE', false)
on conflict (version) do nothing;