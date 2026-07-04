-- =====================================================
-- 029 EDGE AUTOMATION API EXTENSIONS (017/023)
-- Thin wrapper ops for 027 automation_domain extensions
-- Does NOT modify prior migrations
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('029_edge_automation_api_extensions_rev19', 'REV19.EDGE.AUTOMATION.API.EXT', false)
on conflict (version) do nothing;

create or replace function public.automation_api(
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
        when 'list_runs', 'get_run', 'list_run_steps', 'list_subscriptions' then
            perform public.edge_require_tenant();
        when 'dispatch_event', 'start_run', 'cancel_run', 'upsert_subscription', 'delete_subscription' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown automation_api operation: %', p_op;
    end case;

    return public.automation_domain(p_op, p_payload);
end;
$$;

revoke all on function public.automation_api(text, jsonb) from public;
grant execute on function public.automation_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 029 EDGE AUTOMATION API EXTENSIONS
-- =====================================================
