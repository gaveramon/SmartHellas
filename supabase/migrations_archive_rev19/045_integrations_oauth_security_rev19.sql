-- =====================================================
-- 045_integrations_oauth_security_rev19.sql
-- 005 Integration Engine — OAuth token exchange + SECURITY DEFINER hardening
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('045_integrations_oauth_security_rev19', 'REV19.SECURITY.INTEGRATIONS', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- 000 Platform: vault upsert + synchronous pg_net HTTP
-- -----------------------------------------------------

create or replace function platform.upsert_vault_secret(
    p_secret text,
    p_name text,
    p_description text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_secret_id uuid;
begin
    if p_secret is null or p_name is null then
        raise exception 'secret and name are required';
    end if;

    if not exists (select 1 from pg_extension where extname = 'vault') then
        raise exception 'vault extension not available';
    end if;

    select s.id
    into v_secret_id
    from vault.secrets s
    where s.name = p_name
    limit 1;

    if v_secret_id is not null then
        perform vault.update_secret(
            v_secret_id,
            p_secret,
            p_name,
            coalesce(p_description, p_name)
        );
    else
        perform vault.create_secret(p_secret, p_name, coalesce(p_description, p_name));
    end if;
end;
$$;

create or replace function platform.sync_http_request(
    p_method text,
    p_url text,
    p_content_type text,
    p_body text,
    p_timeout_ms int default 15000
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_request_id bigint;
    v_method text;
    v_result net.http_response_result;
    v_status_code int;
    v_response_body text;
begin
    if p_url is null or btrim(p_url) = '' then
        raise exception 'url is required';
    end if;

    if not exists (select 1 from pg_extension where extname = 'pg_net') then
        raise exception 'pg_net extension not available';
    end if;

    v_method := upper(coalesce(p_method, 'POST'));

    if v_method = 'GET' then
        select net.http_get(
            url := p_url,
            headers := case
                when p_content_type is not null and btrim(p_content_type) <> ''
                    then jsonb_build_object('Content-Type', p_content_type)
                else '{}'::jsonb
            end,
            timeout_milliseconds := p_timeout_ms
        )
        into v_request_id;
    elsif v_method = 'POST' then
        if coalesce(lower(p_content_type), 'application/json') = 'application/json' then
            select net.http_post(
                url := p_url,
                body := coalesce(p_body, '{}')::jsonb,
                headers := jsonb_build_object('Content-Type', 'application/json'),
                timeout_milliseconds := p_timeout_ms
            )
            into v_request_id;
        else
            insert into net.http_request_queue (method, url, headers, body, timeout_milliseconds)
            values (
                'POST',
                p_url,
                jsonb_build_object(
                    'Content-Type',
                    coalesce(nullif(btrim(p_content_type), ''), 'application/octet-stream')
                ),
                convert_to(coalesce(p_body, ''), 'UTF8'),
                p_timeout_ms
            )
            returning id into v_request_id;

            perform net.wake();
        end if;
    else
        raise exception 'unsupported HTTP method: %', p_method;
    end if;

    select net.http_collect_response(v_request_id, async := false)
    into v_result;

    if v_result.status <> 'SUCCESS'::net.request_status then
        raise exception 'HTTP request failed: %', coalesce(v_result.message, 'unknown error');
    end if;

    v_status_code := (v_result.response).status_code;
    v_response_body := (v_result.response).body;

    return jsonb_build_object(
        'status_code', v_status_code,
        'body', v_response_body
    );
end;
$$;

revoke all on function platform.upsert_vault_secret(text, text, text) from public, authenticated;
revoke all on function platform.sync_http_request(text, text, text, text, int) from public, authenticated;

grant execute on function platform.upsert_vault_secret(text, text, text) to service_role;
grant execute on function platform.sync_http_request(text, text, text, text, int) to service_role;


-- -----------------------------------------------------
-- 005 Integrations: OAuth token exchange (SSOT)
-- -----------------------------------------------------

create or replace function public.integrations_exchange_oauth_tokens(
    p_tenant_id uuid,
    p_provider_code text,
    p_code text,
    p_redirect_uri text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_provider_code text;
    v_credentials_ref text;
    v_redirect_uri text;
    v_supabase_url text;
    v_client_secret text;
    v_client_id text;
    v_token_url text;
    v_form_body text;
    v_http_result jsonb;
    v_status_code int;
    v_response_body text;
begin
    if p_code is null or length(trim(p_code)) = 0 then
        raise exception 'code is required';
    end if;

    if p_tenant_id is null or p_provider_code is null then
        raise exception 'tenant_id and provider_code are required';
    end if;

    v_provider_code := lower(trim(p_provider_code));
    v_credentials_ref := format('integrations/%s/%s', p_tenant_id, v_provider_code);

    if v_provider_code = 'stripe' then
        v_client_secret := platform.get_vault_secret('stripe_connect_client_secret');
        if v_client_secret is null then
            raise exception 'stripe_connect_client_secret not configured in vault';
        end if;

        v_form_body :=
            'grant_type=authorization_code&' ||
            'code=' || public.integrations_oauth_url_encode(p_code) || '&' ||
            'client_secret=' || public.integrations_oauth_url_encode(v_client_secret);

        v_http_result := platform.sync_http_request(
            'POST',
            'https://connect.stripe.com/oauth/token',
            'application/x-www-form-urlencoded',
            v_form_body
        );
    else
        v_token_url := platform.get_vault_secret('oauth_token_url_' || v_provider_code);
        v_client_secret := platform.get_vault_secret('oauth_client_secret_' || v_provider_code);
        v_client_id := platform.get_vault_secret('oauth_client_id_' || v_provider_code);

        if v_token_url is null then
            raise exception 'OAuth token URL not configured for %', v_provider_code;
        end if;
        if v_client_secret is null then
            raise exception 'OAuth client secret not configured for %', v_provider_code;
        end if;
        if v_client_id is null then
            raise exception 'OAuth client id not configured for %', v_provider_code;
        end if;

        v_supabase_url := platform.get_vault_secret('supabase_url');
        if v_supabase_url is null then
            raise exception 'supabase_url not configured in vault';
        end if;

        v_redirect_uri := coalesce(
            nullif(trim(p_redirect_uri), ''),
            rtrim(v_supabase_url, '/') || '/functions/v1/integrations/oauth-callback'
        );

        v_form_body :=
            'grant_type=authorization_code&' ||
            'code=' || public.integrations_oauth_url_encode(p_code) || '&' ||
            'client_id=' || public.integrations_oauth_url_encode(v_client_id) || '&' ||
            'client_secret=' || public.integrations_oauth_url_encode(v_client_secret) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);

        v_http_result := platform.sync_http_request(
            'POST',
            v_token_url,
            'application/x-www-form-urlencoded',
            v_form_body
        );
    end if;

    v_status_code := (v_http_result->>'status_code')::int;
    v_response_body := v_http_result->>'body';

    if v_status_code < 200 or v_status_code >= 300 then
        raise exception 'OAuth token exchange failed (HTTP %): %', v_status_code, v_response_body;
    end if;

    begin
        perform v_response_body::jsonb;
    exception
        when others then
            raise exception 'OAuth token exchange returned invalid JSON: %', v_response_body;
    end;

    perform platform.upsert_vault_secret(
        v_response_body,
        v_credentials_ref,
        format('OAuth credentials for %s tenant %s', v_provider_code, p_tenant_id)
    );

    return v_credentials_ref;
end;
$$;

revoke all on function public.integrations_exchange_oauth_tokens(uuid, text, text, text) from public, authenticated;
grant execute on function public.integrations_exchange_oauth_tokens(uuid, text, text, text) to service_role;


-- -----------------------------------------------------
-- 005 Integrations: OAuth complete API (real token exchange)
-- -----------------------------------------------------

create or replace function public.integrations_oauth_complete_api(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_resolved jsonb;
    v_tenant_id uuid;
    v_provider_code text;
    v_credentials_ref text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
        raise exception 'state_token is required';
    end if;

    if p_payload->>'code' is null or length(trim(p_payload->>'code')) = 0 then
        raise exception 'code is required';
    end if;

    v_resolved := public.integrations_resolve_oauth_state(p_payload->>'state_token');
    v_tenant_id := (v_resolved->>'tenant_id')::uuid;
    v_provider_code := v_resolved->>'provider_code';

    v_credentials_ref := public.integrations_exchange_oauth_tokens(
        v_tenant_id,
        v_provider_code,
        p_payload->>'code',
        p_payload->>'redirect_uri'
    );

    return public.integrations_complete_oauth(
        v_tenant_id,
        v_provider_code,
        v_credentials_ref,
        p_payload->>'state_token'
    );
end;
$$;

revoke all on function public.integrations_oauth_complete_api(jsonb) from public, authenticated;
grant execute on function public.integrations_oauth_complete_api(jsonb) to service_role;


-- -----------------------------------------------------
-- 005 Integrations: domain authorization hardening
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
    v_row record;
    v_result jsonb;
    v_existing uuid;
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
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
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        delete from public.device_integration_map dim where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.deleted', 'device_integration_map', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        return public.integrations_domain_ext(p_op, p_payload);
    end case;

    return v_result;
end;
$$;

-- Direct domain access revoked; callers must use integrations_api (017 Edge layer).
revoke all on function public.integrations_domain(text, jsonb) from public, authenticated;
grant execute on function public.integrations_domain(text, jsonb) to service_role;

revoke all on function public.integrations_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.integrations_domain_ext(text, jsonb) to service_role;


-- =====================================================
-- END 045 INTEGRATIONS OAUTH SECURITY
-- =====================================================
