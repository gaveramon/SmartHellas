-- =====================================================
-- 050_rev20_baseline_consolidation.sql
-- REV20 production baseline: grant lockdown + SECURITY DEFINER hardening
-- + surgical production security fixes (locks, operations, OAuth, tenant create)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('050_rev20_baseline_consolidation', 'REV20.BASELINE.CONSOLIDATION', false)
on conflict (version) do nothing;


-- =====================================================
-- GRANT LOCKDOWN
-- Authenticated role: *_api entrypoints + infrastructure guards only
-- =====================================================


-- Revoke authenticated execute on non-API exposure surface

revoke all on function platform.has_tenant_membership(uuid, uuid) from public, authenticated;
grant execute on function platform.has_tenant_membership(uuid, uuid) to service_role;

revoke all on function public.auth_resolve_tenant_switch(uuid, uuid) from public, authenticated;
grant execute on function public.auth_resolve_tenant_switch(uuid, uuid) to service_role;

revoke all on function public.auth_switch_tenant(jsonb) from public, authenticated;
grant execute on function public.auth_switch_tenant(jsonb) to service_role;

revoke all on function public.auth_invite_member(jsonb) from public, authenticated;
grant execute on function public.auth_invite_member(jsonb) to service_role;

revoke all on function public.auth_domain(text, jsonb) from public, authenticated;
grant execute on function public.auth_domain(text, jsonb) to service_role;

revoke all on function public.auth_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.auth_domain_ext(text, jsonb) to service_role;

revoke all on function public.auth_domain_ext_031(text, jsonb) from public, authenticated;
grant execute on function public.auth_domain_ext_031(text, jsonb) to service_role;

revoke all on function public.integrations_oauth_url_encode(text) from public, authenticated;
grant execute on function public.integrations_oauth_url_encode(text) to service_role;

revoke all on function public.integrations_start_oauth(jsonb) from public, authenticated;
grant execute on function public.integrations_start_oauth(jsonb) to service_role;

revoke all on function public.integrations_domain(text, jsonb) from public, authenticated;
grant execute on function public.integrations_domain(text, jsonb) to service_role;

revoke all on function public.integrations_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.integrations_domain_ext(text, jsonb) to service_role;

revoke all on function public.booking_compute_access_window(uuid) from public, authenticated;
grant execute on function public.booking_compute_access_window(uuid) to service_role;

revoke all on function public.booking_calculate_access_window(uuid) from public, authenticated;
grant execute on function public.booking_calculate_access_window(uuid) to service_role;

revoke all on function public.booking_generate_booking_access(uuid) from public, authenticated;
grant execute on function public.booking_generate_booking_access(uuid) to service_role;

revoke all on function public.booking_regenerate_booking_access(uuid) from public, authenticated;
grant execute on function public.booking_regenerate_booking_access(uuid) to service_role;

revoke all on function public.booking_create_booking_access(jsonb) from public, authenticated;
grant execute on function public.booking_create_booking_access(jsonb) to service_role;

revoke all on function public.booking_domain(text, jsonb) from public, authenticated;
grant execute on function public.booking_domain(text, jsonb) to service_role;

revoke all on function public.locks_domain(text, jsonb) from public, authenticated;
grant execute on function public.locks_domain(text, jsonb) to service_role;

revoke all on function public.get_onboarding_lifecycle(uuid) from public, authenticated;
grant execute on function public.get_onboarding_lifecycle(uuid) to service_role;

revoke all on function public.list_onboarding_lifecycle_transitions(uuid) from public, authenticated;
grant execute on function public.list_onboarding_lifecycle_transitions(uuid) to service_role;

revoke all on function public.onboarding_lifecycle_transition(uuid, public.onboarding_lifecycle_state, jsonb) from public, authenticated;
grant execute on function public.onboarding_lifecycle_transition(uuid, public.onboarding_lifecycle_state, jsonb) to service_role;

revoke all on function public.create_property(text, public.property_type, text, text) from public, authenticated;
grant execute on function public.create_property(text, public.property_type, text, text) to service_role;

revoke all on function public.assign_device(uuid, uuid) from public, authenticated;
grant execute on function public.assign_device(uuid, uuid) to service_role;

revoke all on function public.generate_lock_code(uuid, uuid, timestamptz, timestamptz) from public, authenticated;
grant execute on function public.generate_lock_code(uuid, uuid, timestamptz, timestamptz) to service_role;

revoke all on function public.create_booking(uuid, date, date, text, text) from public, authenticated;
grant execute on function public.create_booking(uuid, date, date, text, text) to service_role;

revoke all on function public.onboarding_step_update(uuid, public.onboarding_step_type, public.onboarding_step_status) from public, authenticated;
grant execute on function public.onboarding_step_update(uuid, public.onboarding_step_type, public.onboarding_step_status) to service_role;

revoke all on function public.create_subscription(uuid, public.subscription_tier) from public, authenticated;
grant execute on function public.create_subscription(uuid, public.subscription_tier) to service_role;

revoke all on function public.log_event(text, jsonb) from public, authenticated;
grant execute on function public.log_event(text, jsonb) to service_role;

revoke all on function public.calculate_optimization_score(uuid) from public, authenticated;
grant execute on function public.calculate_optimization_score(uuid) to service_role;

revoke all on function public.generate_monetization_proposal(uuid, uuid) from public, authenticated;
grant execute on function public.generate_monetization_proposal(uuid, uuid) to service_role;

revoke all on function public.insert_event(text, jsonb, text, uuid, uuid) from public, authenticated;
grant execute on function public.insert_event(text, jsonb, text, uuid, uuid) to service_role;

revoke all on function public.assign_device_to_room(uuid, uuid) from public, authenticated;
grant execute on function public.assign_device_to_room(uuid, uuid) to service_role;

revoke all on function public.change_subscription_plan(uuid) from public, authenticated;
grant execute on function public.change_subscription_plan(uuid) to service_role;

revoke all on function public.dispatch_fulfilment_order(uuid, jsonb) from public, authenticated;
grant execute on function public.dispatch_fulfilment_order(uuid, jsonb) to service_role;

revoke all on function public.edge_soft_delete_row(regclass, uuid) from public, authenticated;
grant execute on function public.edge_soft_delete_row(regclass, uuid) to service_role;

revoke all on function public.automation_domain(text, jsonb) from public, authenticated;
grant execute on function public.automation_domain(text, jsonb) to service_role;

revoke all on function public.automation_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.automation_domain_ext(text, jsonb) to service_role;

revoke all on function public.automation_cancel_run(uuid) from public, authenticated;
grant execute on function public.automation_cancel_run(uuid) to service_role;

revoke all on function public.automation_start_run(uuid, public.automation_trigger_type, jsonb) from public, authenticated;
grant execute on function public.automation_start_run(uuid, public.automation_trigger_type, jsonb) to service_role;

revoke all on function public.automation_dispatch_event(text, jsonb) from public, authenticated;
grant execute on function public.automation_dispatch_event(text, jsonb) to service_role;

revoke all on function public.automation_enqueue_notification(jsonb) from public, authenticated;
grant execute on function public.automation_enqueue_notification(jsonb) to service_role;

revoke all on function public.commerce_domain(text, jsonb) from public, authenticated;
grant execute on function public.commerce_domain(text, jsonb) to service_role;

revoke all on function public.logistics_domain(text, jsonb) from public, authenticated;
grant execute on function public.logistics_domain(text, jsonb) to service_role;

revoke all on function public.crm_domain(text, jsonb) from public, authenticated;
grant execute on function public.crm_domain(text, jsonb) to service_role;

revoke all on function public.portal_domain(text, jsonb) from public, authenticated;
grant execute on function public.portal_domain(text, jsonb) to service_role;

revoke all on function public.onboarding_domain(text, jsonb) from public, authenticated;
grant execute on function public.onboarding_domain(text, jsonb) to service_role;

revoke all on function public.optimization_domain(text, jsonb) from public, authenticated;
grant execute on function public.optimization_domain(text, jsonb) to service_role;

revoke all on function public.monetization_domain(text, jsonb) from public, authenticated;
grant execute on function public.monetization_domain(text, jsonb) to service_role;

revoke all on function public.operations_domain(text, jsonb) from public, authenticated;
grant execute on function public.operations_domain(text, jsonb) to service_role;

revoke all on function public.preconfig_domain(text, jsonb) from public, authenticated;
grant execute on function public.preconfig_domain(text, jsonb) to service_role;

revoke all on function public.notification_domain(text, jsonb) from public, authenticated;
grant execute on function public.notification_domain(text, jsonb) to service_role;

revoke all on function public.payment_domain(text, jsonb) from public, authenticated;
grant execute on function public.payment_domain(text, jsonb) to service_role;

revoke all on function public.devices_domain(text, jsonb) from public, authenticated;
grant execute on function public.devices_domain(text, jsonb) to service_role;

revoke all on function public.devices_assign_device_to_room(uuid, uuid) from public, authenticated;
grant execute on function public.devices_assign_device_to_room(uuid, uuid) to service_role;

revoke all on function public.crm_soft_delete_row(regclass, uuid) from public, authenticated;
grant execute on function public.crm_soft_delete_row(regclass, uuid) to service_role;

revoke all on function public.commerce_change_subscription_plan(uuid) from public, authenticated;
grant execute on function public.commerce_change_subscription_plan(uuid) to service_role;

revoke all on function public.commerce_create_subscription(uuid, public.subscription_tier) from public, authenticated;
grant execute on function public.commerce_create_subscription(uuid, public.subscription_tier) to service_role;

revoke all on function public.logistics_dispatch_fulfilment_order(uuid, jsonb) from public, authenticated;
grant execute on function public.logistics_dispatch_fulfilment_order(uuid, jsonb) to service_role;

revoke all on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) from public, authenticated;
grant execute on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) to service_role;


-- Re-affirm authenticated *_api entrypoints

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;

revoke all on function public.booking_api(text, jsonb) from public;
grant execute on function public.booking_api(text, jsonb) to authenticated, service_role;

revoke all on function public.locks_api(text, jsonb) from public;
grant execute on function public.locks_api(text, jsonb) to authenticated, service_role;

revoke all on function public.commerce_api(text, jsonb) from public;
grant execute on function public.commerce_api(text, jsonb) to authenticated, service_role;

revoke all on function public.logistics_api(text, jsonb) from public;
grant execute on function public.logistics_api(text, jsonb) to authenticated, service_role;

revoke all on function public.crm_api(text, jsonb) from public;
grant execute on function public.crm_api(text, jsonb) to authenticated, service_role;

revoke all on function public.portal_api(text, jsonb) from public;
grant execute on function public.portal_api(text, jsonb) to authenticated, service_role;

revoke all on function public.onboarding_api(text, jsonb) from public;
grant execute on function public.onboarding_api(text, jsonb) to authenticated, service_role;

revoke all on function public.optimization_api(text, jsonb) from public;
grant execute on function public.optimization_api(text, jsonb) to authenticated, service_role;

revoke all on function public.monetization_api(text, jsonb) from public;
grant execute on function public.monetization_api(text, jsonb) to authenticated, service_role;

revoke all on function public.operations_api(text, jsonb) from public;
grant execute on function public.operations_api(text, jsonb) to authenticated, service_role;

revoke all on function public.preconfig_api(text, jsonb) from public;
grant execute on function public.preconfig_api(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;

revoke all on function public.automation_api(text, jsonb) from public;
grant execute on function public.automation_api(text, jsonb) to authenticated, service_role;

revoke all on function public.devices_api(text, jsonb) from public;
grant execute on function public.devices_api(text, jsonb) to authenticated, service_role;

revoke all on function public.payment_api(text, jsonb) from public;
grant execute on function public.payment_api(text, jsonb) to authenticated, service_role;

revoke all on function public.notification_api(text, jsonb) from public;
grant execute on function public.notification_api(text, jsonb) to authenticated, service_role;


-- Re-affirm infrastructure / RLS helper entrypoints

revoke all on function public.has_tenant_access(uuid) from public;
grant execute on function public.has_tenant_access(uuid) to authenticated, service_role;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated, service_role;

revoke all on function public.edge_require_tenant() from public;
grant execute on function public.edge_require_tenant() to authenticated, service_role;

revoke all on function public.edge_require_manager() from public;
grant execute on function public.edge_require_manager() to authenticated, service_role;

revoke all on function public.edge_require_admin() from public;
grant execute on function public.edge_require_admin() to authenticated, service_role;

revoke all on function platform.current_tenant_id() from public;
grant execute on function platform.current_tenant_id() to authenticated, service_role;

revoke all on function platform.current_role() from public;
grant execute on function platform.current_role() to authenticated, service_role;

revoke all on function platform.has_tenant_access(uuid) from public;
grant execute on function platform.has_tenant_access(uuid) to authenticated, service_role;

revoke all on function platform.has_role(text) from public;
grant execute on function platform.has_role(text) to authenticated, service_role;

revoke all on function platform.is_owner() from public;
grant execute on function platform.is_owner() to authenticated, service_role;

revoke all on function platform.is_admin() from public;
grant execute on function platform.is_admin() to authenticated, service_role;

revoke all on function platform.is_support() from public;
grant execute on function platform.is_support() to authenticated, service_role;

revoke all on function platform.has_permission(text) from public;
grant execute on function platform.has_permission(text) to authenticated, service_role;

revoke all on function platform.is_platform_admin() from public;
grant execute on function platform.is_platform_admin() to authenticated, service_role;

revoke all on function platform.storage_tenant_from_path(text) from public;
grant execute on function platform.storage_tenant_from_path(text) to authenticated, service_role;

revoke all on function platform.storage_user_from_path(text) from public;
grant execute on function platform.storage_user_from_path(text) to authenticated, service_role;


-- =====================================================
-- SECURITY DEFINER HARDENING
-- =====================================================

alter function platform._apply_platform_admin_rls(regclass) set search_path = '';
alter function platform._apply_tenant_rls(regclass) set search_path = '';
alter function platform._apply_tenant_rls_select_only(regclass) set search_path = '';
alter function platform.apply_payment_status(uuid, text, text, text, text, jsonb) set search_path = '';
alter function platform.bind_operation_context_type_column() set search_path = '';
alter function platform.complete_notification_delivery(uuid, boolean, jsonb) set search_path = '';
alter function platform.create_monthly_partition(base_table text, start_date date) set search_path = '';
alter function platform.create_vault_secret(text, text, text) set search_path = '';
alter function platform.current_role() set search_path = '';
alter function platform.current_tenant_id() set search_path = '';
alter function platform.current_user_email() set search_path = '';
alter function platform.current_user_id() set search_path = '';
alter function platform.dispatch_http_request(text, text, jsonb, jsonb, int) set search_path = '';
alter function platform.drop_old_log_partitions(text, interval) set search_path = '';
alter function platform.enable_realtime(regclass) set search_path = '';
alter function platform.enqueue_http_delivery(uuid, text, text, jsonb, jsonb, text, text) set search_path = '';
alter function platform.enqueue_shipment_dispatch(uuid, uuid, jsonb) set search_path = '';
alter function platform.ensure_log_partitions(int) set search_path = '';
alter function platform.ensure_pg_cron_jobs() set search_path = '';
alter function platform.execution_watchdog() set search_path = '';
alter function platform.fetch_external_webhook_batch(int) set search_path = '';
alter function platform.fetch_integration_queue_batch(int) set search_path = '';
alter function platform.fetch_next_command() set search_path = '';
alter function platform.fetch_notification_batch(int) set search_path = '';
alter function platform.fetch_retry_task_batch(int) set search_path = '';
alter function platform.fetch_shipment_dispatch_batch(int) set search_path = '';
alter function platform.get_device_command_context(uuid, uuid) set search_path = '';
alter function platform.get_identity() set search_path = '';
alter function platform.get_vault_secret(text) set search_path = '';
alter function platform.handle_new_auth_user() set search_path = '';
alter function platform.has_permission(permission text) set search_path = '';
alter function platform.has_role(required_role text) set search_path = '';
alter function platform.has_tenant_access(tid uuid) set search_path = '';
alter function platform.has_tenant_membership(uuid, uuid) set search_path = '';
alter function platform.ingest_external_webhook(text, text, text, jsonb, uuid, text) set search_path = '';
alter function platform.ingest_shipment_tracking_event(text, text, uuid, text, timestamptz, uuid, text, jsonb) set search_path = '';
alter function platform.is_admin() set search_path = '';
alter function platform.is_authenticated() set search_path = '';
alter function platform.is_owner() set search_path = '';
alter function platform.is_platform_admin() set search_path = '';
alter function platform.is_support() set search_path = '';
alter function platform.log_audit(text, text, uuid, jsonb) set search_path = '';
alter function platform.log_event(text, text, jsonb, text, uuid, uuid) set search_path = '';
alter function platform.log_operation(text, text, text, uuid, jsonb, jsonb, jsonb, uuid, text) set search_path = '';
alter function platform.mark_integration_queue_item(uuid, text, jsonb) set search_path = '';
alter function platform.mark_retry_task(uuid, text, int, text) set search_path = '';
alter function platform.mark_shipment_dispatch_failed(uuid, jsonb, int, int) set search_path = '';
alter function platform.mark_shipment_dispatched(uuid, text, text) set search_path = '';
alter function platform.move_to_dlq(uuid, text, jsonb) set search_path = '';
alter function platform.process_device_command_batch(int, text) set search_path = '';
alter function platform.process_external_webhook(uuid) set search_path = '';
alter function platform.process_external_webhook_batch(int) set search_path = '';
alter function platform.process_integration_queue() set search_path = '';
alter function platform.process_integration_queue_batch(int) set search_path = '';
alter function platform.process_notification_batch(int) set search_path = '';
alter function platform.process_payment_webhook(uuid) set search_path = '';
alter function platform.process_retry_task_batch(int) set search_path = '';
alter function platform.process_retry_tasks() set search_path = '';
alter function platform.process_shipment_dispatch_batch(int) set search_path = '';
alter function platform.process_shipment_dispatch_queue() set search_path = '';
alter function platform.publish_internal_event(text, text, jsonb, uuid) set search_path = '';
alter function platform.purge_expired_logs() set search_path = '';
alter function platform.push_integration_event(text, text, jsonb) set search_path = '';
alter function platform.rls_allow() set search_path = '';
alter function platform.rls_allow(uuid) set search_path = '';
alter function platform.rls_tenant_match(record_tenant_id uuid) set search_path = '';
alter function platform.run_platform_cron_tick() set search_path = '';
alter function platform.run_platform_daily_maintenance() set search_path = '';
alter function platform.schedule_retry_task(text, text, uuid, jsonb, text) set search_path = '';
alter function platform.sync_http_request(text, text, text, text, int) set search_path = '';
alter function platform.sync_service_activation_state() set search_path = '';
alter function platform.update_device_command_status(uuid, text, text, jsonb, jsonb) set search_path = '';
alter function platform.upsert_vault_secret(text, text, text) set search_path = '';
alter function public._apply_public_tenant_rls(regclass) set search_path = '';
alter function public.assign_device(uuid, uuid) set search_path = '';
alter function public.assign_device_to_room(uuid, uuid) set search_path = '';
alter function public.auth_api(text, jsonb) set search_path = '';
alter function public.auth_domain(text, jsonb) set search_path = '';
alter function public.auth_domain_ext(text, jsonb) set search_path = '';
alter function public.auth_domain_ext_031(text, jsonb) set search_path = '';
alter function public.auth_invite_member(jsonb) set search_path = '';
alter function public.auth_resolve_tenant_switch(uuid, uuid) set search_path = '';
alter function public.auth_switch_tenant(jsonb) set search_path = '';
alter function public.automation_api(text, jsonb) set search_path = '';
alter function public.automation_cancel_run(uuid) set search_path = '';
alter function public.automation_dispatch_event(text, jsonb) set search_path = '';
alter function public.automation_domain(text, jsonb) set search_path = '';
alter function public.automation_domain_ext(text, jsonb) set search_path = '';
alter function public.automation_enqueue_notification(jsonb) set search_path = '';
alter function public.automation_start_run(uuid, public.automation_trigger_type, jsonb) set search_path = '';
alter function public.booking_api(text, jsonb) set search_path = '';
alter function public.booking_calculate_access_window(uuid) set search_path = '';
alter function public.booking_compute_access_window(uuid) set search_path = '';
alter function public.booking_create_booking_access(jsonb) set search_path = '';
alter function public.booking_domain(text, jsonb) set search_path = '';
alter function public.booking_generate_booking_access(uuid) set search_path = '';
alter function public.booking_regenerate_booking_access(uuid) set search_path = '';
alter function public.calculate_optimization_score(uuid) set search_path = '';
alter function public.change_subscription_plan(uuid) set search_path = '';
alter function public.commerce_api(text, jsonb) set search_path = '';
alter function public.commerce_change_subscription_plan(uuid) set search_path = '';
alter function public.commerce_create_subscription(uuid, public.subscription_tier) set search_path = '';
alter function public.commerce_domain(text, jsonb) set search_path = '';
alter function public.create_booking(uuid, date, date, text, text) set search_path = '';
alter function public.create_property(text, public.property_type, text, text) set search_path = '';
alter function public.create_subscription(uuid, public.subscription_tier) set search_path = '';
alter function public.crm_api(text, jsonb) set search_path = '';
alter function public.crm_domain(text, jsonb) set search_path = '';
alter function public.crm_soft_delete_row(regclass, uuid) set search_path = '';
alter function public.devices_api(text, jsonb) set search_path = '';
alter function public.devices_assign_device_to_room(uuid, uuid) set search_path = '';
alter function public.devices_domain(text, jsonb) set search_path = '';
alter function public.dispatch_fulfilment_order(uuid, jsonb) set search_path = '';
alter function public.edge_require_admin() set search_path = '';
alter function public.edge_require_manager() set search_path = '';
alter function public.edge_require_tenant() set search_path = '';
alter function public.edge_soft_delete_row(regclass, uuid) set search_path = '';
alter function public.generate_lock_code(uuid, uuid, timestamptz, timestamptz) set search_path = '';
alter function public.generate_monetization_proposal(uuid, uuid) set search_path = '';
alter function public.get_onboarding_lifecycle(uuid) set search_path = '';
alter function public.handle_new_tenant() set search_path = '';
alter function public.has_tenant_access(uuid) set search_path = '';
alter function public.insert_event(text, jsonb, text, uuid, uuid) set search_path = '';
alter function public.integrations_api(text, jsonb) set search_path = '';
alter function public.integrations_complete_oauth(uuid, text, text) set search_path = '';
alter function public.integrations_complete_oauth(uuid, text, text, text) set search_path = '';
alter function public.integrations_domain(text, jsonb) set search_path = '';
alter function public.integrations_domain_ext(text, jsonb) set search_path = '';
alter function public.integrations_exchange_oauth_tokens(uuid, text, text, text) set search_path = '';
alter function public.integrations_oauth_complete(uuid, text, text) set search_path = '';
alter function public.integrations_oauth_complete(uuid, text, text, text) set search_path = '';
alter function public.integrations_oauth_complete_api(jsonb) set search_path = '';
alter function public.integrations_resolve_oauth_state(text) set search_path = '';
alter function public.integrations_start_oauth(jsonb) set search_path = '';
alter function public.is_platform_admin() set search_path = '';
alter function public.list_onboarding_lifecycle_transitions(uuid) set search_path = '';
alter function public.locks_api(text, jsonb) set search_path = '';
alter function public.locks_domain(text, jsonb) set search_path = '';
alter function public.log_event(text, jsonb) set search_path = '';
alter function public.logistics_api(text, jsonb) set search_path = '';
alter function public.logistics_dispatch_fulfilment_order(uuid, jsonb) set search_path = '';
alter function public.logistics_domain(text, jsonb) set search_path = '';
alter function public.monetization_api(text, jsonb) set search_path = '';
alter function public.monetization_domain(text, jsonb) set search_path = '';
alter function public.notification_api(text, jsonb) set search_path = '';
alter function public.notification_domain(text, jsonb) set search_path = '';
alter function public.notification_is_channel_enabled(uuid, uuid, public.notification_channel) set search_path = '';
alter function public.notification_resolve_template(uuid, text, public.notification_channel) set search_path = '';
alter function public.onboarding_api(text, jsonb) set search_path = '';
alter function public.onboarding_domain(text, jsonb) set search_path = '';
alter function public.onboarding_lifecycle_apply_transition(uuid, public.onboarding_lifecycle_state, jsonb) set search_path = '';
alter function public.onboarding_lifecycle_get(uuid) set search_path = '';
alter function public.onboarding_lifecycle_list_transitions(uuid) set search_path = '';
alter function public.onboarding_lifecycle_transition(uuid, public.onboarding_lifecycle_state, jsonb) set search_path = '';
alter function public.onboarding_step_update(uuid, public.onboarding_step_type, public.onboarding_step_status) set search_path = '';
alter function public.operations_api(text, jsonb) set search_path = '';
alter function public.operations_domain(text, jsonb) set search_path = '';
alter function public.optimization_api(text, jsonb) set search_path = '';
alter function public.optimization_domain(text, jsonb) set search_path = '';
alter function public.payment_api(text, jsonb) set search_path = '';
alter function public.payment_domain(text, jsonb) set search_path = '';
alter function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) set search_path = '';
alter function public.portal_api(text, jsonb) set search_path = '';
alter function public.portal_domain(text, jsonb) set search_path = '';
alter function public.preconfig_api(text, jsonb) set search_path = '';
alter function public.preconfig_domain(text, jsonb) set search_path = '';


-- =====================================================
-- PRODUCTION SECURITY FIXES (Option B — surgical guards only)
-- Tenant authority: REV21 only (051–053). Call edge_require_tenant(); defined in 052.
-- =====================================================

-- 1. locks_api: align credential read ops with 047 admin/manager intent
create or replace function public.locks_api(
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
        when 'list_lock_devices', 'get_lock_device' then
            perform public.edge_require_tenant();
        when 'list_credentials', 'get_credential' then
            perform public.edge_require_manager();
        when 'create_lock_device', 'update_lock_device', 'delete_lock_device', 'issue_credential', 'revoke_credential' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown locks_api operation: %', p_op;
    end case;

    return public.locks_domain(p_op, p_payload);
end;
$$;

-- 2. operations_api: restrict support ticket mutations to manager
create or replace function public.operations_api(
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
        when 'list_templates', 'get_template', 'list_workflows', 'get_workflow', 'list_workflow_steps', 'list_workflow_triggers', 'list_support_tickets', 'get_support_ticket', 'create_support_ticket', 'list_support_messages', 'create_support_message' then
            perform public.edge_require_tenant();
        when 'update_support_ticket', 'delete_support_ticket' then
            perform public.edge_require_manager();
        when 'create_template', 'update_template', 'delete_template', 'create_workflow', 'update_workflow', 'delete_workflow', 'create_workflow_step', 'update_workflow_step', 'delete_workflow_step', 'create_workflow_trigger', 'update_workflow_trigger', 'delete_workflow_trigger' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown operations_api operation: %', p_op;
    end case;

    return public.operations_domain(p_op, p_payload);
end;
$$;

-- 3. integrations_api: remove authenticated reachable complete_oauth bypass
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
        when 'complete_oauth' then
            raise exception 'complete_oauth is not available; use oauth_complete';
        when 'list_providers', 'get_provider', 'list_capabilities', 'list_webhook_definitions', 'list_device_maps' then
            perform public.edge_require_tenant();
        when 'list_tenant_integrations', 'get_tenant_integration' then
            perform public.edge_require_manager();
        when 'connect_integration', 'update_integration', 'disconnect_integration', 'create_webhook_definition', 'update_webhook_definition', 'delete_webhook_definition', 'create_device_map', 'update_device_map', 'delete_device_map', 'register_oauth_state', 'start_oauth', 'request_sync' then
            perform public.edge_require_manager();
        when 'resolve_oauth_state' then
            null;
        else
            raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return public.integrations_domain(p_op, p_payload);
end;
$$;

-- 5. auth_domain: mirror tenants_insert RLS owner-invariant on create_tenant
create or replace function public.auth_domain(
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
    v_uid uuid;
    v_row record;
    v_result jsonb;
    v_role text;
    v_tenant_status text;
    v_existing record;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'get_auth_context' then
        if v_uid is null then raise exception 'authentication required'; end if;
        v_tid := platform.current_tenant_id();
        v_role := platform.current_role();
        v_tenant_status := null;
        if v_tid is not null then
            select t.status::text into v_tenant_status
            from public.tenants t
            where t.id = v_tid;
        end if;
        v_result := jsonb_build_object(
            'user_id', v_uid,
            'email', (select p.email from platform.profiles p where p.id = v_uid),
            'tenant_id', v_tid,
            'role', v_role,
            'tenant_status', v_tenant_status,
            'is_platform_admin', platform.is_platform_admin()
        );

    when 'list_user_tenants' then
        if v_uid is null then raise exception 'authentication required'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.tenant_id, t.name as tenant_name, tm.role, tm.is_active, t.status as tenant_status, tm.created_at
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.user_id = v_uid and tm.is_active = true
        ) t;

    when 'get_current_tenant' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select to_jsonb(t) into v_result from (
            select tn.id, tn.name, tn.status, tn.created_at, tn.updated_at
            from public.tenants tn where tn.id = v_tid
        ) t;
        if v_result is null then raise exception 'Tenant not found'; end if;

    when 'create_tenant' then
        if v_uid is null then raise exception 'authentication required'; end if;
        if not platform.is_platform_admin()
           and public.resolve_active_tenant(v_uid) is not null
           and platform.is_owner() then
            raise exception 'User already has an active owner membership';
        end if;
        insert into public.tenants (name) values (p_payload->>'name')
        returning id, name, status, created_at, updated_at into v_row;
        perform platform.log_audit('tenant.created', 'tenant', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'created_by', v_uid));
        v_result := to_jsonb(v_row);

    when 'update_tenant' then
        perform public.edge_require_admin();
        v_tid := platform.current_tenant_id();
        update public.tenants tn set
            name = case when p_payload ? 'name' then p_payload->>'name' else tn.name end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.tenant_status else tn.status end
        where tn.id = v_tid
        returning tn.id, tn.name, tn.status, tn.created_at, tn.updated_at into v_row;
        if not found then raise exception 'Tenant not found'; end if;
        perform platform.log_audit('tenant.updated', 'tenant', v_tid, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_memberships' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at,
                   p.email, p.full_name, tm.created_at
            from public.tenant_memberships tm
            left join platform.profiles p on p.id = tm.user_id
            where tm.tenant_id = v_tid
        ) t;

    when 'update_membership' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select tm.id, tm.user_id, tm.tenant_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id = v_uid then
            if p_payload ? 'role' then raise exception 'Cannot change your own role via this endpoint'; end if;
        else
            perform public.edge_require_admin();
        end if;
        update public.tenant_memberships tm set
            role = case when p_payload ? 'role' then (p_payload->>'role')::public.user_role else tm.role end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else tm.is_active end,
            revoked_at = case
                when p_payload ? 'is_active' and not (p_payload->>'is_active')::boolean then now()
                when p_payload ? 'is_active' and (p_payload->>'is_active')::boolean then null
                else tm.revoked_at
            end
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid
        returning tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at, tm.created_at into v_row;
        if not found then raise exception 'Membership not found'; end if;
        perform platform.log_audit('membership.updated', 'tenant_membership', v_row.id, p_payload);
        select jsonb_build_object(
            'id', v_row.id,
            'user_id', v_row.user_id,
            'tenant_id', v_row.tenant_id,
            'role', v_row.role,
            'is_active', v_row.is_active,
            'revoked_at', v_row.revoked_at,
            'email', p.email,
            'full_name', p.full_name,
            'created_at', v_row.created_at
        ) into v_result
        from platform.profiles p where p.id = v_row.user_id;

    when 'revoke_membership' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select tm.id, tm.user_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id <> v_uid then perform public.edge_require_admin(); end if;
        delete from public.tenant_memberships tm where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        perform platform.log_audit('membership.revoked', 'tenant_membership', (p_payload->>'membership_id')::uuid,
            jsonb_build_object('tenant_id', v_tid, 'revoked_by', v_uid));
        v_result := jsonb_build_object('revoked', true, 'membership_id', p_payload->>'membership_id');

    when 'get_subscription' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select to_jsonb(t) into v_result from (
            select s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at
            from public.subscriptions s where s.tenant_id = v_tid
        ) t;

    when 'update_subscription' then
        perform public.edge_require_admin();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        if not exists (select 1 from public.subscriptions s where s.tenant_id = v_tid) then
            raise exception 'Subscription not found for tenant';
        end if;
        update public.subscriptions s set
            status = case when p_payload ? 'status' then (p_payload->>'status')::public.subscription_status else s.status end,
            current_period_start = case when p_payload ? 'current_period_start'
                then (p_payload->>'current_period_start')::timestamptz else s.current_period_start end,
            current_period_end = case when p_payload ? 'current_period_end'
                then (p_payload->>'current_period_end')::timestamptz else s.current_period_end end
        where s.tenant_id = v_tid
        returning s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at into v_row;
        perform platform.log_audit('subscription.updated', 'subscription', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_service_accounts' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at
            from public.service_accounts sa where sa.tenant_id = v_tid
        ) t;

    when 'create_service_account' then
        perform public.edge_require_admin();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        insert into public.service_accounts (tenant_id, name, provider_code, is_active)
        values (
            v_tid, p_payload->>'name', p_payload->>'provider_code',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, name, provider_code, is_active, created_at into v_row;
        perform platform.log_audit('service_account.created', 'service_account', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'provider_code', p_payload->>'provider_code'));
        v_result := to_jsonb(v_row);

    when 'update_service_account' then
        perform public.edge_require_admin();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        update public.service_accounts sa set
            name = case when p_payload ? 'name' then p_payload->>'name' else sa.name end,
            provider_code = case when p_payload ? 'provider_code' then p_payload->>'provider_code' else sa.provider_code end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else sa.is_active end
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid
        returning sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at into v_row;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.updated', 'service_account', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_service_account' then
        perform public.edge_require_admin();
        v_tid := platform.current_tenant_id();
        if v_tid is null then raise exception 'NO_ACTIVE_TENANT'; end if;
        delete from public.service_accounts sa
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.deleted', 'service_account', (p_payload->>'service_account_id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'service_account_id', p_payload->>'service_account_id');

    else
        return public.auth_domain_ext(p_op, p_payload);
    end case;

    return v_result;
end;
$$;


-- =====================================================
-- CONSOLIDATION NOTES
-- =====================================================
-- Supersedes scattered grant/revoke statements from 002–049.
-- Idempotent: safe to re-run on databases already partially hardened.
-- Edge handlers unchanged: all client traffic routes via {module}_api.
-- Domain *_domain / *_domain_ext / standalone mutators: service_role only.
-- Infrastructure guards retained per 11_edge_jobs_lockdown.mdc §10:
--   has_tenant_access, edge_require_manager, edge_require_admin
-- RLS helper functions (platform.current_* / has_role / is_*): retained for policy evaluation.
-- SECURITY DEFINER search_path reinforcement: defense-in-depth only (definitions already set in 000–049).
-- Production security fixes (Option B): locks_api credential guard, operations_api ticket guard,
-- integrations_api complete_oauth block, integrations_api credential read manager guard (H3),
-- auth_domain create_tenant owner invariant.
-- REV21 authority layer (edge_require_tenant, resolve_oauth_state bind): 051–053 only.
-- =====================================================
-- END 050 REV20 BASELINE CONSOLIDATION
-- =====================================================

