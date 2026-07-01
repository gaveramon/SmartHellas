-- 002 Core SaaS extensions: invite_member + validate_tenant_switch (auth_domain SSOT)

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('031_core_saas_auth_extensions_rev19', 'REV19.DOMAIN.CORE_SAAS.AUTH.EXT', false)
on conflict (version) do nothing;

create or replace function public.auth_domain(
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
    v_existing record;
    v_target_tid uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'get_auth_context' then
        if v_uid is null then raise exception 'authentication required'; end if;
        v_tid := platform.current_tenant_id();
        v_role := null;
        v_tenant_status := null;
        if v_tid is not null then
            select tm.role::text, t.status::text
            into v_role, v_tenant_status
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.tenant_id = v_tid and tm.user_id = v_uid and tm.is_active = true;
        end if;
        v_result := jsonb_build_object(
            'user_id', v_uid,
            'email', (select p.email from platform.profiles p where p.id = v_uid),
            'tenant_id', v_tid,
            'role', v_role,
            'tenant_status', v_tenant_status,
            'is_platform_admin', platform.is_platform_admin()
        );

    when 'list_user_tenants' then
        if v_uid is null then raise exception 'authentication required'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.tenant_id, t.name as tenant_name, tm.role, tm.is_active, t.status as tenant_status, tm.created_at
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.user_id = v_uid and tm.is_active = true
        ) t;

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

    when 'get_current_tenant' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select tn.id, tn.name, tn.status, tn.created_at, tn.updated_at
            from public.tenants tn where tn.id = v_tid
        ) t;
        if v_result is null then raise exception 'Tenant not found'; end if;

    when 'create_tenant' then
        if v_uid is null then raise exception 'authentication required'; end if;
        insert into public.tenants (name) values (p_payload->>'name')
        returning id, name, status, created_at, updated_at into v_row;
        perform platform.log_audit('tenant.created', 'tenant', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'created_by', v_uid));
        v_result := to_jsonb(v_row);

    when 'update_tenant' then
        v_tid := platform.current_tenant_id();
        update public.tenants tn set
            name = case when p_payload ? 'name' then p_payload->>'name' else tn.name end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.tenant_status else tn.status end
        where tn.id = v_tid
        returning tn.id, tn.name, tn.status, tn.created_at, tn.updated_at into v_row;
        if not found then raise exception 'Tenant not found'; end if;
        perform platform.log_audit('tenant.updated', 'tenant', v_tid, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_memberships' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at,
                   p.email, p.full_name, tm.created_at
            from public.tenant_memberships tm
            left join platform.profiles p on p.id = tm.user_id
            where tm.tenant_id = v_tid
        ) t;

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

    when 'update_membership' then
        v_tid := platform.current_tenant_id();
        select tm.id, tm.user_id, tm.tenant_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id = v_uid then
            if p_payload ? 'role' then raise exception 'Cannot change your own role via this endpoint'; end if;
        else
        end if;
        update public.tenant_memberships tm set
            role = case when p_payload ? 'role' then (p_payload->>'role')::public.user_role else tm.role end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else tm.is_active end,
            revoked_at = case
                when p_payload ? 'is_active' and not (p_payload->>'is_active')::boolean then now()
                when p_payload ? 'is_active' and (p_payload->>'is_active')::boolean then null
                else tm.revoked_at
            end
        where tm.id = (p_payload->>'membership_id')::uuid
        returning tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at, tm.created_at into v_row;
        perform platform.log_audit('membership.updated', 'tenant_membership', v_row.id, p_payload);
        select jsonb_build_object(
            'id', v_row.id,
            'user_id', v_row.user_id,
            'tenant_id', v_row.tenant_id,
            'role', v_row.role,
            'is_active', v_row.is_active,
            'revoked_at', v_row.revoked_at,
            'email', p.email,
            'full_name', p.full_name,
            'created_at', v_row.created_at
        ) into v_result
        from platform.profiles p where p.id = v_row.user_id;

    when 'revoke_membership' then
        v_tid := platform.current_tenant_id();
        select tm.id, tm.user_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id <> v_uid then perform public.edge_require_admin(); end if;
        delete from public.tenant_memberships tm where tm.id = (p_payload->>'membership_id')::uuid;
        perform platform.log_audit('membership.revoked', 'tenant_membership', (p_payload->>'membership_id')::uuid,
            jsonb_build_object('tenant_id', v_tid, 'revoked_by', v_uid));
        v_result := jsonb_build_object('revoked', true, 'membership_id', p_payload->>'membership_id');

    when 'get_subscription' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at
            from public.subscriptions s where s.tenant_id = v_tid
        ) t;

    when 'update_subscription' then
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.subscriptions s where s.tenant_id = v_tid) then
            raise exception 'Subscription not found for tenant';
        end if;
        update public.subscriptions s set
            tier = case when p_payload ? 'tier' then (p_payload->>'tier')::public.subscription_tier else s.tier end,
            status = case when p_payload ? 'status' then (p_payload->>'status')::public.subscription_status else s.status end,
            current_period_start = case when p_payload ? 'current_period_start'
                then (p_payload->>'current_period_start')::timestamptz else s.current_period_start end,
            current_period_end = case when p_payload ? 'current_period_end'
                then (p_payload->>'current_period_end')::timestamptz else s.current_period_end end
        where s.tenant_id = v_tid
        returning s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at into v_row;
        perform platform.log_audit('subscription.updated', 'subscription', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_service_accounts' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at
            from public.service_accounts sa where sa.tenant_id = v_tid
        ) t;

    when 'create_service_account' then
        v_tid := platform.current_tenant_id();
        insert into public.service_accounts (tenant_id, name, provider_code, is_active)
        values (
            v_tid, p_payload->>'name', p_payload->>'provider_code',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, name, provider_code, is_active, created_at into v_row;
        perform platform.log_audit('service_account.created', 'service_account', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'provider_code', p_payload->>'provider_code'));
        v_result := to_jsonb(v_row);

    when 'update_service_account' then
        v_tid := platform.current_tenant_id();
        update public.service_accounts sa set
            name = case when p_payload ? 'name' then p_payload->>'name' else sa.name end,
            provider_code = case when p_payload ? 'provider_code' then p_payload->>'provider_code' else sa.provider_code end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else sa.is_active end
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid
        returning sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at into v_row;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.updated', 'service_account', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_service_account' then
        v_tid := platform.current_tenant_id();
        delete from public.service_accounts sa
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.deleted', 'service_account', (p_payload->>'service_account_id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'service_account_id', p_payload->>'service_account_id');

    else
        raise exception 'unknown auth_api operation: %', p_op;
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

revoke all on function public.auth_domain(text, jsonb) from public;
grant execute on function public.auth_domain(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;
