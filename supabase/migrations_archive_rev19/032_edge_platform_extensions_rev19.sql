-- 000 Platform + 002 Auth + 005 Integrations extensions (Edge REV19 compliance)

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('032_edge_platform_extensions_rev19', 'REV19.EDGE.PLATFORM.EXT', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- 000 Platform: vault write + worker batch RPCs + device context
-- -----------------------------------------------------

create or replace function platform.create_vault_secret(
    p_secret text,
    p_name text,
    p_description text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_secret is null or p_name is null then
        raise exception 'secret and name are required';
    end if;

    if not exists (select 1 from pg_extension where extname = 'vault') then
        raise exception 'vault extension not available';
    end if;

    perform vault.create_secret(p_secret, p_name, coalesce(p_description, p_name));
end;
$$;

create or replace function platform.get_device_command_context(
    p_device_id uuid,
    p_tenant_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_result jsonb;
begin
    select jsonb_build_object(
        'provider_code', dim.provider_code,
        'external_device_id', dim.external_id,
        'credentials_ref', ti.credentials_ref,
        'config', ti.config
    ) into v_result
    from public.device_integration_map dim
    join public.tenant_integrations ti
      on ti.tenant_id = dim.tenant_id
     and ti.provider_code = dim.provider_code
     and ti.is_enabled = true
    where dim.device_id = p_device_id
      and dim.tenant_id = p_tenant_id
    limit 1;

    return v_result;
end;
$$;

create or replace function platform.fetch_integration_queue_batch(p_limit int default 50)
returns table (
    id uuid,
    tenant_id uuid,
    integration_type text,
    event_type text,
    payload jsonb,
    status text,
    retry_count int,
    max_retries int,
    next_retry_at timestamptz,
    last_error jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    select
        iq.id,
        iq.tenant_id,
        iq.integration_type,
        iq.event_type,
        iq.payload,
        iq.status,
        iq.retry_count,
        iq.max_retries,
        iq.next_retry_at,
        iq.last_error
    from platform.integration_queue iq
    where iq.status in ('pending', 'retrying')
      and (iq.next_retry_at is null or iq.next_retry_at <= now())
    order by iq.created_at
    limit p_limit
    for update skip locked;
end;
$$;

create or replace function platform.mark_integration_queue_item(
    p_id uuid,
    p_status text,
    p_last_error jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update platform.integration_queue
    set status = p_status,
        last_error = p_last_error,
        delivered_at = case when p_status = 'sent' then now() else delivered_at end
    where id = p_id;
end;
$$;

create or replace function platform.fetch_retry_task_batch(p_limit int default 50)
returns table (
    id uuid,
    tenant_id uuid,
    handler text,
    target_type text,
    target_id uuid,
    attempt int,
    max_attempts int,
    next_retry_at timestamptz,
    status text,
    last_error text,
    payload jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    select
        rt.id,
        rt.tenant_id,
        rt.handler,
        rt.target_type,
        rt.target_id,
        rt.attempt,
        rt.max_attempts,
        rt.next_retry_at,
        rt.status,
        rt.last_error,
        rt.payload
    from platform.retry_tasks rt
    where rt.status = 'queued'
      and (rt.next_retry_at is null or rt.next_retry_at <= now())
    order by rt.created_at
    limit p_limit
    for update skip locked;
end;
$$;

create or replace function platform.mark_retry_task(
    p_id uuid,
    p_status text,
    p_attempt int,
    p_last_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update platform.retry_tasks
    set status = p_status,
        attempt = p_attempt,
        last_error = p_last_error
    where id = p_id;
end;
$$;

create or replace function platform.fetch_shipment_dispatch_batch(p_limit int default 50)
returns table (
    id uuid,
    tenant_id uuid,
    fulfilment_order_id uuid,
    status text,
    payload jsonb,
    retry_count int,
    max_retries int
)
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    select
        sd.id,
        sd.tenant_id,
        sd.fulfilment_order_id,
        sd.status,
        sd.payload,
        sd.retry_count,
        sd.max_retries
    from platform.shipment_dispatch_queue sd
    where sd.status in ('pending', 'retrying')
    order by sd.created_at
    limit p_limit
    for update skip locked;
end;
$$;

create or replace function platform.mark_shipment_dispatched(
    p_id uuid,
    p_tracking_number text default null,
    p_label_ref text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update platform.shipment_dispatch_queue
    set status = 'dispatched',
        tracking_number = coalesce(p_tracking_number, tracking_number),
        label_artifact_ref = coalesce(p_label_ref, label_artifact_ref),
        dispatched_at = now(),
        updated_at = now()
    where id = p_id;
end;
$$;

create or replace function platform.mark_shipment_dispatch_failed(
    p_id uuid,
    p_error jsonb,
    p_retry_count int,
    p_max_retries int
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_retry_count + 1 >= p_max_retries then
        update platform.shipment_dispatch_queue
        set status = 'dead_letter',
            retry_count = p_retry_count + 1,
            last_error = p_error,
            updated_at = now()
        where id = p_id;
    else
        update platform.shipment_dispatch_queue
        set status = 'retrying',
            retry_count = p_retry_count + 1,
            last_error = p_error,
            updated_at = now()
        where id = p_id;
    end if;
end;
$$;

revoke all on function platform.create_vault_secret(text, text, text) from public, authenticated;
revoke all on function platform.get_device_command_context(uuid, uuid) from public, authenticated;
revoke all on function platform.fetch_integration_queue_batch(int) from public, authenticated;
revoke all on function platform.mark_integration_queue_item(uuid, text, jsonb) from public, authenticated;
revoke all on function platform.fetch_retry_task_batch(int) from public, authenticated;
revoke all on function platform.mark_retry_task(uuid, text, int, text) from public, authenticated;
revoke all on function platform.fetch_shipment_dispatch_batch(int) from public, authenticated;
revoke all on function platform.mark_shipment_dispatched(uuid, text, text) from public, authenticated;
revoke all on function platform.mark_shipment_dispatch_failed(uuid, jsonb, int, int) from public, authenticated;

grant execute on function platform.create_vault_secret(text, text, text) to service_role;
grant execute on function platform.get_device_command_context(uuid, uuid) to service_role;
grant execute on function platform.fetch_integration_queue_batch(int) to service_role;
grant execute on function platform.mark_integration_queue_item(uuid, text, jsonb) to service_role;
grant execute on function platform.fetch_retry_task_batch(int) to service_role;
grant execute on function platform.mark_retry_task(uuid, text, int, text) to service_role;
grant execute on function platform.fetch_shipment_dispatch_batch(int) to service_role;
grant execute on function platform.mark_shipment_dispatched(uuid, text, text) to service_role;
grant execute on function platform.mark_shipment_dispatch_failed(uuid, jsonb, int, int) to service_role;

-- -----------------------------------------------------
-- 005 Integrations: OAuth state SSOT
-- -----------------------------------------------------

create table if not exists public.integration_oauth_states (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants(id),
    user_id uuid not null,
    provider_code text not null,
    state_token text not null,
    expires_at timestamptz not null,
    consumed_at timestamptz,
    created_at timestamptz not null default now(),
    constraint integration_oauth_states_state_token_key unique (state_token)
);

create index if not exists integration_oauth_states_pending_idx
    on public.integration_oauth_states (expires_at)
    where consumed_at is null;

alter table public.integration_oauth_states enable row level security;

revoke all on public.integration_oauth_states from public, authenticated;
grant select, insert, update on public.integration_oauth_states to service_role;

create or replace function public.integrations_resolve_oauth_state(p_state_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.integration_oauth_states;
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

    return jsonb_build_object(
        'tenant_id', v_row.tenant_id,
        'provider_code', v_row.provider_code,
        'user_id', v_row.user_id
    );
end;
$$;

drop function if exists public.integrations_complete_oauth(uuid, text, text);
drop function if exists public.integrations_oauth_complete(uuid, text, text);

create or replace function public.integrations_complete_oauth(
    p_tenant_id uuid,
    p_provider_code text,
    p_credentials_ref text,
    p_state_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.tenant_integrations;
    v_state public.integration_oauth_states;
begin
    if p_tenant_id is null or p_provider_code is null or p_credentials_ref is null then
        raise exception 'tenant_id, provider_code, and credentials_ref are required';
    end if;

    if p_state_token is null or length(trim(p_state_token)) = 0 then
        raise exception 'OAuth state token is required';
    end if;

    select * into v_state
    from public.integration_oauth_states s
    where s.state_token = p_state_token
      and s.consumed_at is null
      and s.expires_at > now()
      and s.tenant_id = p_tenant_id
      and s.provider_code = p_provider_code
    for update;

    if not found then
        raise exception 'Invalid OAuth state for tenant/provider';
    end if;

    if not exists (
        select 1 from public.integration_providers ip where ip.code = p_provider_code
    ) then
        raise exception 'Integration provider not found';
    end if;

    update public.integration_oauth_states
    set consumed_at = now()
    where id = v_state.id;

    insert into public.tenant_integrations (
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled
    )
    values (
        p_tenant_id,
        p_provider_code,
        p_credentials_ref,
        '{}'::jsonb,
        true
    )
    on conflict (tenant_id, provider_code) do update
        set credentials_ref = excluded.credentials_ref,
            is_enabled = true,
            updated_at = now()
    returning
        id,
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled,
        created_at,
        updated_at
    into v_row;

    perform platform.log_audit(
        'integration.oauth_completed',
        'tenant_integration',
        v_row.id,
        jsonb_build_object('provider_code', p_provider_code)
    );

    return to_jsonb(v_row);
end;
$$;

create or replace function public.integrations_oauth_complete(
    p_tenant_id uuid,
    p_provider_code text,
    p_credentials_ref text,
    p_state_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    return public.integrations_complete_oauth(
        p_tenant_id,
        p_provider_code,
        p_credentials_ref,
        p_state_token
    );
end;
$$;

revoke all on function public.integrations_resolve_oauth_state(text) from public;
revoke all on function public.integrations_complete_oauth(uuid, text, text, text) from public;
revoke all on function public.integrations_oauth_complete(uuid, text, text, text) from public;

grant execute on function public.integrations_resolve_oauth_state(text) to service_role;
grant execute on function public.integrations_complete_oauth(uuid, text, text, text) to service_role;
grant execute on function public.integrations_oauth_complete(uuid, text, text, text) to service_role;
