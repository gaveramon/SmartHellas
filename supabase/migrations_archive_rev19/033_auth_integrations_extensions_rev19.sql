-- 002 Auth + 005 Integrations extensions (domain_ext only; SSOT in 002/005)

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('033_auth_integrations_extensions_rev19', 'REV19.EDGE.AUTH_INTEGRATIONS.EXT', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- 002 Auth: resolve_user_by_email (extends auth_domain via auth_domain_ext)
-- -----------------------------------------------------

create or replace function public.auth_domain_ext_031(
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
    v_uid uuid;
    v_row record;
    v_result jsonb;
    v_role text;
    v_tenant_status text;
    v_target_tid uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'validate_tenant_switch' then
        if v_uid is null then raise exception 'authentication required'; end if;
        if p_payload->>'tenant_id' is null then raise exception 'tenant_id is required'; end if;
        v_target_tid := (p_payload->>'tenant_id')::uuid;
        if not public.has_tenant_access(v_target_tid) then
            raise exception 'No access to the requested tenant';
        end if;
        select tm.role::text, t.status::text
        into v_role, v_tenant_status
        from public.tenant_memberships tm
        join public.tenants t on t.id = tm.tenant_id
        where tm.tenant_id = v_target_tid
          and tm.user_id = v_uid
          and tm.is_active = true;
        if v_role is null then raise exception 'No active membership for tenant'; end if;
        if v_tenant_status in ('suspended', 'deleted') then
            raise exception 'Tenant is not available';
        end if;
        v_result := jsonb_build_object(
            'tenant_id', v_target_tid,
            'role', v_role,
            'tenant_status', v_tenant_status
        );

    when 'invite_member' then
        v_tid := platform.current_tenant_id();
        if p_payload->>'user_id' is null then raise exception 'user_id is required'; end if;
        if p_payload->>'role' is null then raise exception 'role is required'; end if;
        if exists (
            select 1
            from public.tenant_memberships tm
            where tm.tenant_id = v_tid
              and tm.user_id = (p_payload->>'user_id')::uuid
              and tm.is_active = true
        ) then
            raise exception 'User is already an active member of this tenant';
        end if;
        insert into public.tenant_memberships (tenant_id, user_id, role, is_active)
        values (
            v_tid,
            (p_payload->>'user_id')::uuid,
            (p_payload->>'role')::public.user_role,
            true
        )
        returning id, user_id, tenant_id, role, is_active, revoked_at, created_at into v_row;
        perform platform.log_audit(
            'membership.created',
            'tenant_membership',
            v_row.id,
            jsonb_build_object(
                'tenant_id', v_tid,
                'user_id', v_row.user_id,
                'role', v_row.role,
                'invited_by', v_uid
            )
        );
        select jsonb_build_object(
            'id', v_row.id,
            'user_id', v_row.user_id,
            'tenant_id', v_row.tenant_id,
            'role', v_row.role,
            'is_active', v_row.is_active,
            'revoked_at', v_row.revoked_at,
            'email', coalesce(p_payload->>'email', p.email),
            'full_name', p.full_name,
            'created_at', v_row.created_at
        ) into v_result
        from platform.profiles p
        where p.id = v_row.user_id;

    else
        raise exception 'unknown auth_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;

create or replace function public.auth_domain_ext(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_result jsonb;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'resolve_user_by_email' then
        if p_payload->>'email' is null then raise exception 'email is required'; end if;
        select to_jsonb(t) into v_result from (
            select p.id, p.email, p.full_name
            from platform.profiles p
            where lower(p.email) = lower(p_payload->>'email')
            limit 1
        ) t;
        return v_result;

    else
        return public.auth_domain_ext_031(p_op, p_payload);
    end case;
end;
$$;

create or replace function public.auth_api(
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
        when 'get_auth_context', 'list_user_tenants', 'create_tenant', 'validate_tenant_switch' then
            null;
        when 'invite_member', 'resolve_user_by_email' then
            perform public.edge_require_tenant();
            perform public.edge_require_admin();
        when 'get_current_tenant', 'list_memberships', 'update_membership', 'revoke_membership',
             'get_subscription', 'list_service_accounts' then
            perform public.edge_require_tenant();
        when 'update_tenant', 'update_subscription', 'create_service_account', 'update_service_account',
             'delete_service_account' then
            perform public.edge_require_admin();
        else
            raise exception 'unknown auth_api operation: %', p_op;
    end case;

    return public.auth_domain(p_op, p_payload);
end;
$$;

-- -----------------------------------------------------
-- 005 Integrations: OAuth state + sync (extends integrations_domain via integrations_domain_ext)
-- -----------------------------------------------------

create or replace function public.integrations_domain_ext(
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
    v_uid uuid;
    v_result jsonb;
    v_state_token text;
    v_expires_at timestamptz;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'register_oauth_state' then
        v_tid := platform.current_tenant_id();
        v_uid := auth.uid();
        if p_payload->>'provider_code' is null then
            raise exception 'provider_code is required';
        end if;
        if not exists (
            select 1 from public.integration_providers ip
            where ip.code = p_payload->>'provider_code'
              and ip.supports_oauth = true
              and ip.is_active = true
        ) then
            raise exception 'Integration provider not found or does not support OAuth';
        end if;
        v_state_token := encode(extensions.gen_random_bytes(32), 'hex');
        v_expires_at := now() + interval '10 minutes';
        insert into public.integration_oauth_states (
            tenant_id, user_id, provider_code, state_token, expires_at
        )
        values (
            v_tid, v_uid, p_payload->>'provider_code', v_state_token, v_expires_at
        );
        v_result := jsonb_build_object(
            'state_token', v_state_token,
            'expires_at', v_expires_at,
            'provider_code', p_payload->>'provider_code'
        );

    when 'request_sync' then
        v_tid := platform.current_tenant_id();
        v_uid := auth.uid();
        if p_payload->>'provider_code' is null then
            raise exception 'provider_code is required';
        end if;
        if not exists (
            select 1 from public.tenant_integrations ti
            where ti.tenant_id = v_tid
              and ti.provider_code = p_payload->>'provider_code'
              and ti.is_enabled = true
        ) then
            raise exception 'Integration not connected or disabled';
        end if;
        perform platform.push_integration_event(
            p_payload->>'provider_code',
            'sync_state',
            jsonb_build_object(
                'tenant_id', v_tid,
                'triggered_by', v_uid,
                'scope', coalesce(p_payload->'scope', '{}'::jsonb)
            )
        );
        perform platform.log_audit(
            'integration.sync_requested',
            'tenant_integration',
            (
                select ti.id from public.tenant_integrations ti
                where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
            ),
            jsonb_build_object('provider_code', p_payload->>'provider_code')
        );
        v_result := jsonb_build_object(
            'queued', true,
            'provider_code', p_payload->>'provider_code'
        );

    when 'resolve_oauth_state' then
        if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
            raise exception 'state_token is required';
        end if;
        return public.integrations_resolve_oauth_state(p_payload->>'state_token');

    when 'complete_oauth' then
        if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
            raise exception 'state_token is required';
        end if;
        return public.integrations_complete_oauth(
            (p_payload->>'tenant_id')::uuid,
            p_payload->>'provider_code',
            p_payload->>'credentials_ref',
            p_payload->>'state_token'
        );

    else
        raise exception 'unknown integrations_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;

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
        when 'list_providers', 'get_provider', 'list_capabilities', 'list_tenant_integrations', 'get_tenant_integration', 'list_webhook_definitions', 'list_device_maps' then
            perform public.edge_require_tenant();
        when 'connect_integration', 'update_integration', 'disconnect_integration', 'create_webhook_definition', 'update_webhook_definition', 'delete_webhook_definition', 'create_device_map', 'update_device_map', 'delete_device_map', 'register_oauth_state', 'request_sync' then
            perform public.edge_require_manager();
        when 'resolve_oauth_state', 'complete_oauth' then
            null;
        else
            raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return public.integrations_domain(p_op, p_payload);
end;
$$;

revoke all on function public.auth_domain_ext_031(text, jsonb) from public;
grant execute on function public.auth_domain_ext_031(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_domain_ext(text, jsonb) from public;
grant execute on function public.auth_domain_ext(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_domain_ext(text, jsonb) from public;
grant execute on function public.integrations_domain_ext(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;
