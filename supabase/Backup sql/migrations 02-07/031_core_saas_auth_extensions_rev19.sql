-- 002 Core SaaS extensions: invite_member + validate_tenant_switch (auth_domain_ext only)

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('031_core_saas_auth_extensions_rev19', 'REV19.DOMAIN.CORE_SAAS.AUTH.EXT', false)
on conflict (version) do nothing;

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
        when 'invite_member' then
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

revoke all on function public.auth_domain_ext(text, jsonb) from public;
grant execute on function public.auth_domain_ext(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;
