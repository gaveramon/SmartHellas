-- =====================================================
-- 025 FOUNDATION RPCs, UI VIEWS
-- Public entrypoints + UI-safe read contracts
-- Business SSOT remains in domain functions (018–022)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('025_foundation_rpcs_views_rev19', 'REV19.FOUNDATION.RPC.VIEWS', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. EVENT SYSTEM — PUBLIC insert_event WRAPPER
-- =====================================================

create or replace function public.insert_event(
    p_event_type text,
    p_payload jsonb default '{}'::jsonb,
    p_severity text default 'info',
    p_device_id uuid default null,
    p_correlation_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_event_id uuid;
    v_tid uuid;
begin
    v_tid := platform.current_tenant_id();

    insert into platform.event_log (
        tenant_id,
        user_id,
        event_type,
        source,
        payload,
        severity,
        device_id,
        correlation_id
    )
    values (
        v_tid,
        (select auth.uid()),
        p_event_type,
        'edge_or_rpc',
        coalesce(p_payload, '{}'::jsonb),
        coalesce(p_severity, 'info'),
        p_device_id,
        coalesce(p_correlation_id, gen_random_uuid())
    )
    returning id into v_event_id;

    return v_event_id;
end;
$$;

revoke all on function public.insert_event(text, jsonb, text, uuid, uuid) from public;
grant execute on function public.insert_event(text, jsonb, text, uuid, uuid) to authenticated, service_role;

-- =====================================================
-- 2. NAMED FOUNDATION RPCs (THIN DELEGATES)
-- =====================================================

create or replace function public.create_property(
    p_name text,
    p_property_type public.property_type,
    p_address text default null,
    p_timezone text default 'UTC'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.devices_domain(
        'create_property',
        jsonb_build_object(
            'name', p_name,
            'property_type', p_property_type,
            'address', p_address,
            'timezone', p_timezone
        )
    );
end;
$$;

create or replace function public.assign_device(
    p_device_id uuid,
    p_room_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.devices_assign_device_to_room(p_device_id, p_room_id);
end;
$$;

create or replace function public.generate_lock_code(
    p_lock_device_id uuid,
    p_booking_id uuid default null,
    p_valid_from timestamptz default null,
    p_valid_until timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.locks_domain(
        'issue_credential',
        jsonb_build_object(
            'lock_device_id', p_lock_device_id,
            'booking_id', p_booking_id,
            'valid_from', p_valid_from,
            'valid_until', p_valid_until
        )
    );
end;
$$;

create or replace function public.create_booking(
    p_property_id uuid,
    p_start_date date,
    p_end_date date,
    p_guest_name text default null,
    p_guest_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.booking_domain(
        'create_booking',
        jsonb_build_object(
            'property_id', p_property_id,
            'start_date', p_start_date,
            'end_date', p_end_date,
            'guest_name', p_guest_name,
            'guest_email', p_guest_email
        )
    );
end;
$$;

create or replace function public.onboarding_step_update(
    p_session_id uuid,
    p_step_type public.onboarding_step_type,
    p_status public.onboarding_step_status
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.onboarding_domain(
        'update_step_state',
        jsonb_build_object(
            'session_id', p_session_id,
            'step_type', p_step_type,
            'status', p_status
        )
    );
end;
$$;

create or replace function public.create_subscription(
    p_plan_id uuid,
    p_tier public.subscription_tier default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row jsonb;
begin
    perform public.edge_require_admin();
    v_row := public.commerce_create_subscription(p_plan_id, p_tier);
    perform public.insert_event(
        'subscription.created',
        jsonb_build_object('subscription_id', v_row->>'id', 'plan_id', p_plan_id)
    );
    return v_row;
end;
$$;

create or replace function public.log_event(
    p_event_type text,
    p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    return public.insert_event(p_event_type, p_payload);
end;
$$;

create or replace function public.calculate_optimization_score(
    p_property_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    return public.optimization_domain(
        'calculate_property_score',
        jsonb_build_object('property_id', p_property_id)
    );
end;
$$;

create or replace function public.generate_monetization_proposal(
    p_property_id uuid default null,
    p_source_campaign_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_proposal jsonb;
begin
    perform public.edge_require_manager();
    v_proposal := public.monetization_domain(
        'create_proposal',
        jsonb_build_object(
            'property_id', p_property_id,
            'source_campaign_id', p_source_campaign_id
        )
    );

    perform public.insert_event(
        'monetization.proposal.generated',
        jsonb_build_object('proposal_id', v_proposal->>'id', 'property_id', p_property_id)
    );

    return v_proposal;
end;
$$;

revoke all on function public.create_property(text, public.property_type, text, text) from public;
grant execute on function public.create_property(text, public.property_type, text, text) to authenticated, service_role;

revoke all on function public.assign_device(uuid, uuid) from public;
grant execute on function public.assign_device(uuid, uuid) to authenticated, service_role;

revoke all on function public.generate_lock_code(uuid, uuid, timestamptz, timestamptz) from public;
grant execute on function public.generate_lock_code(uuid, uuid, timestamptz, timestamptz) to authenticated, service_role;

revoke all on function public.create_booking(uuid, date, date, text, text) from public;
grant execute on function public.create_booking(uuid, date, date, text, text) to authenticated, service_role;

revoke all on function public.onboarding_step_update(uuid, public.onboarding_step_type, public.onboarding_step_status) from public;
grant execute on function public.onboarding_step_update(uuid, public.onboarding_step_type, public.onboarding_step_status) to authenticated, service_role;

revoke all on function public.create_subscription(uuid, public.subscription_tier) from public;
grant execute on function public.create_subscription(uuid, public.subscription_tier) to authenticated, service_role;

revoke all on function public.log_event(text, jsonb) from public;
grant execute on function public.log_event(text, jsonb) to authenticated, service_role;

revoke all on function public.calculate_optimization_score(uuid) from public;
grant execute on function public.calculate_optimization_score(uuid) to authenticated, service_role;

revoke all on function public.generate_monetization_proposal(uuid, uuid) from public;
grant execute on function public.generate_monetization_proposal(uuid, uuid) to authenticated, service_role;

-- =====================================================
-- 3. UI-SAFE VIEWS (READ-ONLY CONTRACT)
-- =====================================================

create or replace view public.v_properties_overview
with (security_invoker = true)
as
select
    p.id,
    p.tenant_id,
    p.name,
    p.address,
    p.property_type,
    p.timezone,
    count(distinct r.id) as room_count,
    count(distinct d.id) as device_count,
    p.created_at,
    p.updated_at
from public.properties p
left join public.rooms r on r.property_id = p.id
left join public.device_assignments da on da.room_id = r.id
left join public.devices d on d.id = da.device_id and d.is_active = true
group by p.id;

create or replace view public.v_devices_overview
with (security_invoker = true)
as
select
    d.id,
    d.tenant_id,
    d.device_name,
    d.category_code,
    dc.name as category_name,
    d.protocol,
    d.model,
    d.manufacturer,
    d.is_active,
    r.id as room_id,
    r.name as room_name,
    r.property_id,
    p.name as property_name,
    dus.score as latest_usage_score,
    d.created_at
from public.devices d
left join public.device_categories dc on dc.code = d.category_code
left join public.device_assignments da on da.device_id = d.id
left join public.rooms r on r.id = da.room_id
left join public.properties p on p.id = r.property_id
left join lateral (
    select s.score
    from public.device_usage_scores s
    where s.device_id = d.id
    order by s.calculated_at desc
    limit 1
) dus on true;

create or replace view public.v_onboarding_progress
with (security_invoker = true)
as
select
    os.id as session_id,
    os.tenant_id,
    os.property_id,
    p.name as property_name,
    os.status as session_status,
    os.current_step,
    count(*) filter (where ss.status = 'completed') as completed_steps,
    count(*) as total_steps,
    os.created_at,
    os.updated_at
from public.onboarding_sessions os
join public.properties p on p.id = os.property_id
left join public.onboarding_step_state ss on ss.session_id = os.id
group by os.id, p.name;

create or replace view public.v_bookings_overview
with (security_invoker = true)
as
select
    b.id,
    b.tenant_id,
    b.property_id,
    p.name as property_name,
    b.guest_name,
    b.guest_email,
    b.start_date,
    b.end_date,
    b.status,
    ba.valid_from,
    ba.valid_until,
    ac.status as credential_status,
    b.created_at,
    b.updated_at
from public.bookings b
join public.properties p on p.id = b.property_id
left join public.booking_access ba on ba.booking_id = b.id
left join public.access_credentials ac on ac.booking_id = b.id;

create or replace view public.v_crm_pipeline
with (security_invoker = true)
as
select
    o.id as opportunity_id,
    o.tenant_id,
    o.name as title,
    o.expected_revenue as amount,
    o.status,
    o.expected_close_date,
    ps.id as stage_id,
    ps.name as stage_name,
    ps.stage_order,
    pip.id as pipeline_id,
    pip.name as pipeline_name,
    co.id as company_id,
    co.name as company_name,
    ct.id as contact_id,
    ct.first_name,
    ct.last_name,
    ct.email as contact_email,
    o.created_at,
    o.updated_at
from public.crm_opportunities o
join public.crm_pipeline_stages ps on ps.id = o.stage_id
join public.crm_pipelines pip on pip.id = ps.pipeline_id
left join public.crm_companies co on co.id = o.company_id
left join public.crm_contacts ct on ct.id = o.contact_id
where o.deleted_at is null;

create or replace view public.v_subscription_overview
with (security_invoker = true)
as
select
    s.id,
    s.tenant_id,
    t.name as tenant_name,
    s.tier,
    s.status,
    s.plan_id,
    pp.name as plan_name,
    s.current_period_start,
    s.current_period_end,
    s.created_at,
    s.updated_at
from public.subscriptions s
join public.tenants t on t.id = s.tenant_id
left join public.product_plans pp on pp.id = s.plan_id;

grant select on public.v_properties_overview to authenticated;
grant select on public.v_devices_overview to authenticated;
grant select on public.v_onboarding_progress to authenticated;
grant select on public.v_bookings_overview to authenticated;
grant select on public.v_crm_pipeline to authenticated;
grant select on public.v_subscription_overview to authenticated;

-- =====================================================
-- END 025 FOUNDATION RPCs + UI VIEWS
-- =====================================================
