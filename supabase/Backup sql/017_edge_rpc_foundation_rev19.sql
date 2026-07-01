-- =====================================================
-- 017 EDGE RPC FOUNDATION (REV19)
-- SQL SSOT for Edge orchestration: guards, business rules, public RPC wrappers
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('017_edge_rpc_foundation_rev19', 'REV19.EDGE.RPC.FOUNDATION', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. PUBLIC WRAPPERS (authenticated JWT context)
-- =====================================================

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.is_platform_admin();
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated, service_role;

create or replace function public.edge_require_tenant()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if (select auth.uid()) is null then
        raise exception 'authentication required';
    end if;
    if platform.current_tenant_id() is null then
        raise exception 'no active tenant';
    end if;
end;
$$;

revoke all on function public.edge_require_tenant() from public;
grant execute on function public.edge_require_tenant() to authenticated, service_role;

create or replace function public.edge_require_manager()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    if not (
        platform.is_platform_admin()
        or platform.is_admin()
        or platform.has_role('manager')
    ) then
        raise exception 'manager, admin, or owner role required';
    end if;
end;
$$;

revoke all on function public.edge_require_manager() from public;
grant execute on function public.edge_require_manager() to authenticated, service_role;

create or replace function public.edge_require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    if not (platform.is_platform_admin() or platform.is_admin()) then
        raise exception 'admin or owner role required';
    end if;
end;
$$;

revoke all on function public.edge_require_admin() from public;
grant execute on function public.edge_require_admin() to authenticated, service_role;

-- =====================================================
-- 2. BUSINESS RULES (moved from Edge TypeScript)
-- =====================================================

create or replace function public.trg_customer_proposals_status_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.status is distinct from old.status then
        if new.status = 'presented'::public.proposal_status then
            new.presented_at := coalesce(new.presented_at, now());
        elsif new.status = 'accepted'::public.proposal_status then
            new.accepted_at := coalesce(new.accepted_at, now());
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_customer_proposals_status_timestamps on public.customer_proposals;
create trigger trg_customer_proposals_status_timestamps
before update of status on public.customer_proposals
for each row execute function public.trg_customer_proposals_status_timestamps();

create or replace function public.trg_crm_contacts_consent_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        if new.marketing_consent then
            new.marketing_consent_at := coalesce(new.marketing_consent_at, now());
        end if;
        if new.gdpr_consent then
            new.gdpr_consent_at := coalesce(new.gdpr_consent_at, now());
        end if;
    elsif tg_op = 'UPDATE' then
        if new.marketing_consent is distinct from old.marketing_consent then
            new.marketing_consent_at := case
                when new.marketing_consent then coalesce(new.marketing_consent_at, now())
                else null
            end;
        end if;
        if new.gdpr_consent is distinct from old.gdpr_consent then
            new.gdpr_consent_at := case
                when new.gdpr_consent then coalesce(new.gdpr_consent_at, now())
                else null
            end;
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_crm_contacts_consent_timestamps on public.crm_contacts;
create trigger trg_crm_contacts_consent_timestamps
before insert or update on public.crm_contacts
for each row execute function public.trg_crm_contacts_consent_timestamps();

create or replace function public.trg_crm_leads_conversion_timestamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.status is distinct from old.status then
        if new.status = 'converted'::public.crm_lead_status then
            new.converted_at := coalesce(new.converted_at, now());
        elsif old.status = 'converted'::public.crm_lead_status
              and new.status <> 'converted'::public.crm_lead_status then
            new.converted_at := null;
        end if;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_crm_leads_conversion_timestamp on public.crm_leads;
create trigger trg_crm_leads_conversion_timestamp
before update of status on public.crm_leads
for each row execute function public.trg_crm_leads_conversion_timestamp();

create or replace function public.trg_crm_notes_version_increment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.body is distinct from old.body then
        new.version := old.version + 1;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_crm_notes_version_increment on public.crm_notes;
create trigger trg_crm_notes_version_increment
before update of body on public.crm_notes
for each row execute function public.trg_crm_notes_version_increment();

create or replace function public.assign_device_to_room(
    p_device_id uuid,
    p_room_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row record;
    v_existing uuid;
begin
    perform public.edge_require_tenant();

    select da.id into v_existing
    from public.device_assignments da
    where da.device_id = p_device_id;

    if found then
        update public.device_assignments
        set room_id = p_room_id
        where device_id = p_device_id
        returning device_id, room_id, assigned_at
        into v_row;
    else
        insert into public.device_assignments (device_id, room_id)
        values (p_device_id, p_room_id)
        returning device_id, room_id, assigned_at
        into v_row;
    end if;

    return jsonb_build_object(
        'device_id', v_row.device_id,
        'room_id', v_row.room_id,
        'assigned_at', v_row.assigned_at
    );
end;
$$;

revoke all on function public.assign_device_to_room(uuid, uuid) from public;
grant execute on function public.assign_device_to_room(uuid, uuid) to authenticated, service_role;

create or replace function public.change_subscription_plan(p_plan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_sub record;
begin
    perform public.edge_require_admin();
    v_tid := platform.current_tenant_id();

    if not exists (
        select 1 from public.product_plans pp
        where pp.id = p_plan_id and pp.is_active = true
    ) then
        raise exception 'product plan not found or inactive';
    end if;

    update public.subscriptions s
    set plan_id = p_plan_id
    where s.tenant_id = v_tid
    returning s.id, s.plan_id, s.tier, s.status
    into v_sub;

    if not found then
        raise exception 'subscription not found for tenant';
    end if;

    return jsonb_build_object(
        'subscription_id', v_sub.id,
        'plan_id', v_sub.plan_id,
        'tier', v_sub.tier,
        'status', v_sub.status
    );
end;
$$;

revoke all on function public.change_subscription_plan(uuid) from public;
grant execute on function public.change_subscription_plan(uuid) to authenticated, service_role;

create or replace function public.dispatch_fulfilment_order(
    p_fulfilment_order_id uuid,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_order record;
    v_queue_id text;
    v_merged jsonb;
begin
    perform public.edge_require_manager();
    v_tid := platform.current_tenant_id();

    select fo.id, fo.status, fo.property_id, fo.carrier_id, fo.warehouse_id,
           fo.label_template_id, fo.package_definition_id, fo.device_bundle_id
    into v_order
    from public.fulfilment_orders fo
    where fo.id = p_fulfilment_order_id
      and fo.tenant_id = v_tid
      and fo.deleted_at is null;

    if not found then
        raise exception 'fulfilment order not found';
    end if;

    if v_order.status <> 'ready_to_ship' then
        raise exception 'fulfilment order must be ready_to_ship before dispatch (current: %)', v_order.status;
    end if;

    v_merged := coalesce(p_payload, '{}'::jsonb)
        || jsonb_build_object(
            'property_id', v_order.property_id,
            'carrier_id', v_order.carrier_id,
            'warehouse_id', v_order.warehouse_id,
            'label_template_id', v_order.label_template_id,
            'package_definition_id', v_order.package_definition_id,
            'device_bundle_id', v_order.device_bundle_id
        );

    v_queue_id := platform.enqueue_shipment_dispatch(
        v_tid,
        v_order.id,
        v_merged
    );

    return jsonb_build_object(
        'queued', true,
        'dispatch_queue_id', v_queue_id,
        'fulfilment_order_id', v_order.id
    );
end;
$$;

revoke all on function public.dispatch_fulfilment_order(uuid, jsonb) from public;
grant execute on function public.dispatch_fulfilment_order(uuid, jsonb) to authenticated, service_role;

-- =====================================================
-- 3. GENERIC SOFT DELETE HELPER (CRM-style tables)
-- =====================================================

create or replace function public.edge_soft_delete_row(
    p_table regclass,
    p_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_count int;
begin
    perform public.edge_require_manager();
    execute format(
        'update %s set deleted_at = now() where id = $1 and tenant_id = $2',
        p_table
    ) using p_id, platform.current_tenant_id();
    get diagnostics v_count = row_count;
    if v_count = 0 then
        raise exception 'record not found or not accessible';
    end if;
    return jsonb_build_object('deleted', true, 'id', p_id);
end;
$$;

revoke all on function public.edge_soft_delete_row(regclass, uuid) from public;
grant execute on function public.edge_soft_delete_row(regclass, uuid) to authenticated, service_role;

-- =====================================================
-- END 017 EDGE RPC FOUNDATION
-- =====================================================
