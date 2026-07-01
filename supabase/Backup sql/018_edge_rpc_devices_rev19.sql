-- =====================================================
-- 018 EDGE RPC DEVICES (REV19)
-- SQL SSOT: public.devices_api for property / room / device domain
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('018_edge_rpc_devices_rev19', 'REV19.EDGE.RPC.DEVICES', false)
on conflict (version) do nothing;

create or replace function public.devices_api(
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
        perform public.edge_require_tenant();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb)
        into v_result
        from (
            select p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at
            from public.properties p
        ) t;

    when 'get_property' then
        perform public.edge_require_tenant();
        select to_jsonb(t) into v_result
        from (
            select p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at
            from public.properties p where p.id = (p_payload->>'id')::uuid
        ) t;
        if v_result is null then raise exception 'Property not found'; end if;

    when 'create_property' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
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
        update public.properties p set
            name = case when p_payload ? 'name' then p_payload->>'name' else p.name end,
            address = case when p_payload ? 'address' then p_payload->>'address' else p.address end,
            property_type = case when p_payload ? 'property_type' then (p_payload->>'property_type')::public.property_type else p.property_type end,
            timezone = case when p_payload ? 'timezone' then p_payload->>'timezone' else p.timezone end
        where p.id = (p_payload->>'id')::uuid
        returning p.id, p.tenant_id, p.name, p.address, p.property_type, p.timezone, p.created_at, p.updated_at into v_row;
        if not found then raise exception 'Property not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_property' then
        perform public.edge_require_manager();
        delete from public.properties p where p.id = (p_payload->>'id')::uuid;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_rooms' then
        perform public.edge_require_tenant();
        if p_payload ? 'property_id' then
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at
                from public.rooms r where r.property_id = (p_payload->>'property_id')::uuid
            ) t;
        else
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at from public.rooms r
            ) t;
        end if;

    when 'get_room' then
        perform public.edge_require_tenant();
        select to_jsonb(t) into v_result
        from (
            select r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at
            from public.rooms r where r.id = (p_payload->>'id')::uuid
        ) t;
        if v_result is null then raise exception 'Room not found'; end if;

    when 'create_room' then
        perform public.edge_require_manager();
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
        update public.rooms r set
            name = case when p_payload ? 'name' then p_payload->>'name' else r.name end,
            room_type = case when p_payload ? 'room_type' then (p_payload->>'room_type')::public.room_type else r.room_type end,
            floor = case when p_payload ? 'floor' then case when p_payload->>'floor' is null then null else (p_payload->>'floor')::int end else r.floor end
        where r.id = (p_payload->>'id')::uuid
        returning r.id, r.property_id, r.name, r.room_type, r.floor, r.created_at into v_row;
        if not found then raise exception 'Room not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_room' then
        perform public.edge_require_manager();
        delete from public.rooms r where r.id = (p_payload->>'id')::uuid;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_categories' then
        perform public.edge_require_tenant();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order), '[]'::jsonb) into v_result
        from (
            select dc.code, dc.name, dc.description, dc.is_gateway, dc.is_lock, dc.is_active, dc.sort_order
            from public.device_categories dc where dc.is_active = true
        ) t;

    when 'list_devices' then
        perform public.edge_require_tenant();
        if p_payload ? 'room_id' then
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
                where d.id in (select da.device_id from public.device_assignments da where da.room_id = (p_payload->>'room_id')::uuid)
            ) t;
        elsif p_payload ? 'property_id' then
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
                where d.id in (
                    select da.device_id from public.device_assignments da
                    where da.room_id in (select r.id from public.rooms r where r.property_id = (p_payload->>'property_id')::uuid)
                )
            ) t;
        else
            select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
            from (
                select d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at
                from public.devices d
            ) t;
        end if;

    when 'get_device' then
        perform public.edge_require_tenant();
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
        where d.id = v_device_id;
        if v_result is null then raise exception 'Device not found'; end if;

    when 'create_device' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
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
        update public.devices d set
            device_name = case when p_payload ? 'device_name' then p_payload->>'device_name' else d.device_name end,
            category_code = case when p_payload ? 'category_code' then p_payload->>'category_code' else d.category_code end,
            protocol = case when p_payload ? 'protocol' then (p_payload->>'protocol')::public.device_protocol else d.protocol end,
            parent_device_id = case when p_payload ? 'parent_device_id' then case when p_payload->>'parent_device_id' is null then null else (p_payload->>'parent_device_id')::uuid end else d.parent_device_id end,
            model = case when p_payload ? 'model' then p_payload->>'model' else d.model end,
            manufacturer = case when p_payload ? 'manufacturer' then p_payload->>'manufacturer' else d.manufacturer end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else d.is_active end
        where d.id = (p_payload->>'id')::uuid
        returning d.id, d.tenant_id, d.parent_device_id, d.device_name, d.category_code, d.protocol, d.model, d.manufacturer, d.is_active, d.created_at into v_row;
        if not found then raise exception 'Device not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_device' then
        perform public.edge_require_manager();
        delete from public.devices d where d.id = (p_payload->>'id')::uuid;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'assign_device' then
        perform public.edge_require_manager();
        v_result := public.assign_device_to_room((p_payload->>'device_id')::uuid, (p_payload->>'room_id')::uuid);

    when 'unassign_device' then
        perform public.edge_require_manager();
        delete from public.device_assignments da where da.device_id = (p_payload->>'device_id')::uuid;
        v_result := jsonb_build_object('unassigned', true, 'device_id', p_payload->>'device_id');

    when 'get_device_config' then
        perform public.edge_require_tenant();
        select to_jsonb(t) into v_result
        from (
            select dc.id, dc.device_id, dc.config, dc.created_at, dc.updated_at
            from public.device_configurations dc where dc.device_id = (p_payload->>'device_id')::uuid
        ) t;
        if v_result is null then v_result := 'null'::jsonb; end if;

    when 'upsert_device_config' then
        perform public.edge_require_manager();
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

revoke all on function public.devices_api(text, jsonb) from public;
grant execute on function public.devices_api(text, jsonb) to authenticated, service_role;
