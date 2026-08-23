-- =====================================================
-- 040 INTEGRATIONS OAUTH START (005 SSOT)
-- Moves OAuth authorize URL construction from Edge into SQL.
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('040_integrations_oauth_start_rev19', 'REV19.INTEGRATIONS.OAUTH.START', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- 005: URL encode helper for OAuth query parameters
-- -----------------------------------------------------

create or replace function public.integrations_oauth_url_encode(p_value text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
    v_bytes bytea;
    v_result text := '';
    v_i int;
    v_byte int;
begin
    if p_value is null then
        return '';
    end if;

    v_bytes := convert_to(p_value, 'UTF8');
    for v_i in 0..(length(v_bytes) - 1) loop
        v_byte := get_byte(v_bytes, v_i);
        if (v_byte >= 48 and v_byte <= 57)
           or (v_byte >= 65 and v_byte <= 90)
           or (v_byte >= 97 and v_byte <= 122)
           or v_byte in (45, 46, 95, 126) then
            v_result := v_result || chr(v_byte);
        else
            v_result := v_result || '%' || upper(to_hex(v_byte));
        end if;
    end loop;

    return v_result;
end;
$$;

revoke all on function public.integrations_oauth_url_encode(text) from public;
grant execute on function public.integrations_oauth_url_encode(text) to authenticated, service_role;

-- -----------------------------------------------------
-- 005: OAuth start (state registration + authorize URL)
-- Vault secrets: supabase_url, stripe_connect_client_id,
-- oauth_authorize_url_{provider_code}
-- -----------------------------------------------------

create or replace function public.integrations_start_oauth(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_uid uuid;
    v_provider_code text;
    v_state_token text;
    v_expires_at timestamptz;
    v_redirect_uri text;
    v_supabase_url text;
    v_authorize_url text;
    v_base_url text;
    v_client_id text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_tid := platform.current_tenant_id();
    v_uid := auth.uid();

    if p_payload->>'provider_code' is null then
        raise exception 'provider_code is required';
    end if;

    v_provider_code := lower(trim(p_payload->>'provider_code'));

    if not exists (
        select 1 from public.integration_providers ip
        where ip.code = v_provider_code
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
        v_tid, v_uid, v_provider_code, v_state_token, v_expires_at
    );

    v_supabase_url := platform.get_vault_secret('supabase_url');
    if v_supabase_url is null then
        raise exception 'supabase_url not configured in vault';
    end if;

    v_redirect_uri := coalesce(
        nullif(trim(p_payload->>'redirect_uri'), ''),
        rtrim(v_supabase_url, '/') || '/functions/v1/integrations/oauth-callback'
    );

    if v_provider_code = 'stripe' then
        v_client_id := platform.get_vault_secret('stripe_connect_client_id');
        if v_client_id is null then
            raise exception 'stripe_connect_client_id not configured in vault';
        end if;

        v_authorize_url :=
            'https://connect.stripe.com/oauth/authorize?' ||
            'response_type=code&' ||
            'client_id=' || public.integrations_oauth_url_encode(v_client_id) || '&' ||
            'scope=read_write&' ||
            'state=' || public.integrations_oauth_url_encode(v_state_token) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);
    else
        v_base_url := platform.get_vault_secret('oauth_authorize_url_' || v_provider_code);
        if v_base_url is null then
            raise exception 'OAuth authorize URL not configured for %', v_provider_code;
        end if;

        v_authorize_url :=
            v_base_url || '?' ||
            'state=' || public.integrations_oauth_url_encode(v_state_token) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);
    end if;

    return jsonb_build_object(
        'authorize_url', v_authorize_url,
        'state', v_state_token,
        'provider_code', v_provider_code
    );
end;
$$;

revoke all on function public.integrations_start_oauth(jsonb) from public;
grant execute on function public.integrations_start_oauth(jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- 005: extend integrations_domain_ext with start_oauth
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
    when 'start_oauth' then
        return public.integrations_start_oauth(p_payload);

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

-- -----------------------------------------------------
-- integrations_api: route start_oauth
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
        when 'list_providers', 'get_provider', 'list_capabilities', 'list_tenant_integrations', 'get_tenant_integration', 'list_webhook_definitions', 'list_device_maps' then
            perform public.edge_require_tenant();
        when 'connect_integration', 'update_integration', 'disconnect_integration', 'create_webhook_definition', 'update_webhook_definition', 'delete_webhook_definition', 'create_device_map', 'update_device_map', 'delete_device_map', 'register_oauth_state', 'start_oauth', 'request_sync' then
            perform public.edge_require_manager();
        when 'resolve_oauth_state', 'complete_oauth' then
            null;
        else
            raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return public.integrations_domain(p_op, p_payload);
end;
$$;

revoke all on function public.integrations_domain_ext(text, jsonb) from public;
grant execute on function public.integrations_domain_ext(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 040 INTEGRATIONS OAUTH START
-- =====================================================
