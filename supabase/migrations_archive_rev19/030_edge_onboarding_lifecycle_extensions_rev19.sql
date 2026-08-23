-- =====================================================
-- 030 EDGE ONBOARDING LIFECYCLE EXTENSIONS (017/023)
-- Thin Edge wrappers for 026 onboarding lifecycle domain
-- Does NOT modify prior migrations
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('030_edge_onboarding_lifecycle_extensions_rev19', 'REV19.EDGE.ONBOARDING.LIFECYCLE.EXT', false)
on conflict (version) do nothing;

create or replace function public.get_onboarding_lifecycle(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    return public.onboarding_lifecycle_get(p_property_id);
end;
$$;

create or replace function public.list_onboarding_lifecycle_transitions(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    return public.onboarding_lifecycle_list_transitions(p_property_id);
end;
$$;

create or replace function public.onboarding_lifecycle_transition(
    p_property_id uuid,
    p_to_state public.onboarding_lifecycle_state,
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.onboarding_lifecycle_apply_transition(p_property_id, p_to_state, p_metadata);
end;
$$;

revoke all on function public.get_onboarding_lifecycle(uuid) from public;
grant execute on function public.get_onboarding_lifecycle(uuid) to authenticated, service_role;

revoke all on function public.list_onboarding_lifecycle_transitions(uuid) from public;
grant execute on function public.list_onboarding_lifecycle_transitions(uuid) to authenticated, service_role;

revoke all on function public.onboarding_lifecycle_transition(uuid, public.onboarding_lifecycle_state, jsonb) from public;
grant execute on function public.onboarding_lifecycle_transition(uuid, public.onboarding_lifecycle_state, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- onboarding_api lifecycle ops (017/023 extension)
-- -----------------------------------------------------

create or replace function public.onboarding_api(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
        when 'get_lifecycle' then
            perform public.edge_require_tenant();
            return public.onboarding_lifecycle_get((p_payload->>'property_id')::uuid);

        when 'list_lifecycle_transitions' then
            perform public.edge_require_tenant();
            return public.onboarding_lifecycle_list_transitions((p_payload->>'property_id')::uuid);

        when 'lifecycle_transition' then
            perform public.edge_require_manager();
            return public.onboarding_lifecycle_apply_transition(
                (p_payload->>'property_id')::uuid,
                (p_payload->>'to_state')::public.onboarding_lifecycle_state,
                coalesce(p_payload->'metadata', '{}'::jsonb)
            );

        when 'list_sessions', 'get_session', 'list_step_states', 'list_room_mappings', 'list_device_mappings', 'list_checklist_items', 'list_notes' then
            perform public.edge_require_tenant();
            return public.onboarding_domain(p_op, p_payload);

        when 'create_session', 'update_session', 'delete_session', 'update_step_state', 'create_room_mapping', 'update_room_mapping', 'delete_room_mapping', 'create_device_mapping', 'update_device_mapping', 'delete_device_mapping', 'upsert_checklist_item', 'update_checklist_item', 'delete_checklist_item', 'create_note', 'delete_note' then
            perform public.edge_require_manager();
            return public.onboarding_domain(p_op, p_payload);

        else
            raise exception 'unknown onboarding_api operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.onboarding_api(text, jsonb) from public;
grant execute on function public.onboarding_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 030 EDGE ONBOARDING LIFECYCLE EXTENSIONS
-- =====================================================
