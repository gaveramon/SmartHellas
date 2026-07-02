-- =====================================================
-- SmartHellas automated integration test runner
-- Usage (from repo root):
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f tests/integration_tests.sql
-- =====================================================

\set ON_ERROR_STOP on

\ir schema_scan.sql
\ir seed_generator.sql
\ir validation.sql
\ir cleanup.sql

create or replace function tests.run_rls_isolation_checks()
returns void
language plpgsql
set search_path = ''
as $$
declare
    v_tenant_a uuid := tests.fixture('tenant_a');
    v_tenant_b uuid := tests.fixture('tenant_b');
    v_user_a uuid := tests.fixture('user_a_owner');
    v_user_b uuid := tests.fixture('user_b_owner');
    v_property_a uuid := tests.fixture('property_a');
    v_property_b uuid := tests.fixture('property_b');
    v_count bigint;
begin
    perform tests.set_jwt_context(v_user_a, v_tenant_a);
    set local role authenticated;
    select count(*) into v_count from public.properties where id = v_property_a;
    reset role;
    perform tests.assert(v_count = 1, 'RLS: tenant A owner must read tenant A property');

    perform tests.set_jwt_context(v_user_a, v_tenant_a);
    set local role authenticated;
    select count(*) into v_count from public.properties where id = v_property_b;
    reset role;
    perform tests.assert(v_count = 0, 'RLS: tenant A owner must not read tenant B property');
    perform tests.clear_jwt_context();

    perform tests.set_jwt_context(v_user_b, v_tenant_b);
    set local role authenticated;
    select count(*) into v_count from public.properties where id = v_property_b;
    reset role;
    perform tests.assert(v_count = 1, 'RLS: tenant B owner must read tenant B property');
    perform tests.clear_jwt_context();
end;
$$;

create or replace function tests.run_integration_suite()
returns void
language plpgsql
set search_path = ''
as $$
declare
    v_tenant_a uuid := tests.fixture('tenant_a');
    v_tenant_b uuid := tests.fixture('tenant_b');
    v_user_a uuid := tests.fixture('user_a_owner');
    v_user_b uuid := tests.fixture('user_b_owner');
    v_property_a uuid := tests.fixture('property_a');
    v_property_b uuid := tests.fixture('property_b');
    v_count bigint;
    v_audit_before bigint;
    v_audit_after bigint;
    v_temp_room uuid := 'b0000000-0000-4000-8000-0000000000ff';
begin
    raise notice '=== SmartHellas integration suite start ===';

    -- 0. schema inventory
    perform tests.run_schema_scan();
    select count(*) into v_count from tests.schema_inventory where category = 'table';
    perform tests.assert(v_count >= 80, 'schema scan must inventory public/platform tables');

    -- 1. seed minimal valid data (dependency order inside function)
    perform tests.seed_integration_fixtures();

    -- 2. module validation 000–015
    perform tests.assert(to_regclass('platform.profiles') is not null, '000 platform.profiles missing');
    perform tests.assert(to_regclass('public.tenants') is not null, '002 tenants missing');
    perform tests.assert(to_regclass('public.properties') is not null, '003 properties missing');
    perform tests.assert(to_regclass('public.bookings') is not null, '004 bookings missing');
    perform tests.assert(to_regclass('public.integration_providers') is not null, '005 providers missing');
    perform tests.assert(to_regclass('public.operation_workflows') is not null, '006 workflows missing');
    perform tests.assert(to_regclass('public.device_bundles') is not null, '007 bundles missing');
    perform tests.assert(to_regclass('public.fulfilment_orders') is not null, '008 fulfilment missing');
    perform tests.assert(to_regclass('public.product_plans') is not null, '009 commerce missing');
    perform tests.assert(to_regclass('public.tenant_portal_settings') is not null, '010 portal missing');
    perform tests.assert(to_regclass('public.onboarding_sessions') is not null, '011 onboarding missing');
    perform tests.assert(to_regclass('public.optimization_rules') is not null, '012 optimization missing');
    perform tests.assert(to_regclass('public.customer_proposals') is not null, '013 proposals missing');
    perform tests.assert(
        exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'platform' and p.proname = 'sync_service_activation_state'),
        '014 bootstrap sync function missing'
    );
    perform tests.assert(to_regclass('public.crm_pipelines') is not null, '015 CRM missing');

    -- 3. cross-module integration
    perform tests.assert(
        exists (
            select 1
            from public.fulfilment_orders fo
            join public.package_definitions pd on pd.id = fo.package_definition_id
            join public.device_bundles db on db.id = pd.device_bundle_id
            where fo.id = tests.fixture('fulfilment')
        ),
        '008 fulfilment must bind 007 bundle through package_definitions'
    );

    perform tests.assert(
        exists (
            select 1
            from platform.payment_intents pi
            join public.subscriptions s on s.id = pi.target_id
            join public.integration_providers ip on ip.code = pi.provider
            where pi.id = tests.fixture('payment_intent')
        ),
        '014 payment_intent must bridge 009 subscription and 005 provider'
    );

    -- 4. SSOT ownership
    perform tests.assert(
        (select count(*) from tests.module_ownership) >= 16,
        'module ownership map incomplete'
    );

    perform tests.assert(
        not exists (
            select 1
            from tests.schema_inventory
            where category = 'enum'
              and object_schema not in ('public', 'platform')
        ),
        'enums must live in public/platform (001 SSOT)'
    );

    -- 5. tenant isolation (data plane)
    perform tests.assert(
        (select tenant_id from public.properties where id = v_property_a) <>
        (select tenant_id from public.properties where id = v_property_b),
        'fixture tenants must be isolated at property level'
    );

    -- 6. RLS (authenticated role + JWT tenant context)
    perform tests.run_rls_isolation_checks();

    -- 7. cascade behaviour (room → assignments)
    insert into public.rooms (id, property_id, name, room_type)
    values (v_temp_room, v_property_a, '__cascade_test__', 'bedroom')
    on conflict (id) do nothing;

    insert into public.device_assignments (id, device_id, room_id)
    select 'b0000000-0000-4000-8000-0000000000fe', tests.fixture('lock_dev'), v_temp_room
    where not exists (
        select 1 from public.device_assignments where device_id = tests.fixture('lock_dev')
    );

    update public.device_assignments
    set room_id = v_temp_room
    where device_id = tests.fixture('lock_dev');

    delete from public.rooms where id = v_temp_room;

    perform tests.assert(
        not exists (select 1 from public.device_assignments where room_id = v_temp_room),
        'device_assignments must cascade on room delete'
    );

    insert into public.device_assignments (id, device_id, room_id)
    values (tests.fixture('device_assign'), tests.fixture('lock_dev'), tests.fixture('room_a'))
    on conflict (device_id) do update set room_id = excluded.room_id;

    -- 8. audit / event generation
    perform tests.set_jwt_context(v_user_a, v_tenant_a);
    select count(*) into v_audit_before
    from platform.audit_log
    where tenant_id = v_tenant_a and entity_id = v_property_a;

    perform platform.log_audit('integration_test', 'property', v_property_a, '{"suite":true}'::jsonb);

    select count(*) into v_audit_after
    from platform.audit_log
    where tenant_id = v_tenant_a and entity_id = v_property_a;

    perform tests.assert(v_audit_after > v_audit_before, 'platform.log_audit must append audit_log row');
    perform tests.clear_jwt_context();

    -- 9. onboarding flow
    perform tests.assert(
        exists (
            select 1
            from public.onboarding_sessions os
            join public.onboarding_step_state oss on oss.session_id = os.id
            where os.id = tests.fixture('onboard_session')
              and oss.step_type = 'wifi_setup'
        ),
        'onboarding flow must link session to step state'
    );

    -- 10. logistics flow
    perform tests.assert(
        exists (
            select 1
            from public.fulfilment_orders fo
            join public.warehouses w on w.id = fo.warehouse_id
            join public.shipping_carriers sc on sc.id = fo.carrier_id
            where fo.id = tests.fixture('fulfilment')
              and w.tenant_id = fo.tenant_id
        ),
        'logistics flow must bind warehouse and carrier to fulfilment order'
    );

    -- 11. booking / access flow
    perform tests.assert(
        exists (
            select 1
            from public.bookings b
            join public.booking_access ba on ba.booking_id = b.id
            join public.access_credentials ac on ac.booking_id = b.id
            where b.id = tests.fixture('booking_a')
              and ba.access_type = 'guest'
        ),
        'booking/access flow must connect booking, guest window, and credential'
    );

    -- 12. provisioning flow (007 + 011 + 013)
    perform tests.assert(
        exists (
            select 1
            from public.preconfig_templates pt
            join public.device_bundles db on db.id = pt.device_bundle_id
            join public.onboarding_sessions os on os.preconfig_template_id = pt.id
            where pt.id = tests.fixture('preconfig_tpl')
        ),
        'provisioning flow must chain preconfig template, bundle, and onboarding session'
    );

    -- 13. CRM flow
    perform tests.assert(
        exists (
            select 1
            from public.crm_opportunities o
            join public.crm_pipeline_stages st on st.id = o.stage_id
            join public.crm_contacts c on c.id = o.contact_id
            where o.id = tests.fixture('crm_opp')
              and st.pipeline_id = o.pipeline_id
        ),
        'CRM flow must align opportunity with pipeline stage and contact'
    );

    -- 14. portal flow
    perform tests.assert(
        exists (
            select 1
            from public.tenant_portal_settings tps
            join public.dashboard_configs dc on dc.tenant_id = tps.tenant_id
            where tps.tenant_id = v_tenant_a
        ),
        'portal flow must co-exist portal settings and dashboard config'
    );

    -- 15. integration providers
    perform tests.assert(
        exists (
            select 1
            from public.integration_providers ip
            join public.tenant_integrations ti on ti.provider_code = ip.code
            where ti.id = tests.fixture('tenant_integ')
              and ip.code = 'ttlock'
        ),
        'tenant integration must reference integration_providers SSOT'
    );

    -- 16. subscriptions and commerce
    perform tests.assert(
        exists (
            select 1
            from public.subscriptions s
            join public.product_plans pp on pp.id = s.plan_id
            join public.feature_entitlements fe on fe.plan_id = pp.id
            where s.id = tests.fixture('subscription_a')
              and fe.feature_key = 'auto_door_code'
        ),
        'commerce stack must bind subscription, plan, and entitlements'
    );

    -- 17. post-insert validation bundle
    perform tests.run_validations();

    raise notice '=== SmartHellas integration suite PASSED ===';
end;
$$;

-- execute suite
select tests.run_integration_suite();
