-- =====================================================
-- 037 PLATFORM WEBHOOK PROCESSING (000 SSOT)
-- Single SQL pipeline: ingest → process → domain handlers.
-- Provider validation remains in Edge; event routing in SQL.
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('037_platform_webhook_processing_rev19', 'REV19.PLATFORM.WEBHOOK.PROCESSING', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. PROCESSING STATE (additive to 000 external_webhooks)
-- =====================================================

alter table platform.external_webhooks
    add column if not exists processing_status text not null default 'pending';

alter table platform.external_webhooks
    add column if not exists processed_at timestamptz;

alter table platform.external_webhooks
    add column if not exists last_error jsonb;

alter table platform.external_webhooks
    add column if not exists retry_count int not null default 0;

alter table platform.external_webhooks
    add constraint chk_external_webhooks_processing_status
    check (processing_status in ('pending', 'processing', 'processed', 'failed', 'skipped'));

create index if not exists idx_external_webhooks_pending
on platform.external_webhooks (processing_status, received_at)
where processing_status in ('pending', 'failed');

-- =====================================================
-- 2. INGEST RETURNS ID (extends 000 pipeline)
-- PostgreSQL 42P13: void → uuid requires drop + create (not replace).
-- =====================================================

drop function if exists platform.ingest_external_webhook(text, text, text, jsonb, uuid, text);

create function platform.ingest_external_webhook(
    p_source text,
    p_external_event_id text,
    p_event_type text,
    p_payload jsonb,
    p_tenant_id uuid default null,
    p_external_account_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant_id uuid;
    v_id uuid;
begin
    v_tenant_id := coalesce(
        p_tenant_id,
        (
            select w.tenant_id
            from platform.webhook_provider_tenant_map w
            where w.source = p_source
              and w.external_account_id = p_external_account_id
        ),
        platform.current_tenant_id()
    );

    insert into platform.external_webhooks (
        source,
        external_event_id,
        event_type,
        tenant_id,
        payload,
        processing_status
    )
    values (
        p_source,
        p_external_event_id,
        p_event_type,
        v_tenant_id,
        p_payload,
        'pending'
    )
    on conflict (source, external_event_id) do nothing
    returning id into v_id;

    if v_id is null then
        select ew.id into v_id
        from platform.external_webhooks ew
        where ew.source = p_source and ew.external_event_id = p_external_event_id;
    end if;

    return v_id;
end;
$$;

revoke all on function platform.ingest_external_webhook(text, text, text, jsonb, uuid, text) from public, authenticated;
grant execute on function platform.ingest_external_webhook(text, text, text, jsonb, uuid, text) to service_role;

-- =====================================================
-- 3. PAYMENT WEBHOOK ROUTING (000)
-- =====================================================

create or replace function platform.map_stripe_payment_status(p_event_type text)
returns text
language sql
immutable
set search_path = ''
as $$
    select case
        when p_event_type in ('payment_intent.succeeded', 'charge.succeeded') then 'paid'
        when p_event_type in ('payment_intent.payment_failed', 'charge.failed') then 'failed'
        when p_event_type = 'payment_intent.canceled' then 'cancelled'
        when p_event_type = 'payment_intent.amount_capturable_updated' then 'authorized'
        when p_event_type = 'charge.refunded' then 'refunded'
        else null
    end;
$$;

create or replace function platform.process_payment_webhook(
    p_webhook_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_wh record;
    v_external_id text;
    v_intent_id uuid;
    v_new_status text;
    v_mapped text;
begin
    select * into v_wh from platform.external_webhooks where id = p_webhook_id;
    if not found then return false; end if;

    if v_wh.source = 'stripe' then
        v_external_id := coalesce(
            v_wh.payload #>> '{data,object,id}',
            v_wh.payload->>'id'
        );
        v_mapped := platform.map_stripe_payment_status(v_wh.event_type);

        if v_external_id is null or v_mapped is null then
            return false;
        end if;

        select pi.id into v_intent_id
        from platform.payment_intents pi
        where pi.provider = 'stripe'
          and pi.external_intent_id = v_external_id
          and (v_wh.tenant_id is null or pi.tenant_id = v_wh.tenant_id);

        if v_intent_id is null then
            return false;
        end if;

        perform platform.apply_payment_status(
            v_intent_id,
            v_mapped,
            'webhook',
            v_wh.event_type,
            v_wh.external_event_id,
            v_wh.payload
        );
        return true;
    end if;

    if v_wh.source = 'vivawallet' then
        v_external_id := coalesce(v_wh.payload->>'OrderCode', v_wh.payload->>'TransactionId');
        v_mapped := case v_wh.event_type
            when 'payment.success' then 'paid'
            when 'payment.failed' then 'failed'
            when 'payment.cancelled' then 'cancelled'
            else null
        end;

        if v_external_id is null or v_mapped is null then
            return false;
        end if;

        select pi.id into v_intent_id
        from platform.payment_intents pi
        where pi.provider = 'vivawallet'
          and pi.external_intent_id = v_external_id
          and (v_wh.tenant_id is null or pi.tenant_id = v_wh.tenant_id);

        if v_intent_id is null then
            return false;
        end if;

        perform platform.apply_payment_status(
            v_intent_id,
            v_mapped,
            'webhook',
            v_wh.event_type,
            v_wh.external_event_id,
            v_wh.payload
        );
        return true;
    end if;

    return false;
end;
$$;

-- =====================================================
-- 4. UNIFIED WEBHOOK PROCESSOR (000)
-- =====================================================

create or replace function platform.process_external_webhook(p_webhook_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_wh record;
    v_handled boolean := false;
    v_result jsonb;
begin
    select * into v_wh
    from platform.external_webhooks ew
    where ew.id = p_webhook_id
    for update;

    if not found then
        raise exception 'webhook % not found', p_webhook_id;
    end if;

    if v_wh.processing_status = 'processed' then
        return jsonb_build_object('skipped', true, 'reason', 'already_processed');
    end if;

    update platform.external_webhooks set
        processing_status = 'processing'
    where id = p_webhook_id;

    begin
        v_handled := platform.process_payment_webhook(p_webhook_id);

        if v_handled then
            update platform.external_webhooks set
                processing_status = 'processed',
                processed_at = now(),
                last_error = null
            where id = p_webhook_id;

            return jsonb_build_object('processed', true, 'handler', 'payment');
        end if;

        perform platform.schedule_retry_task(
            'external_webhook',
            'external_webhook',
            p_webhook_id,
            jsonb_build_object('source', v_wh.source, 'event_type', v_wh.event_type),
            'no_handler_matched'
        );

        update platform.external_webhooks set
            processing_status = 'skipped',
            processed_at = now(),
            last_error = jsonb_build_object('reason', 'no_handler_matched')
        where id = p_webhook_id;

        return jsonb_build_object('processed', false, 'reason', 'no_handler_matched');

    exception when others then
        update platform.external_webhooks set
            processing_status = 'failed',
            retry_count = retry_count + 1,
            last_error = jsonb_build_object('message', sqlerrm)
        where id = p_webhook_id;

        perform platform.schedule_retry_task(
            'external_webhook',
            'external_webhook',
            p_webhook_id,
            jsonb_build_object('source', v_wh.source),
            sqlerrm
        );

        raise;
    end;
end;
$$;

create or replace function platform.fetch_external_webhook_batch(p_limit int default 50)
returns setof platform.external_webhooks
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    with picked as (
        select ew.id
        from platform.external_webhooks ew
        where ew.processing_status in ('pending', 'failed')
          and ew.retry_count < 5
        order by ew.received_at
        for update skip locked
        limit greatest(p_limit, 1)
    )
    select ew.*
    from platform.external_webhooks ew
    join picked on picked.id = ew.id;
end;
$$;

create or replace function platform.process_external_webhook_batch(p_limit int default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_wh record;
    v_processed int := 0;
    v_failed int := 0;
    v_result jsonb;
begin
    for v_wh in select * from platform.fetch_external_webhook_batch(p_limit)
    loop
        begin
            v_result := platform.process_external_webhook(v_wh.id);
            if coalesce(v_result->>'processed', 'false') = 'true' then
                v_processed := v_processed + 1;
            end if;
        exception when others then
            v_failed := v_failed + 1;
        end;
    end loop;

    return jsonb_build_object(
        'processed', v_processed,
        'failed', v_failed
    );
end;
$$;

revoke all on function platform.process_payment_webhook(uuid) from public, authenticated;
grant execute on function platform.process_payment_webhook(uuid) to service_role;

revoke all on function platform.process_external_webhook(uuid) from public, authenticated;
grant execute on function platform.process_external_webhook(uuid) to service_role;

revoke all on function platform.fetch_external_webhook_batch(int) from public, authenticated;
grant execute on function platform.fetch_external_webhook_batch(int) to service_role;

revoke all on function platform.process_external_webhook_batch(int) from public, authenticated;
grant execute on function platform.process_external_webhook_batch(int) to service_role;

-- =====================================================
-- END 037 PLATFORM WEBHOOK PROCESSING
-- =====================================================
