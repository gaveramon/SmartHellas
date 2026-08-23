-- =====================================================
-- 027 AUTOMATION EXTENSIONS (016)
-- Subscription domain ops + UI view (extends automation_domain_ext only)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('027_automation_extensions_rev19', 'REV19.AUTOMATION.EXT', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. DOMAIN EXTENSION — SUBSCRIPTION OPS
-- =====================================================

create or replace function public.automation_domain_ext(
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
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_tid := platform.current_tenant_id();

    case p_op
    when 'list_subscriptions' then
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb)
        into v_result
        from (
            select
                aes.id,
                aes.tenant_id,
                aes.workflow_trigger_id,
                aes.is_active,
                wt.workflow_id,
                wt.trigger_type,
                wt.property_id,
                aes.created_at
            from public.automation_event_subscriptions aes
            join public.workflow_triggers wt on wt.id = aes.workflow_trigger_id
            where aes.tenant_id = v_tid
              and case
                when p_payload ? 'workflow_id'
                then wt.workflow_id = (p_payload->>'workflow_id')::uuid
                else true
            end
        ) t;

    when 'upsert_subscription' then
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        insert into public.automation_event_subscriptions (
            tenant_id, workflow_trigger_id, is_active
        )
        values (
            v_tid,
            (p_payload->>'workflow_trigger_id')::uuid,
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        on conflict (workflow_trigger_id) do update set
            is_active = coalesce(
                excluded.is_active,
                public.automation_event_subscriptions.is_active
            )
        where public.automation_event_subscriptions.tenant_id = excluded.tenant_id
        returning id, tenant_id, workflow_trigger_id, is_active, created_at into v_row;
        v_result := to_jsonb(v_row);

    when 'delete_subscription' then
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        delete from public.automation_event_subscriptions aes
        where aes.id = (p_payload->>'id')::uuid
          and aes.tenant_id = v_tid;
        if not found then raise exception 'subscription not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        raise exception 'unknown automation_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.automation_domain_ext(text, jsonb) from public;
grant execute on function public.automation_domain_ext(text, jsonb) to authenticated, service_role;

-- =====================================================
-- 2. UI VIEW (Appsmith read contract)
-- =====================================================

create or replace view public.v_automation_runs_overview
with (security_invoker = true)
as
select
    ar.id,
    ar.tenant_id,
    ar.workflow_id,
    ow.name as workflow_name,
    ar.trigger_type,
    ar.status,
    ar.correlation_id,
    ar.started_at,
    ar.completed_at,
    ar.error_message,
    (
        select count(*)
        from public.automation_run_steps ars
        where ars.run_id = ar.id
    ) as step_count,
    (
        select count(*)
        from public.automation_run_steps ars
        where ars.run_id = ar.id and ars.status = 'completed'
    ) as completed_step_count,
    ar.created_at
from public.automation_runs ar
join public.operation_workflows ow on ow.id = ar.workflow_id;

grant select on public.v_automation_runs_overview to authenticated;

-- =====================================================
-- END 027 AUTOMATION EXTENSIONS
-- =====================================================
