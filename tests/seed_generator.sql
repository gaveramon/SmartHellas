-- =====================================================
-- SmartHellas integration test seed generator
-- Deterministic UUIDs, dependency-ordered inserts
-- Idempotent: ON CONFLICT DO NOTHING / DO UPDATE
-- =====================================================

create schema if not exists tests;

create table if not exists tests.fixture_registry (
    fixture_key text primary key,
    fixture_uuid uuid not null,
    entity_table text,
    notes text
);

insert into tests.fixture_registry (fixture_key, fixture_uuid, entity_table, notes) values
    ('run_id',           'b0000000-0000-4000-8000-000000000001', null, 'correlation marker'),
    ('tenant_a',         'b0000000-0000-4000-8000-000000000010', 'public.tenants', 'primary tenant'),
    ('tenant_b',         'b0000000-0000-4000-8000-000000000011', 'public.tenants', 'isolation tenant'),
    ('user_a_owner',     'b0000000-0000-4000-8000-000000000020', 'auth.users', 'owner tenant_a'),
    ('user_b_owner',     'b0000000-0000-4000-8000-000000000021', 'auth.users', 'owner tenant_b'),
    ('user_a_viewer',    'b0000000-0000-4000-8000-000000000022', 'auth.users', 'viewer tenant_a'),
    ('plan_pro',         'b0000000-0000-4000-8000-000000000030', 'public.product_plans', 'commerce catalog'),
    ('plan_pricing_eur', 'b0000000-0000-4000-8000-000000000031', 'public.plan_pricing', null),
    ('feature_ent',      'b0000000-0000-4000-8000-000000000032', 'public.feature_entitlements', null),
    ('subscription_a',   'b0000000-0000-4000-8000-000000000033', 'public.subscriptions', null),
    ('property_a',       'b0000000-0000-4000-8000-000000000040', 'public.properties', null),
    ('property_b',       'b0000000-0000-4000-8000-000000000041', 'public.properties', 'tenant_b'),
    ('room_a',           'b0000000-0000-4000-8000-000000000050', 'public.rooms', null),
    ('gateway_dev',      'b0000000-0000-4000-8000-000000000060', 'public.devices', 'gateway category'),
    ('lock_dev',         'b0000000-0000-4000-8000-000000000061', 'public.devices', 'lock category'),
    ('device_map',       'b0000000-0000-4000-8000-000000000062', 'public.device_integration_map', null),
    ('device_assign',    'b0000000-0000-4000-8000-000000000063', 'public.device_assignments', null),
    ('access_sched',     'b0000000-0000-4000-8000-000000000064', 'public.property_access_schedules', null),
    ('booking_a',        'b0000000-0000-4000-8000-000000000070', 'public.bookings', null),
    ('booking_access',   'b0000000-0000-4000-8000-000000000071', 'public.booking_access', null),
    ('lock_device',      'b0000000-0000-4000-8000-000000000072', 'public.lock_devices', null),
    ('credential',       'b0000000-0000-4000-8000-000000000073', 'public.access_credentials', null),
    ('device_bundle',    'b0000000-0000-4000-8000-000000000080', 'public.device_bundles', '007 catalog'),
    ('bundle_device',    'b0000000-0000-4000-8000-000000000081', 'public.bundle_devices', null),
    ('onboard_bp',       'b0000000-0000-4000-8000-000000000082', 'public.onboarding_blueprints', null),
    ('onboard_bp_step',  'b0000000-0000-4000-8000-000000000083', 'public.onboarding_blueprint_steps', null),
    ('preconfig_tpl',    'b0000000-0000-4000-8000-000000000084', 'public.preconfig_templates', null),
    ('onboard_session',  'b0000000-0000-4000-8000-000000000085', 'public.onboarding_sessions', null),
    ('onboard_step',     'b0000000-0000-4000-8000-000000000086', 'public.onboarding_step_state', null),
    ('carrier',          'b0000000-0000-4000-8000-000000000090', 'public.shipping_carriers', null),
    ('warehouse',        'b0000000-0000-4000-8000-000000000091', 'public.warehouses', null),
    ('logistics_tpl',    'b0000000-0000-4000-8000-000000000092', 'public.logistics_templates', null),
    ('package_def',      'b0000000-0000-4000-8000-000000000093', 'public.package_definitions', null),
    ('fulfilment',       'b0000000-0000-4000-8000-000000000094', 'public.fulfilment_orders', null),
    ('op_template',      'b0000000-0000-4000-8000-0000000000a0', 'public.operation_templates', null),
    ('workflow',         'b0000000-0000-4000-8000-0000000000a1', 'public.operation_workflows', null),
    ('workflow_step',    'b0000000-0000-4000-8000-0000000000a2', 'public.workflow_steps', null),
    ('workflow_trig',    'b0000000-0000-4000-8000-0000000000a3', 'public.workflow_triggers', null),
    ('support_ticket',   'b0000000-0000-4000-8000-0000000000a4', 'public.support_tickets', null),
    ('support_msg',      'b0000000-0000-4000-8000-0000000000a5', 'public.support_messages', null),
    ('monet_package',    'b0000000-0000-4000-8000-0000000000b0', 'public.monetization_packages', null),
    ('proposal',         'b0000000-0000-4000-8000-0000000000b1', 'public.customer_proposals', null),
    ('proposal_item',    'b0000000-0000-4000-8000-0000000000b2', 'public.proposal_items', null),
    ('tenant_integ',     'b0000000-0000-4000-8000-0000000000c0', 'public.tenant_integrations', null),
    ('portal_settings',  'b0000000-0000-4000-8000-0000000000d0', 'public.tenant_portal_settings', null),
    ('dashboard',        'b0000000-0000-4000-8000-0000000000d1', 'public.dashboard_configs', null),
    ('crm_pipeline',     'b0000000-0000-4000-8000-0000000000e0', 'public.crm_pipelines', null),
    ('crm_stage',        'b0000000-0000-4000-8000-0000000000e1', 'public.crm_pipeline_stages', null),
    ('crm_contact',      'b0000000-0000-4000-8000-0000000000e2', 'public.crm_contacts', null),
    ('crm_company',      'b0000000-0000-4000-8000-0000000000e3', 'public.crm_companies', null),
    ('crm_lead',         'b0000000-0000-4000-8000-0000000000e4', 'public.crm_leads', null),
    ('crm_opp',          'b0000000-0000-4000-8000-0000000000e5', 'public.crm_opportunities', null),
    ('payment_intent',   'b0000000-0000-4000-8000-0000000000f0', 'platform.payment_intents', null),
    ('opt_rule',         'b0000000-0000-4000-8000-000000000100', 'public.optimization_rules', null),
    ('insight_event',    'b0000000-0000-4000-8000-000000000101', 'public.insight_events', null)
on conflict (fixture_key) do update set
    fixture_uuid = excluded.fixture_uuid,
    entity_table = excluded.entity_table,
    notes = excluded.notes;

create or replace function tests.fixture(p_key text)
returns uuid
language sql
stable
as $$
    select fixture_uuid from tests.fixture_registry where fixture_key = p_key;
$$;

create or replace function tests.set_jwt_context(p_user_id uuid, p_tenant_id uuid)
returns void
language plpgsql
as $$
begin
    perform set_config(
        'request.jwt.claims',
        json_build_object(
            'sub', p_user_id::text,
            'role', 'authenticated',
            'app_metadata', json_build_object('tenant_id', p_tenant_id::text)
        )::text,
        true
    );
    perform set_config('request.jwt.claim.sub', p_user_id::text, true);
end;
$$;

create or replace function tests.clear_jwt_context()
returns void
language plpgsql
as $$
begin
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

create or replace function tests.upsert_auth_user(
    p_user_id uuid,
    p_email text,
    p_tenant_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at
    )
    values (
        p_user_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        p_email,
        extensions.crypt('integration-test-password', extensions.gen_salt('bf')),
        now(),
        case when p_tenant_id is null then '{}'::jsonb else jsonb_build_object('tenant_id', p_tenant_id::text) end,
        jsonb_build_object('full_name', 'Integration Test User'),
        now(),
        now()
    )
    on conflict (id) do update set
        email = excluded.email,
        raw_app_meta_data = excluded.raw_app_meta_data,
        updated_at = now();

    insert into platform.profiles (id, email, full_name, is_active)
    values (p_user_id, p_email::public.citext, 'Integration Test User', true)
    on conflict (id) do update set
        email = excluded.email,
        full_name = excluded.full_name,
        is_active = true;
end;
$$;

create or replace function tests.seed_integration_fixtures()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant_a uuid := tests.fixture('tenant_a');
    v_tenant_b uuid := tests.fixture('tenant_b');
    v_user_a uuid := tests.fixture('user_a_owner');
    v_user_b uuid := tests.fixture('user_b_owner');
    v_user_viewer uuid := tests.fixture('user_a_viewer');
begin
    -- layer 0: identity (000)
    perform tests.upsert_auth_user(v_user_a, 'integration-owner-a@test.local', v_tenant_a);
    perform tests.upsert_auth_user(v_user_b, 'integration-owner-b@test.local', v_tenant_b);
    perform tests.upsert_auth_user(v_user_viewer, 'integration-viewer-a@test.local', v_tenant_a);

    -- layer 1: tenants (002)
    insert into public.tenants (id, name, status)
    values
        (v_tenant_a, '__integration_test__ tenant A', 'active'),
        (v_tenant_b, '__integration_test__ tenant B', 'active')
    on conflict (id) do update set name = excluded.name, status = excluded.status;

    insert into public.tenant_memberships (id, tenant_id, user_id, role, is_active)
    values
        ('b0000000-0000-4000-8000-000000000015', v_tenant_a, v_user_a, 'owner', true),
        ('b0000000-0000-4000-8000-000000000016', v_tenant_b, v_user_b, 'owner', true),
        ('b0000000-0000-4000-8000-000000000017', v_tenant_a, v_user_viewer, 'viewer', true)
    on conflict (tenant_id, user_id) do update set role = excluded.role, is_active = true;

    -- layer 2: commerce catalog (009) — required before subscriptions
    insert into public.product_plans (id, name, tier, is_active)
    values (tests.fixture('plan_pro'), '__integration_test__ Pro Plan', 'pro', true)
    on conflict (id) do update set name = excluded.name, tier = excluded.tier;

    insert into public.plan_pricing (id, plan_id, currency, monthly_price, yearly_price)
    values (tests.fixture('plan_pricing_eur'), tests.fixture('plan_pro'), 'EUR', 49.00, 490.00)
    on conflict (plan_id, currency) do update set monthly_price = excluded.monthly_price;

    insert into public.feature_entitlements (id, plan_id, feature_key, enabled)
    values (tests.fixture('feature_ent'), tests.fixture('plan_pro'), 'auto_door_code', true)
    on conflict (plan_id, feature_key) do update set enabled = excluded.enabled;

    insert into public.subscriptions (id, tenant_id, tier, status, plan_id)
    values (tests.fixture('subscription_a'), v_tenant_a, 'pro', 'active', tests.fixture('plan_pro'))
    on conflict (id) do update set status = excluded.status, plan_id = excluded.plan_id;

    -- layer 3: integrations (005) — catalog pre-seeded; tenant connection
    insert into public.tenant_integrations (id, tenant_id, provider_code, is_enabled)
    values (tests.fixture('tenant_integ'), v_tenant_a, 'ttlock', true)
    on conflict (tenant_id, provider_code) do update set is_enabled = true;

    -- layer 4: property graph (003)
    insert into public.properties (id, tenant_id, name, property_type, timezone)
    values
        (tests.fixture('property_a'), v_tenant_a, '__integration_test__ Property A', 'apartment', 'Europe/Athens'),
        (tests.fixture('property_b'), v_tenant_b, '__integration_test__ Property B', 'studio', 'Europe/Athens')
    on conflict (id) do update set name = excluded.name;

    insert into public.rooms (id, property_id, name, room_type)
    values (tests.fixture('room_a'), tests.fixture('property_a'), 'Living Room', 'living_room')
    on conflict (id) do update set name = excluded.name;

    insert into public.devices (id, tenant_id, device_name, category_code, protocol, parent_device_id)
    values
        (tests.fixture('gateway_dev'), v_tenant_a, 'Test Gateway', 'gateway', 'zigbee', null),
        (tests.fixture('lock_dev'), v_tenant_a, 'Test Lock', 'lock', 'wifi', tests.fixture('gateway_dev'))
    on conflict (id) do update set device_name = excluded.device_name;

    insert into public.device_integration_map (id, tenant_id, device_id, provider_code, external_id)
    values (tests.fixture('device_map'), v_tenant_a, tests.fixture('lock_dev'), 'ttlock', 'integration-test-lock-001')
    on conflict (device_id, provider_code) do update set external_id = excluded.external_id;

    insert into public.device_assignments (id, device_id, room_id)
    values (tests.fixture('device_assign'), tests.fixture('lock_dev'), tests.fixture('room_a'))
    on conflict (device_id) do update set room_id = excluded.room_id;

    -- layer 5: booking / access (004)
    insert into public.property_access_schedules (id, tenant_id, property_id)
    values (tests.fixture('access_sched'), v_tenant_a, tests.fixture('property_a'))
    on conflict (property_id) do nothing;

    insert into public.bookings (id, tenant_id, property_id, guest_name, start_date, end_date, status)
    values (
        tests.fixture('booking_a'),
        v_tenant_a,
        tests.fixture('property_a'),
        'Integration Guest',
        current_date + 1,
        current_date + 3,
        'confirmed'
    )
    on conflict (id) do update set status = excluded.status;

    insert into public.booking_access (id, tenant_id, booking_id, access_type, valid_from, valid_until)
    values (
        tests.fixture('booking_access'),
        v_tenant_a,
        tests.fixture('booking_a'),
        'guest',
        (current_date + 1)::timestamptz + time '15:00',
        (current_date + 3)::timestamptz + time '11:00'
    )
    on conflict do nothing;

    insert into public.lock_devices (id, tenant_id, device_id, property_id, is_primary)
    values (tests.fixture('lock_device'), v_tenant_a, tests.fixture('lock_dev'), tests.fixture('property_a'), true)
    on conflict (device_id) do update set is_primary = excluded.is_primary;

    insert into public.access_credentials (
        id, tenant_id, booking_id, lock_device_id, booking_access_id,
        provider_code, status, credential_ref, valid_from, valid_until
    )
    values (
        tests.fixture('credential'),
        v_tenant_a,
        tests.fixture('booking_a'),
        tests.fixture('lock_device'),
        tests.fixture('booking_access'),
        'ttlock',
        'pending',
        'integration-test-credential-ref',
        (current_date + 1)::timestamptz + time '15:00',
        (current_date + 3)::timestamptz + time '11:00'
    )
    on conflict (id) do update set status = excluded.status;

    -- layer 6: preconfig / onboarding (007 + 011)
    insert into public.device_bundles (id, code, version, name, is_system, is_active)
    values (tests.fixture('device_bundle'), 'integration_starter', 1, '__integration_test__ Starter Kit', true, true)
    on conflict (code, version) do update set name = excluded.name;

    insert into public.bundle_devices (id, bundle_id, category_code, quantity)
    values (tests.fixture('bundle_device'), tests.fixture('device_bundle'), 'lock', 1)
    on conflict do nothing;

    insert into public.onboarding_blueprints (id, code, name, is_system, is_active)
    values (tests.fixture('onboard_bp'), 'integration_default', '__integration_test__ Default Blueprint', true, true)
    on conflict (code) do update set name = excluded.name;

    insert into public.onboarding_blueprint_steps (id, blueprint_id, step_order, step_type)
    values (tests.fixture('onboard_bp_step'), tests.fixture('onboard_bp'), 1, 'wifi_setup')
    on conflict (id) do update set step_type = excluded.step_type;

    insert into public.preconfig_templates (id, name, device_bundle_id, onboarding_blueprint_id, is_active)
    values (
        tests.fixture('preconfig_tpl'),
        '__integration_test__ Template',
        tests.fixture('device_bundle'),
        tests.fixture('onboard_bp'),
        true
    )
    on conflict (id) do update set name = excluded.name;

    insert into public.onboarding_sessions (
        id, tenant_id, property_id, preconfig_template_id, onboarding_blueprint_id, status, current_step
    )
    values (
        tests.fixture('onboard_session'),
        v_tenant_a,
        tests.fixture('property_a'),
        tests.fixture('preconfig_tpl'),
        tests.fixture('onboard_bp'),
        'in_progress',
        'wifi_setup'
    )
    on conflict (id) do update set status = excluded.status;

    insert into public.onboarding_step_state (id, tenant_id, session_id, step_type, status)
    values (tests.fixture('onboard_step'), v_tenant_a, tests.fixture('onboard_session'), 'wifi_setup', 'in_progress')
    on conflict (session_id, step_type) do update set status = excluded.status;

    -- layer 7: logistics (008)
    insert into public.shipping_carriers (id, name, provider_code, is_active)
    values (tests.fixture('carrier'), '__integration_test__ Carrier', 'generic', true)
    on conflict (name) do update set provider_code = excluded.provider_code;

    insert into public.warehouses (id, tenant_id, name, default_carrier_id, is_active)
    values (tests.fixture('warehouse'), v_tenant_a, '__integration_test__ Warehouse', tests.fixture('carrier'), true)
    on conflict (id) do update set name = excluded.name;

    insert into public.logistics_templates (id, tenant_id, is_system, name, is_active)
    values (tests.fixture('logistics_tpl'), v_tenant_a, false, '__integration_test__ Logistics Template', true)
    on conflict (id) do update set name = excluded.name;

    insert into public.package_definitions (id, template_id, device_bundle_id, name)
    values (
        tests.fixture('package_def'),
        tests.fixture('logistics_tpl'),
        tests.fixture('device_bundle'),
        '__integration_test__ Shipment Package'
    )
    on conflict (template_id, device_bundle_id) do update set name = excluded.name;

    insert into public.fulfilment_orders (
        id, tenant_id, property_id, package_definition_id, device_bundle_id,
        carrier_id, warehouse_id, status
    )
    values (
        tests.fixture('fulfilment'),
        v_tenant_a,
        tests.fixture('property_a'),
        tests.fixture('package_def'),
        tests.fixture('device_bundle'),
        tests.fixture('carrier'),
        tests.fixture('warehouse'),
        'draft'
    )
    on conflict (id) do update set status = excluded.status;

    -- layer 8: operations (006)
    insert into public.operation_templates (id, tenant_id, name, template, is_system, is_active)
    values (
        tests.fixture('op_template'),
        v_tenant_a,
        '__integration_test__ Op Template',
        '{"steps":[]}'::jsonb,
        false,
        true
    )
    on conflict (id) do update set name = excluded.name;

    insert into public.operation_workflows (id, tenant_id, name, source_template_id, is_active)
    values (tests.fixture('workflow'), v_tenant_a, '__integration_test__ Workflow', tests.fixture('op_template'), true)
    on conflict (id) do update set name = excluded.name;

    insert into public.workflow_steps (id, tenant_id, workflow_id, step_order, action_type)
    values (tests.fixture('workflow_step'), v_tenant_a, tests.fixture('workflow'), 1, 'send_notification')
    on conflict do nothing;

    insert into public.workflow_triggers (id, tenant_id, workflow_id, property_id, trigger_type)
    values (
        tests.fixture('workflow_trig'),
        v_tenant_a,
        tests.fixture('workflow'),
        tests.fixture('property_a'),
        'booking_created'
    )
    on conflict do nothing;

    insert into public.support_tickets (id, tenant_id, user_id, subject, status)
    values (tests.fixture('support_ticket'), v_tenant_a, v_user_a, '__integration_test__ Support', 'open')
    on conflict (id) do update set status = excluded.status;

    insert into public.support_messages (id, tenant_id, ticket_id, sender_type, message)
    values (
        tests.fixture('support_msg'),
        v_tenant_a,
        tests.fixture('support_ticket'),
        'user',
        'Integration test message'
    )
    on conflict (id) do update set message = excluded.message;

    -- layer 9: monetization (013)
    insert into public.monetization_packages (id, name, package_type, device_bundle_id, base_price, is_active)
    values (
        tests.fixture('monet_package'),
        '__integration_test__ Hardware Package',
        'hardware',
        tests.fixture('device_bundle'),
        299.00,
        true
    )
    on conflict (id) do update set name = excluded.name;

    insert into public.customer_proposals (id, tenant_id, property_id, status)
    values (tests.fixture('proposal'), v_tenant_a, tests.fixture('property_a'), 'draft')
    on conflict (id) do update set status = excluded.status;

    insert into public.proposal_items (id, tenant_id, proposal_id, item_type, plan_id, quantity, price_estimate)
    values (
        tests.fixture('proposal_item'),
        v_tenant_a,
        tests.fixture('proposal'),
        'subscription',
        tests.fixture('plan_pro'),
        1,
        49.00
    )
    on conflict (id) do update set quantity = excluded.quantity;

    -- layer 10: portal (010)
    insert into public.tenant_portal_settings (id, tenant_id, theme, default_language)
    values (
        tests.fixture('portal_settings'),
        v_tenant_a,
        '{"mode":"light"}'::jsonb,
        'en'
    )
    on conflict (tenant_id) do update set default_language = excluded.default_language;

    insert into public.dashboard_configs (id, tenant_id, name, layout, is_default)
    values (
        tests.fixture('dashboard'),
        v_tenant_a,
        '__integration_test__ Dashboard',
        '{"widgets":[]}'::jsonb,
        true
    )
    on conflict (id) do update set name = excluded.name;

    -- layer 11: CRM (015)
    insert into public.crm_pipelines (id, tenant_id, name, is_default, is_active)
    values (tests.fixture('crm_pipeline'), v_tenant_a, '__integration_test__ Sales', true, true)
    on conflict (id) do update set name = excluded.name;

    insert into public.crm_pipeline_stages (id, tenant_id, pipeline_id, name, stage_order, is_terminal, terminal_outcome)
    values (tests.fixture('crm_stage'), v_tenant_a, tests.fixture('crm_pipeline'), 'Qualified', 1, false, null)
    on conflict (id) do update set name = excluded.name;

    insert into public.crm_contacts (id, tenant_id, first_name, last_name, email, status, owner_user_id)
    values (
        tests.fixture('crm_contact'),
        v_tenant_a,
        'Integration',
        'Contact',
        'crm-contact@test.local',
        'active',
        v_user_a
    )
    on conflict (id) do update set email = excluded.email;

    insert into public.crm_companies (id, tenant_id, name, owner_user_id)
    values (tests.fixture('crm_company'), v_tenant_a, '__integration_test__ Company', v_user_a)
    on conflict (id) do update set name = excluded.name;

    insert into public.crm_leads (id, tenant_id, first_name, last_name, status, owner_user_id)
    values (tests.fixture('crm_lead'), v_tenant_a, 'Integration', 'Lead', 'new', v_user_a)
    on conflict (id) do update set first_name = excluded.first_name;

    insert into public.crm_opportunities (
        id, tenant_id, pipeline_id, stage_id, contact_id, company_id, name, status, owner_user_id
    )
    values (
        tests.fixture('crm_opp'),
        v_tenant_a,
        tests.fixture('crm_pipeline'),
        tests.fixture('crm_stage'),
        tests.fixture('crm_contact'),
        tests.fixture('crm_company'),
        '__integration_test__ Opportunity',
        'open',
        v_user_a
    )
    on conflict (id) do update set name = excluded.name;

    -- layer 12: optimization (012)
    insert into public.optimization_rules (id, tenant_id, rule_name, category, rule_config, is_active)
    values (
        tests.fixture('opt_rule'),
        v_tenant_a,
        '__integration_test__ Rule',
        'energy',
        '{"threshold":0.8}'::jsonb,
        true
    )
    on conflict (id) do update set rule_name = excluded.rule_name;

    insert into public.insight_events (id, tenant_id, property_id, insight_type, severity, message, metadata)
    values (
        tests.fixture('insight_event'),
        v_tenant_a,
        tests.fixture('property_a'),
        'usage_pattern',
        'medium',
        'Integration test insight',
        '{"source":"integration_test"}'::jsonb
    )
    on conflict (id) do update set metadata = excluded.metadata;

    -- layer 13: platform cross-bind (014) — payment intent
    insert into platform.payment_intents (
        id, tenant_id, provider, amount, currency, status, target_type, target_id
    )
    values (
        tests.fixture('payment_intent'),
        v_tenant_a,
        'stripe',
        49.00,
        'EUR',
        'pending',
        'subscription',
        tests.fixture('subscription_a')
    )
    on conflict (id) do update set status = excluded.status;

    -- 013 service activation (014 sync projection)
    perform platform.sync_service_activation_state();
end;
$$;
