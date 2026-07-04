-- 039 Edge stabilization routing (017/002/005) — additive API ops only; no domain logic changes.

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('039_edge_stabilization_routing_rev19', 'REV19.EDGE.STABILIZATION', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- auth: switch_tenant (JWT app_metadata SSOT in SQL)
-- -----------------------------------------------------

create or replace function public.auth_switch_tenant(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid;
    v_target_tid uuid;
    v_role text;
    v_tenant_status text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := auth.uid();
    if v_uid is null then
        raise exception 'authentication required';
    end if;
    if p_payload->>'tenant_id' is null then
        raise exception 'tenant_id is required';
    end if;

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

    if v_role is null then
        raise exception 'No active membership for tenant';
    end if;
    if v_tenant_status in ('suspended', 'deleted') then
        raise exception 'Tenant is not available';
    end if;

    update auth.users
    set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object('tenant_id', v_target_tid::text)
    where id = v_uid;

    return jsonb_build_object(
        'tenant_id', v_target_tid,
        'role', v_role,
        'tenant_status', v_tenant_status
    );
end;
$$;

revoke all on function public.auth_switch_tenant(jsonb) from public;
grant execute on function public.auth_switch_tenant(jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- auth: invite_member by email (resolve user_id in SQL)
-- -----------------------------------------------------

create or replace function public.auth_invite_member(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_uid uuid;
    v_payload jsonb;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_payload := p_payload;

    if v_payload->>'user_id' is null then
        if v_payload->>'email' is null then
            raise exception 'email or user_id is required';
        end if;
        select p.id into v_uid
        from platform.profiles p
        where lower(p.email) = lower(v_payload->>'email')
        limit 1;
        if v_uid is null then
            raise exception 'User not found for email. User must register before invite.';
        end if;
        v_payload := v_payload || jsonb_build_object('user_id', v_uid::text);
    end if;

    return public.auth_domain('invite_member', v_payload);
end;
$$;

revoke all on function public.auth_invite_member(jsonb) from public;
grant execute on function public.auth_invite_member(jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- integrations: oauth_complete (state resolve + credential storage SSOT)
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
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
        raise exception 'state_token is required';
    end if;

    v_resolved := public.integrations_resolve_oauth_state(p_payload->>'state_token');
    v_tenant_id := (v_resolved->>'tenant_id')::uuid;
    v_provider_code := v_resolved->>'provider_code';

    return public.integrations_complete_oauth(
        v_tenant_id,
        v_provider_code,
        format('integrations/%s/%s', v_tenant_id, v_provider_code),
        p_payload->>'state_token'
    );
end;
$$;

revoke all on function public.integrations_oauth_complete_api(jsonb) from public;
grant execute on function public.integrations_oauth_complete_api(jsonb) to service_role;

-- -----------------------------------------------------
-- auth_api / integrations_api routing extensions
-- -----------------------------------------------------

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
        when 'switch_tenant' then
            return public.auth_switch_tenant(p_payload);
        when 'invite_member' then
            perform public.edge_require_tenant();
            perform public.edge_require_admin();
            return public.auth_invite_member(p_payload);
        when 'get_auth_context', 'list_user_tenants', 'create_tenant', 'validate_tenant_switch' then
            null;
        when 'resolve_user_by_email' then
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

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- platform: thin batch processors (000 execution SSOT)
-- -----------------------------------------------------

create or replace function platform.process_integration_queue_batch(
    p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item record;
    v_processed int := 0;
    v_succeeded int := 0;
    v_failed int := 0;
    v_url text;
begin
    perform platform.process_integration_queue();

    for v_item in select * from platform.fetch_integration_queue_batch(p_limit)
    loop
        v_processed := v_processed + 1;
        begin
            v_url := v_item.payload->>'url';
            if v_url is null then
                raise exception 'integration queue item missing payload.url';
            end if;
            perform platform.dispatch_http_request(
                v_url,
                coalesce(v_item.payload->>'method', 'POST'),
                coalesce(v_item.payload->'headers', '{}'::jsonb),
                coalesce(v_item.payload->'body', v_item.payload),
                coalesce((v_item.payload->>'timeout_ms')::int, 5000)
            );
            perform platform.mark_integration_queue_item(v_item.id, 'sent', null);
            v_succeeded := v_succeeded + 1;
        exception when others then
            perform platform.mark_integration_queue_item(
                v_item.id,
                'failed',
                jsonb_build_object('message', sqlerrm)
            );
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'succeeded', v_succeeded,
        'failed', v_failed
    );
end;
$$;

create or replace function platform.process_device_command_batch(
    p_limit int default 50,
    p_worker_id text default 'edge-worker'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_cmd platform.device_commands;
    v_processed int := 0;
    v_succeeded int := 0;
    v_failed int := 0;
    v_ctx jsonb;
    v_url text;
    v_secret text;
begin
    loop
        exit when v_processed >= greatest(p_limit, 1);

        select * into v_cmd from platform.fetch_next_command() limit 1;
        if not found then
            exit;
        end if;

        v_processed := v_processed + 1;
        begin
            v_ctx := platform.get_device_command_context(v_cmd.device_id, v_cmd.tenant_id);
            v_url := v_cmd.payload->>'url';
            if v_url is null and v_ctx is not null then
                v_url := v_ctx->>'dispatch_url';
            end if;
            if v_url is null then
                raise exception 'device command missing dispatch url';
            end if;
            if v_ctx is not null and v_ctx->>'credentials_ref' is not null then
                v_secret := platform.get_vault_secret(v_ctx->>'credentials_ref');
            end if;
            perform platform.dispatch_http_request(
                v_url,
                coalesce(v_cmd.payload->>'method', 'POST'),
                coalesce(v_cmd.payload->'headers', '{}'::jsonb)
                    || case when v_secret is not null
                        then jsonb_build_object('Authorization', 'Bearer ' || v_secret)
                        else '{}'::jsonb end,
                coalesce(v_cmd.payload->'body', v_cmd.payload),
                coalesce((v_cmd.payload->>'timeout_ms')::int, 5000)
            );
            perform platform.update_device_command_status(
                v_cmd.id, 'success', p_worker_id, jsonb_build_object('dispatched', true), null
            );
            v_succeeded := v_succeeded + 1;
        exception when others then
            if v_cmd.retry_count < v_cmd.max_retries then
                perform platform.update_device_command_status(
                    v_cmd.id, 'retrying', p_worker_id, null,
                    jsonb_build_object('message', sqlerrm)
                );
            else
                perform platform.move_to_dlq(v_cmd.id, 'max_retries_exceeded',
                    jsonb_build_object('message', sqlerrm));
            end if;
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'succeeded', v_succeeded,
        'failed', v_failed
    );
end;
$$;

create or replace function platform.process_retry_task_batch(
    p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_task record;
    v_processed int := 0;
    v_succeeded int := 0;
    v_failed int := 0;
    v_url text;
begin
    perform platform.process_retry_tasks();

    for v_task in select * from platform.fetch_retry_task_batch(p_limit)
    loop
        v_processed := v_processed + 1;
        begin
            v_url := v_task.payload->>'url';
            if v_url is null then
                raise exception 'retry task missing payload.url';
            end if;
            perform platform.dispatch_http_request(
                v_url,
                coalesce(v_task.payload->>'method', 'POST'),
                coalesce(v_task.payload->'headers', '{}'::jsonb),
                coalesce(v_task.payload->'body', v_task.payload),
                coalesce((v_task.payload->>'timeout_ms')::int, 5000)
            );
            perform platform.mark_retry_task(v_task.id, 'done', v_task.attempt + 1, null);
            v_succeeded := v_succeeded + 1;
        exception when others then
            if v_task.attempt + 1 >= v_task.max_attempts then
                perform platform.mark_retry_task(v_task.id, 'failed', v_task.attempt + 1, sqlerrm);
            else
                perform platform.mark_retry_task(v_task.id, 'queued', v_task.attempt + 1, sqlerrm);
            end if;
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'succeeded', v_succeeded,
        'failed', v_failed
    );
end;
$$;

create or replace function platform.process_shipment_dispatch_batch(
    p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item record;
    v_processed int := 0;
    v_succeeded int := 0;
    v_failed int := 0;
    v_url text;
    v_tracking text;
    v_label_ref text;
begin
    perform platform.process_shipment_dispatch_queue();

    for v_item in select * from platform.fetch_shipment_dispatch_batch(p_limit)
    loop
        v_processed := v_processed + 1;
        begin
            v_url := v_item.payload->>'url';
            if v_url is not null then
                perform platform.dispatch_http_request(
                    v_url,
                    coalesce(v_item.payload->>'method', 'POST'),
                    coalesce(v_item.payload->'headers', '{}'::jsonb),
                    coalesce(v_item.payload->'body', v_item.payload),
                    coalesce((v_item.payload->>'timeout_ms')::int, 5000)
                );
            end if;
            v_tracking := coalesce(v_item.payload->>'tracking_number', v_item.payload->>'tracking');
            v_label_ref := v_item.payload->>'label_artifact_ref';
            perform platform.mark_shipment_dispatched(v_item.id, v_tracking, v_label_ref);
            v_succeeded := v_succeeded + 1;
        exception when others then
            perform platform.mark_shipment_dispatch_failed(
                v_item.id,
                jsonb_build_object('message', sqlerrm),
                v_item.retry_count,
                v_item.max_retries
            );
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'succeeded', v_succeeded,
        'failed', v_failed
    );
end;
$$;

create or replace function platform.process_notification_batch(
    p_limit int default 50
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_item record;
    v_processed int := 0;
    v_succeeded int := 0;
    v_failed int := 0;
    v_url text;
begin
    for v_item in select * from platform.fetch_notification_batch(p_limit)
    loop
        v_processed := v_processed + 1;
        begin
            v_url := v_item.payload->>'url';
            if v_url is null then
                raise exception 'notification item missing payload.url for platform dispatch';
            end if;
            perform platform.dispatch_http_request(
                v_url,
                coalesce(v_item.payload->>'method', 'POST'),
                coalesce(v_item.payload->'headers', '{}'::jsonb),
                coalesce(v_item.payload->'body', v_item.payload),
                coalesce((v_item.payload->>'timeout_ms')::int, 5000)
            );
            perform platform.complete_notification_delivery(v_item.id, true, null);
            v_succeeded := v_succeeded + 1;
        exception when others then
            perform platform.complete_notification_delivery(
                v_item.id, false, jsonb_build_object('message', sqlerrm)
            );
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'succeeded', v_succeeded,
        'failed', v_failed
    );
end;
$$;

revoke all on function platform.process_integration_queue_batch(int) from public, authenticated;
revoke all on function platform.process_device_command_batch(int, text) from public, authenticated;
revoke all on function platform.process_retry_task_batch(int) from public, authenticated;
revoke all on function platform.process_shipment_dispatch_batch(int) from public, authenticated;
revoke all on function platform.process_notification_batch(int) from public, authenticated;

grant execute on function platform.process_integration_queue_batch(int) to service_role;
grant execute on function platform.process_device_command_batch(int, text) to service_role;
grant execute on function platform.process_retry_task_batch(int) to service_role;
grant execute on function platform.process_shipment_dispatch_batch(int) to service_role;
grant execute on function platform.process_notification_batch(int) to service_role;

-- -----------------------------------------------------
-- platform: cron tick — watchdog only (queue batch owned by Edge jobs)
-- -----------------------------------------------------

create or replace function platform.run_platform_cron_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_lock_key bigint := 190014001;
    v_started timestamptz := clock_timestamp();
    v_elapsed_ms int;
begin
    if not pg_try_advisory_lock(v_lock_key) then
        return;
    end if;

    begin
        perform platform.bind_operation_context_type_column();
        perform platform.execution_watchdog();

        v_elapsed_ms := (extract(epoch from (clock_timestamp() - v_started)) * 1000)::int;

        perform platform.record_queue_metrics(
            'platform_cron_tick',
            0,
            0,
            v_elapsed_ms,
            'ok'
        );
    exception
        when others then
            perform pg_advisory_unlock(v_lock_key);
            raise;
    end;

    perform pg_advisory_unlock(v_lock_key);
end;
$$;

revoke all on function platform.run_platform_cron_tick() from public, authenticated;
grant execute on function platform.run_platform_cron_tick() to service_role;
