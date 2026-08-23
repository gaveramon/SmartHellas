-- =====================================================
-- 038 EDGE API ARCHITECTURE COMPLETION (017)
-- Extends thin wrappers for 034–037 without breaking existing routes.
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('038_edge_api_architecture_completion_rev19', 'REV19.EDGE.API.COMPLETION', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. BOOKING API — access window ops (004)
-- =====================================================

create or replace function public.booking_api(
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
        when 'calculate_access_window' then
            perform public.edge_require_tenant();
            return public.booking_calculate_access_window((p_payload->>'booking_id')::uuid);

        when 'generate_booking_access' then
            return public.booking_generate_booking_access((p_payload->>'booking_id')::uuid);

        when 'regenerate_booking_access' then
            return public.booking_regenerate_booking_access((p_payload->>'booking_id')::uuid);

        when 'create_booking_access' then
            return public.booking_create_booking_access(p_payload);

        when 'list_bookings', 'get_booking', 'get_access_schedule', 'get_booking_access',
             'list_access_policies', 'list_access_rules' then
            perform public.edge_require_tenant();
            return public.booking_domain(p_op, p_payload);

        when 'create_booking', 'update_booking', 'delete_booking', 'upsert_access_schedule',
             'delete_booking_access', 'create_access_policy', 'update_access_policy',
             'delete_access_policy', 'create_access_rule', 'update_access_rule',
             'delete_access_rule' then
            perform public.edge_require_manager();
            return public.booking_domain(p_op, p_payload);

        else
            raise exception 'unknown booking_api operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.booking_api(text, jsonb) from public;
grant execute on function public.booking_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 038 EDGE API ARCHITECTURE COMPLETION
-- =====================================================
