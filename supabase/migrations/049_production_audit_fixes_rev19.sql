-- =====================================================
-- 049_production_audit_fixes_rev19.sql
-- Minimal fixes: C1, C2, H1, H2, H4, H5, H6, M1
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('049_production_audit_fixes_rev19', 'REV19.SECURITY.AUDIT.FIXES', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- C1: auth_invite_member — admin gate + revoke direct authenticated execute
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
    perform public.edge_require_admin();
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

revoke all on function public.auth_invite_member(jsonb) from public, authenticated;
grant execute on function public.auth_invite_member(jsonb) to service_role;


-- -----------------------------------------------------
-- C2: booking_create_booking_access — tenant ownership on manual path + revoke direct execute
-- -----------------------------------------------------

create or replace function public.booking_create_booking_access(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_row record;
begin
    perform public.edge_require_manager();
    p_payload := coalesce(p_payload, '{}'::jsonb);

    if not (p_payload ? 'valid_from') or not (p_payload ? 'valid_until') then
        return public.booking_generate_booking_access((p_payload->>'booking_id')::uuid);
    end if;

    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    if not exists (
        select 1
        from public.bookings b
        where b.id = (p_payload->>'booking_id')::uuid
          and b.tenant_id = v_tid
    ) then
        raise exception 'booking not found';
    end if;

    insert into public.booking_access (
        tenant_id,
        booking_id,
        access_type,
        valid_from,
        valid_until
    )
    values (
        v_tid,
        (p_payload->>'booking_id')::uuid,
        'guest'::public.access_type,
        (p_payload->>'valid_from')::timestamptz,
        (p_payload->>'valid_until')::timestamptz
    )
    returning
        id,
        tenant_id,
        booking_id,
        access_type,
        valid_from,
        valid_until,
        created_at,
        updated_at
    into v_row;

    perform platform.log_audit(
        'booking_access.created',
        'booking_access',
        v_row.id,
        p_payload
    );

    return to_jsonb(v_row);
end;
$$;

revoke all on function public.booking_create_booking_access(jsonb) from public, authenticated;
grant execute on function public.booking_create_booking_access(jsonb) to service_role;


-- -----------------------------------------------------
-- H6: monetization_api — align upsell campaign mutation guards with domain
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
             'list_upsell_campaigns', 'get_upsell_campaign',
             'list_activation_state', 'list_conversion_events', 'list_conversion_scores' then
            perform public.edge_require_tenant();
        when 'create_proposal', 'update_proposal', 'delete_proposal', 'create_proposal_item', 'update_proposal_item',
             'delete_proposal_item' then
            perform public.edge_require_manager();
        when 'create_package', 'update_package', 'delete_package' then
            if not platform.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;
        when 'create_upsell_campaign', 'update_upsell_campaign', 'delete_upsell_campaign' then
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
-- H1, H2, H4, H5, M1: revoke direct authenticated execute on standalone RPCs
-- -----------------------------------------------------

revoke all on function public.commerce_change_subscription_plan(uuid) from public, authenticated;
grant execute on function public.commerce_change_subscription_plan(uuid) to service_role;

revoke all on function public.commerce_create_subscription(uuid, public.subscription_tier) from public, authenticated;
grant execute on function public.commerce_create_subscription(uuid, public.subscription_tier) to service_role;

revoke all on function public.automation_dispatch_event(text, jsonb) from public, authenticated;
grant execute on function public.automation_dispatch_event(text, jsonb) to service_role;

revoke all on function public.automation_start_run(uuid, public.automation_trigger_type, jsonb) from public, authenticated;
grant execute on function public.automation_start_run(uuid, public.automation_trigger_type, jsonb) to service_role;

revoke all on function public.automation_cancel_run(uuid) from public, authenticated;
grant execute on function public.automation_cancel_run(uuid) to service_role;

revoke all on function public.automation_enqueue_notification(jsonb) from public, authenticated;
grant execute on function public.automation_enqueue_notification(jsonb) to service_role;

revoke all on function public.integrations_start_oauth(jsonb) from public, authenticated;
grant execute on function public.integrations_start_oauth(jsonb) to service_role;

revoke all on function public.insert_event(text, jsonb, text, uuid, uuid) from public, authenticated;
grant execute on function public.insert_event(text, jsonb, text, uuid, uuid) to service_role;
