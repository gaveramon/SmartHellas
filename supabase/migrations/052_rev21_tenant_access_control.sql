-- =====================================================
-- REV21 FINAL AUTHORITY FREEZE
-- =====================================================

-- SINGLE SOURCE OF TRUTH ENFORCEMENT NOTE
-- Tenant resolution MUST ONLY occur via:
-- public.resolve_active_tenant(auth.uid())

-- DO NOT introduce:
-- - JWT-based tenant resolution
-- - membership EXISTS checks outside resolver
-- - alternative tenant gates

-- Any deviation is considered architecture drift
-- =====================================================

-- =====================================================
-- 052_rev21_tenant_access_control.sql
-- REV21: single authority gate + RLS compatibility shims
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('052_rev21_tenant_access_control', 'REV21.TENANT.ACCESS.CONTROL', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- edge_require_tenant: sole enforcement gate
-- Authority: resolve_active_tenant(auth.uid()) IS NOT NULL
-- -----------------------------------------------------

create or replace function public.edge_require_tenant()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
begin
    v_tid := public.resolve_active_tenant(auth.uid());
    if v_tid is null then
        raise exception 'NO_ACTIVE_TENANT';
    end if;
end;
$$;

revoke all on function public.edge_require_tenant() from public;
grant execute on function public.edge_require_tenant() to authenticated, service_role;


-- -----------------------------------------------------
-- has_tenant_access: RLS compatibility shim (not an authority surface)
-- Pure delegate: tid = resolve_active_tenant(auth.uid())
-- -----------------------------------------------------

create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select tid = public.resolve_active_tenant((select auth.uid()));
$$;

create or replace function public.has_tenant_access(p_tid uuid)
returns boolean
language sql
stable
as $$
  select p_tid = public.resolve_active_tenant(auth.uid());
$$;

comment on function platform.has_tenant_access(uuid) is
    'RLS shim only. tid = resolve_active_tenant(auth.uid()). Not an authority surface.';

comment on function public.has_tenant_access(uuid) is
    'RLS shim only. p_tid = resolve_active_tenant(auth.uid()). Not an authority surface.';

revoke all on function public.has_tenant_access(uuid) from public;
grant execute on function public.has_tenant_access(uuid) to authenticated, service_role;

revoke all on function platform.has_tenant_access(uuid) from public;
grant execute on function platform.has_tenant_access(uuid) to authenticated, service_role;


-- -----------------------------------------------------
-- integrations_api: gate + resource bind via current_tenant_id()
-- -----------------------------------------------------

create or replace function public.integrations_api(
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
        when 'oauth_complete' then
            return public.integrations_oauth_complete_api(p_payload);
        when 'complete_oauth' then
            raise exception 'complete_oauth is not available; use oauth_complete';
        when 'list_providers', 'get_provider', 'list_capabilities', 'list_webhook_definitions', 'list_device_maps' then
            perform public.edge_require_tenant();
        when 'list_tenant_integrations', 'get_tenant_integration' then
            perform public.edge_require_manager();
        when 'connect_integration', 'update_integration', 'disconnect_integration', 'create_webhook_definition', 'update_webhook_definition', 'delete_webhook_definition', 'create_device_map', 'update_device_map', 'delete_device_map', 'register_oauth_state', 'start_oauth', 'request_sync' then
            perform public.edge_require_manager();
        when 'resolve_oauth_state' then
            perform public.edge_require_tenant();
            if not exists (
                select 1
                from public.integration_oauth_states s
                where s.state_token = p_payload->>'state_token'
                  and s.consumed_at is null
                  and s.expires_at > now()
                  and s.user_id = (select auth.uid())
                  and s.tenant_id = platform.current_tenant_id()
            ) then
                raise exception 'unauthorized';
            end if;
        else
            raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return public.integrations_domain(p_op, p_payload);
end;
$$;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;


-- -----------------------------------------------------
-- integrations_resolve_oauth_state: gate via current_tenant_id()
-- -----------------------------------------------------

create or replace function public.integrations_resolve_oauth_state(p_state_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.integration_oauth_states;
    v_uid uuid;
    v_tid uuid;
begin
    if p_state_token is null or length(trim(p_state_token)) = 0 then
        raise exception 'OAuth state token is required';
    end if;

    select * into v_row
    from public.integration_oauth_states s
    where s.state_token = p_state_token
      and s.consumed_at is null
      and s.expires_at > now()
    for update;

    if not found then
        raise exception 'Invalid or expired OAuth state';
    end if;

    v_uid := (select auth.uid());
    if v_uid is not null then
        v_tid := platform.current_tenant_id();
        if v_row.user_id <> v_uid then
            raise exception 'unauthorized';
        end if;
        if v_tid is null or v_row.tenant_id <> v_tid then
            raise exception 'unauthorized';
        end if;
    end if;

    return jsonb_build_object(
        'tenant_id', v_row.tenant_id,
        'provider_code', v_row.provider_code,
        'user_id', v_row.user_id
    );
end;
$$;

alter function public.edge_require_tenant() set search_path = '';
alter function platform.has_tenant_access(uuid) set search_path = '';
alter function public.has_tenant_access(uuid) set search_path = '';
alter function public.integrations_api(text, jsonb) set search_path = '';
alter function public.integrations_resolve_oauth_state(text) set search_path = '';

-- =====================================================
-- END 052 REV21 TENANT ACCESS CONTROL
-- =====================================================
