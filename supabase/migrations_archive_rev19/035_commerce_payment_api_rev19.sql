-- =====================================================
-- 035 COMMERCE PAYMENT API (009 SSOT)
-- Checkout session creation + payment reads. Execution state in 000 platform tables.
-- Workers confirm via platform.apply_payment_status (000).
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('035_commerce_payment_api_rev19', 'REV19.DOMAIN.COMMERCE.PAYMENT', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. PAYMENT STATUS TRANSITION (009 → 000 bridge)
-- =====================================================

create or replace function public.payment_transition_status(
    p_intent_id uuid,
    p_new_status public.payment_status,
    p_source text,
    p_event_type text default 'status_changed',
    p_external_event_id text default null,
    p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    if not exists (
        select 1 from platform.payment_intents pi
        where pi.id = p_intent_id and pi.tenant_id = v_tid
    ) then
        raise exception 'Payment not found';
    end if;

    perform platform.apply_payment_status(
        p_intent_id,
        p_new_status::text,
        p_source,
        p_event_type,
        p_external_event_id,
        coalesce(p_metadata, '{}'::jsonb)
    );
end;
$$;

revoke all on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) from public;
grant execute on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) to authenticated, service_role;

-- =====================================================
-- 2. PAYMENT DOMAIN (009 Commerce — checkout orchestration)
-- =====================================================

create or replace function public.payment_domain(
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
    v_intent_id uuid;
    v_status public.payment_status;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_tid := platform.current_tenant_id();

    case p_op
    when 'create_checkout_session' then
        if v_tid is null then raise exception 'no active tenant'; end if;

        if not exists (
            select 1 from public.integration_providers ip
            where ip.code = p_payload->>'provider' and ip.is_active = true
        ) then
            raise exception 'Unknown or inactive payment provider: %', p_payload->>'provider';
        end if;

        if (p_payload->>'amount')::numeric <= 0 then
            raise exception 'amount must be positive';
        end if;

        insert into platform.payment_intents (
            tenant_id,
            provider,
            amount,
            currency,
            status,
            target_type,
            target_id,
            metadata
        )
        values (
            v_tid,
            p_payload->>'provider',
            (p_payload->>'amount')::numeric,
            upper(coalesce(p_payload->>'currency', 'EUR')),
            'pending'::public.payment_status,
            p_payload->>'target_type',
            (p_payload->>'target_id')::uuid,
            coalesce(p_payload->'metadata', '{}'::jsonb)
        )
        returning id, tenant_id, provider, external_intent_id, amount, currency,
                  status, target_type, target_id, metadata, created_at, updated_at
        into v_row;

        insert into platform.payment_events (
            payment_intent_id, tenant_id, event_type, old_status, new_status, source, payload
        )
        values (
            v_row.id, v_tid, 'intent_created', null, 'pending', 'api',
            jsonb_build_object('target_type', v_row.target_type, 'target_id', v_row.target_id)
        );

        perform platform.log_audit(
            'payment.checkout_created',
            'payment_intent',
            v_row.id,
            jsonb_build_object('provider', v_row.provider, 'amount', v_row.amount)
        );

        v_result := to_jsonb(v_row);

    when 'get_payment' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select to_jsonb(t) into v_result from (
            select pi.id, pi.tenant_id, pi.provider, pi.external_intent_id, pi.amount,
                   pi.currency, pi.status, pi.target_type, pi.target_id, pi.metadata,
                   pi.created_at, pi.updated_at
            from platform.payment_intents pi
            where pi.id = (p_payload->>'id')::uuid and pi.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Payment not found'; end if;

    when 'list_payments' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select pi.id, pi.tenant_id, pi.provider, pi.external_intent_id, pi.amount,
                   pi.currency, pi.status, pi.target_type, pi.target_id, pi.created_at, pi.updated_at
            from platform.payment_intents pi
            where pi.tenant_id = v_tid
              and (p_payload->>'status' is null or pi.status::text = p_payload->>'status')
              and (p_payload->>'target_type' is null or pi.target_type = p_payload->>'target_type')
              and (p_payload->>'target_id' is null or pi.target_id = (p_payload->>'target_id')::uuid)
        ) t;

    when 'cancel_payment' then
        if v_tid is null then raise exception 'no active tenant'; end if;

        select pi.id, pi.status into v_intent_id, v_status
        from platform.payment_intents pi
        where pi.id = (p_payload->>'id')::uuid and pi.tenant_id = v_tid
        for update;

        if not found then raise exception 'Payment not found'; end if;

        if v_status not in ('pending'::public.payment_status, 'authorized'::public.payment_status) then
            raise exception 'Payment cannot be cancelled in status %', v_status;
        end if;

        perform public.payment_transition_status(
            v_intent_id,
            'cancelled'::public.payment_status,
            'api',
            'cancelled',
            null,
            coalesce(p_payload->'metadata', '{}'::jsonb)
        );

        select to_jsonb(t) into v_result from (
            select pi.id, pi.tenant_id, pi.provider, pi.status, pi.updated_at
            from platform.payment_intents pi where pi.id = v_intent_id
        ) t;

        perform platform.log_audit('payment.cancelled', 'payment_intent', v_intent_id);

    when 'payment_history' then
        if v_tid is null then raise exception 'no active tenant'; end if;

        if not exists (
            select 1 from platform.payment_intents pi
            where pi.id = (p_payload->>'payment_intent_id')::uuid and pi.tenant_id = v_tid
        ) then
            raise exception 'Payment not found';
        end if;

        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select pe.id, pe.payment_intent_id, pe.event_type, pe.old_status, pe.new_status,
                   pe.source, pe.external_event_id, pe.payload, pe.created_at
            from platform.payment_events pe
            where pe.payment_intent_id = (p_payload->>'payment_intent_id')::uuid
              and pe.tenant_id = v_tid
        ) t;

    else
        raise exception 'unknown payment_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.payment_domain(text, jsonb) from public;
grant execute on function public.payment_domain(text, jsonb) to authenticated, service_role;

-- =====================================================
-- 2. PAYMENT API (017 Edge wrapper)
-- =====================================================

create or replace function public.payment_api(
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
        when 'get_payment', 'list_payments', 'payment_history' then
            perform public.edge_require_tenant();
        when 'create_checkout_session' then
            perform public.edge_require_tenant();
        when 'cancel_payment' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown payment_api operation: %', p_op;
    end case;

    return public.payment_domain(p_op, p_payload);
end;
$$;

revoke all on function public.payment_api(text, jsonb) from public;
grant execute on function public.payment_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 035 COMMERCE PAYMENT API
-- =====================================================
