-- =====================================================
-- SmartHellas integration test cleanup
-- Removes deterministic fixtures in reverse dependency order
-- Idempotent: safe when fixtures absent
-- =====================================================

create or replace function tests.cleanup_integration_fixtures()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tenant_a uuid := tests.fixture('tenant_a');
    v_tenant_b uuid := tests.fixture('tenant_b');
begin
    -- platform layer first
    delete from platform.payment_events where payment_intent_id = tests.fixture('payment_intent');
    delete from platform.payment_intents where id = tests.fixture('payment_intent');
    delete from platform.audit_log where tenant_id in (v_tenant_a, v_tenant_b);
    delete from platform.event_log where tenant_id in (v_tenant_a, v_tenant_b);

    -- explicit leaf rows with cross-tenant catalog refs
    delete from public.insight_events where id = tests.fixture('insight_event');
    delete from public.optimization_rules where id = tests.fixture('opt_rule');
    delete from public.crm_opportunities where id = tests.fixture('crm_opp');
    delete from public.crm_leads where id = tests.fixture('crm_lead');
    delete from public.crm_contacts where id = tests.fixture('crm_contact');
    delete from public.crm_companies where id = tests.fixture('crm_company');
    delete from public.crm_pipeline_stages where id = tests.fixture('crm_stage');
    delete from public.crm_pipelines where id = tests.fixture('crm_pipeline');
    delete from public.dashboard_configs where id = tests.fixture('dashboard');
    delete from public.tenant_portal_settings where id = tests.fixture('portal_settings');
    delete from public.proposal_items where id = tests.fixture('proposal_item');
    delete from public.customer_proposals where id = tests.fixture('proposal');
    delete from public.monetization_packages where id = tests.fixture('monet_package');
    delete from public.support_messages where id = tests.fixture('support_msg');
    delete from public.support_tickets where id = tests.fixture('support_ticket');
    delete from public.workflow_triggers where id = tests.fixture('workflow_trig');
    delete from public.workflow_steps where id = tests.fixture('workflow_step');
    delete from public.operation_workflows where id = tests.fixture('workflow');
    delete from public.operation_templates where id = tests.fixture('op_template');
    delete from public.fulfilment_orders where id = tests.fixture('fulfilment');
    delete from public.package_definitions where id = tests.fixture('package_def');
    delete from public.logistics_templates where id = tests.fixture('logistics_tpl');
    delete from public.warehouses where id = tests.fixture('warehouse');
    delete from public.shipping_carriers where name = '__integration_test__ Carrier';
    delete from public.onboarding_step_state where id = tests.fixture('onboard_step');
    delete from public.onboarding_sessions where id = tests.fixture('onboard_session');
    delete from public.preconfig_templates where id = tests.fixture('preconfig_tpl');
    delete from public.onboarding_blueprint_steps where id = tests.fixture('onboard_bp_step');
    delete from public.onboarding_blueprints where id = tests.fixture('onboard_bp');
    delete from public.bundle_devices where id = tests.fixture('bundle_device');
    delete from public.device_bundles where id = tests.fixture('device_bundle');
    delete from public.access_credentials where id = tests.fixture('credential');
    delete from public.lock_devices where id = tests.fixture('lock_device');
    delete from public.booking_access where id = tests.fixture('booking_access');
    delete from public.bookings where id = tests.fixture('booking_a');
    delete from public.property_access_schedules where id = tests.fixture('access_sched');
    delete from public.device_assignments where id = tests.fixture('device_assign');
    delete from public.device_integration_map where id = tests.fixture('device_map');
    delete from public.devices where id in (tests.fixture('lock_dev'), tests.fixture('gateway_dev'));
    delete from public.rooms where id = tests.fixture('room_a');
    delete from public.properties where id in (tests.fixture('property_a'), tests.fixture('property_b'));
    delete from public.tenant_integrations where id = tests.fixture('tenant_integ');
    delete from public.subscriptions where id = tests.fixture('subscription_a');
    delete from public.feature_entitlements where id = tests.fixture('feature_ent');
    delete from public.plan_pricing where id = tests.fixture('plan_pricing_eur');
    delete from public.product_plans where id = tests.fixture('plan_pro');

    -- tenant cascade removes remaining memberships / service accounts
    delete from public.tenants where id in (v_tenant_a, v_tenant_b);

    delete from auth.users
    where id in (
        tests.fixture('user_a_owner'),
        tests.fixture('user_b_owner'),
        tests.fixture('user_a_viewer')
    );

    raise notice 'cleanup: integration fixtures removed';
end;
$$;

-- standalone execution
-- select tests.cleanup_integration_fixtures();
