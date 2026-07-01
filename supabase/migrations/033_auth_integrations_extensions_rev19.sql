-- 002 Auth + 005 Integrations extensions (Edge REV19 compliance)

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('033_auth_integrations_extensions_rev19', 'REV19.EDGE.AUTH_INTEGRATIONS.EXT', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- 002 Auth: resolve_user_by_email (admin-only profile lookup SSOT)
-- -----------------------------------------------------

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

    when 'resolve_user_by_email' then
        if p_payload->>'email' is null then raise exception 'email is required'; end if;
        select to_jsonb(t) into v_result from (
            select p.id, p.email, p.full_name
            from platform.profiles p
            where lower(p.email) = lower(p_payload->>'email')
            limit 1
        ) t;

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
-- 005 Integrations: OAuth state registration + sync SSOT
-- -----------------------------------------------------

create or replace function public.integrations_domain(
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
    v_existing uuid;
    v_state_token text;
    v_expires_at timestamptz;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_providers' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.is_active = true
        ) t;

    when 'get_provider' then
        select to_jsonb(t) into v_result from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.code = p_payload->>'code'
        ) t;
        if v_result is null then raise exception 'Integration provider not found'; end if;

    when 'list_capabilities' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ic.provider_code, ic.capability_code, ic.description, ic.is_supported
            from public.integration_capabilities ic
            where ic.is_supported = true
              and (p_payload->>'provider_code' is null or ic.provider_code = p_payload->>'provider_code')
        ) t;

    when 'list_tenant_integrations' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti where ti.tenant_id = v_tid
        ) t;

    when 'get_tenant_integration' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti
            where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        ) t;

    when 'connect_integration' then
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.integration_providers ip where ip.code = p_payload->>'provider_code') then
            raise exception 'Integration provider not found';
        end if;
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if found then
            update public.tenant_integrations ti set
                credentials_ref = coalesce(p_payload->>'credentials_ref', ti.credentials_ref),
                config = coalesce(p_payload->'config', ti.config),
                is_enabled = coalesce((p_payload->>'is_enabled')::boolean, ti.is_enabled)
            where ti.id = v_existing
            returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
            perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id);
        else
            insert into public.tenant_integrations (tenant_id, provider_code, credentials_ref, config, is_enabled)
            values (
                v_tid, p_payload->>'provider_code', p_payload->>'credentials_ref',
                coalesce(p_payload->'config', '{}'::jsonb),
                coalesce((p_payload->>'is_enabled')::boolean, true)
            )
            returning id, tenant_id, provider_code, credentials_ref, config, is_enabled, created_at, updated_at into v_row;
            perform platform.log_audit('integration.connected', 'tenant_integration', v_row.id,
                jsonb_build_object('provider_code', p_payload->>'provider_code'));
        end if;
        v_result := to_jsonb(v_row);

    when 'update_integration' then
        v_tid := platform.current_tenant_id();
        update public.tenant_integrations ti set
            credentials_ref = case when p_payload ? 'credentials_ref' then p_payload->>'credentials_ref' else ti.credentials_ref end,
            config = case when p_payload ? 'config' then p_payload->'config' else ti.config end,
            is_enabled = case when p_payload ? 'is_enabled' then (p_payload->>'is_enabled')::boolean else ti.is_enabled end
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
        if not found then raise exception 'Integration not found'; end if;
        perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'disconnect_integration' then
        v_tid := platform.current_tenant_id();
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if not found then raise exception 'Integration not found'; end if;
        delete from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        perform platform.log_audit('integration.disconnected', 'tenant_integration', v_existing,
            jsonb_build_object('provider_code', p_payload->>'provider_code'));
        v_result := jsonb_build_object('disconnected', true, 'provider_code', p_payload->>'provider_code');

    when 'list_webhook_definitions' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at
            from public.webhook_definitions wd
            where wd.tenant_id = v_tid
              and (p_payload->>'provider_code' is null or wd.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_webhook_definition' then
        v_tid := platform.current_tenant_id();
        insert into public.webhook_definitions (tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active)
        values (
            v_tid, p_payload->>'provider_code', p_payload->>'event_type', p_payload->>'target_url',
            p_payload->>'signing_secret_ref',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('webhook_definition.created', 'webhook_definition', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_webhook_definition' then
        v_tid := platform.current_tenant_id();
        update public.webhook_definitions wd set
            event_type = case when p_payload ? 'event_type' then p_payload->>'event_type' else wd.event_type end,
            target_url = case when p_payload ? 'target_url' then p_payload->>'target_url' else wd.target_url end,
            signing_secret_ref = case when p_payload ? 'signing_secret_ref' then p_payload->>'signing_secret_ref' else wd.signing_secret_ref end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else wd.is_active end
        where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid
        returning wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at into v_row;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.updated', 'webhook_definition', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_webhook_definition' then
        v_tid := platform.current_tenant_id();
        delete from public.webhook_definitions wd where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.deleted', 'webhook_definition', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_maps' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at
            from public.device_integration_map dim
            where dim.tenant_id = v_tid
              and (p_payload->>'device_id' is null or dim.device_id = (p_payload->>'device_id')::uuid)
              and (p_payload->>'provider_code' is null or dim.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_device_map' then
        v_tid := platform.current_tenant_id();
        insert into public.device_integration_map (device_id, provider_code, external_id, config)
        values (
            (p_payload->>'device_id')::uuid,
            p_payload->>'provider_code',
            p_payload->>'external_id',
            coalesce(p_payload->'config', '{}'::jsonb)
        )
        returning id, tenant_id, device_id, provider_code, external_id, config, created_at into v_row;
        perform platform.log_audit('device_integration_map.created', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_device_map' then
        v_tid := platform.current_tenant_id();
        update public.device_integration_map dim set
            external_id = case when p_payload ? 'external_id' then p_payload->>'external_id' else dim.external_id end,
            config = case when p_payload ? 'config' then p_payload->'config' else dim.config end
        where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid
        returning dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at into v_row;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.updated', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_device_map' then
        v_tid := platform.current_tenant_id();
        delete from public.device_integration_map dim where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.deleted', 'device_integration_map', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

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
        raise exception 'unknown integrations_api operation: %', p_op;
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

revoke all on function public.integrations_domain(text, jsonb) from public;
grant execute on function public.integrations_domain(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_domain(text, jsonb) from public;
grant execute on function public.auth_domain(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;
