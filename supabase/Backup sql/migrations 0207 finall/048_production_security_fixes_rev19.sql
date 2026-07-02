-- =====================================================
-- 048_production_security_fixes_rev19.sql
-- Final audit fixes: API/domain guard alignment, device-map tenant ownership, dispatch grant hardening
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('048_production_security_fixes_rev19', 'REV19.SECURITY.PRODUCTION.FIXES', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- 017 Edge: align monetization_api package guards with monetization_domain
-- -----------------------------------------------------

create or replace function public.monetization_api(
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
        when 'list_proposals', 'get_proposal', 'list_proposal_items', 'list_packages', 'get_package',
             'list_upsell_campaigns', 'get_upsell_campaign', 'update_upsell_campaign', 'delete_upsell_campaign',
             'list_activation_state', 'list_conversion_events', 'list_conversion_scores' then
            perform public.edge_require_tenant();
        when 'create_proposal', 'update_proposal', 'delete_proposal', 'create_proposal_item', 'update_proposal_item',
             'delete_proposal_item' then
            perform public.edge_require_manager();
        when 'create_package', 'update_package', 'delete_package' then
            if not platform.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;
        when 'create_upsell_campaign' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown monetization_api operation: %', p_op;
    end case;

    return public.monetization_domain(p_op, p_payload);
end;
$$;

revoke all on function public.monetization_api(text, jsonb) from public;
grant execute on function public.monetization_api(text, jsonb) to authenticated, service_role;


-- -----------------------------------------------------
-- 005 Integrations: enforce active-tenant ownership on device-map writes
-- -----------------------------------------------------

create or replace function public.enforce_device_integration_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_tid uuid;
begin
    if new.external_id is null or btrim(new.external_id) = '' then
        raise exception 'external_id required';
    end if;

    select d.tenant_id
    into new.tenant_id
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    if not platform.is_platform_admin() then
        v_tid := platform.current_tenant_id();
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        if new.tenant_id is distinct from v_tid then
            raise exception 'device does not belong to active tenant';
        end if;
    end if;

    return new;
end;
$$;


-- -----------------------------------------------------
-- 008 Logistics: close direct authenticated execute bypass on dispatch RPC
-- Idempotent: skip if function not yet created (050 re-applies lockdown)
-- -----------------------------------------------------

do $block$
declare
    r record;
begin
    for r in
        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = 'logistics_dispatch_fulfilment_order'
    loop
        execute format(
            'revoke all on function %I.%I(%s) from public, authenticated',
            r.nspname, r.proname, r.args
        );
        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            r.nspname, r.proname, r.args
        );
    end loop;
end;
$block$;
