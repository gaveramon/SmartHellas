-- =====================================================
-- 029_edge_api_thin_wrappers_rev19.sql
-- Pure Edge API layer: guards only, delegates to *_domain SSOT
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('029_edge_api_thin_wrappers_rev19', 'REV19.EDGE.API.THIN', false)
on conflict (version) do nothing;


create or replace function public.devices_api(
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
        when 'list_properties', 'get_property', 'list_rooms', 'get_room', 'list_device_categories', 'list_devices', 'get_device', 'get_device_config' then
            perform public.edge_require_tenant();
        when 'create_property', 'update_property', 'delete_property', 'create_room', 'update_room', 'delete_room', 'create_device', 'update_device', 'delete_device', 'assign_device', 'unassign_device', 'upsert_device_config' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown devices_api operation: %', p_op;
    end case;

    return public.devices_domain(p_op, p_payload);
end;
$$;

revoke all on function public.devices_api(text, jsonb) from public;
grant execute on function public.devices_api(text, jsonb) to authenticated, service_role;


create or replace function public.booking_api(
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
        when 'list_bookings', 'get_booking', 'get_access_schedule', 'get_booking_access', 'list_access_policies', 'list_access_rules' then
            perform public.edge_require_tenant();
        when 'create_booking', 'update_booking', 'delete_booking', 'upsert_access_schedule', 'create_booking_access', 'delete_booking_access', 'create_access_policy', 'update_access_policy', 'delete_access_policy', 'create_access_rule', 'update_access_rule', 'delete_access_rule' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown booking_api operation: %', p_op;
    end case;

    return public.booking_domain(p_op, p_payload);
end;
$$;

revoke all on function public.booking_api(text, jsonb) from public;
grant execute on function public.booking_api(text, jsonb) to authenticated, service_role;


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
        when 'list_lock_devices', 'get_lock_device', 'list_credentials', 'get_credential' then
            perform public.edge_require_tenant();
        when 'create_lock_device', 'update_lock_device', 'delete_lock_device', 'issue_credential', 'revoke_credential' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown locks_api operation: %', p_op;
    end case;

    return public.locks_domain(p_op, p_payload);
end;
$$;

revoke all on function public.locks_api(text, jsonb) from public;
grant execute on function public.locks_api(text, jsonb) to authenticated, service_role;


create or replace function public.commerce_api(
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
        when 'list_product_plans', 'get_product_plan', 'list_plan_pricing', 'list_feature_entitlements', 'list_upsell_rules', 'get_tenant_entitlements' then
            perform public.edge_require_tenant();
        when 'create_upsell_rule', 'update_upsell_rule', 'delete_upsell_rule' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown commerce_api operation: %', p_op;
    end case;

    return public.commerce_domain(p_op, p_payload);
end;
$$;

revoke all on function public.commerce_api(text, jsonb) from public;
grant execute on function public.commerce_api(text, jsonb) to authenticated, service_role;


create or replace function public.logistics_api(
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
        when 'list_logistics_templates', 'get_logistics_template', 'list_package_definitions', 'list_carriers', 'get_carrier', 'list_warehouses', 'get_warehouse', 'list_label_templates', 'list_shipping_rules', 'list_fulfilment_orders', 'get_fulfilment_order' then
            perform public.edge_require_tenant();
        when 'create_logistics_template', 'update_logistics_template', 'delete_logistics_template', 'create_package_definition', 'update_package_definition', 'delete_package_definition', 'create_warehouse', 'update_warehouse', 'delete_warehouse', 'create_shipping_rule', 'update_shipping_rule', 'delete_shipping_rule', 'create_fulfilment_order', 'update_fulfilment_order', 'delete_fulfilment_order' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown logistics_api operation: %', p_op;
    end case;

    return public.logistics_domain(p_op, p_payload);
end;
$$;

revoke all on function public.logistics_api(text, jsonb) from public;
grant execute on function public.logistics_api(text, jsonb) to authenticated, service_role;


create or replace function public.crm_api(
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
        when 'list_pipelines', 'get_pipeline', 'list_pipeline_stages', 'list_campaigns', 'get_campaign', 'list_tags', 'list_companies', 'get_company', 'list_contacts', 'get_contact', 'list_leads', 'get_lead', 'list_contact_companies', 'list_company_tenants', 'list_contact_tenants', 'list_opportunities', 'get_opportunity', 'list_tasks', 'get_task', 'list_interactions', 'list_notes', 'list_tag_assignments', 'list_lists', 'get_list', 'list_list_members', 'list_custom_fields', 'list_custom_field_values' then
            perform public.edge_require_tenant();
        when 'create_pipeline', 'update_pipeline', 'create_pipeline_stage', 'update_pipeline_stage', 'create_campaign', 'update_campaign', 'create_tag', 'update_tag', 'create_company', 'update_company', 'create_contact', 'update_contact', 'create_lead', 'update_lead', 'create_contact_company', 'update_contact_company', 'create_company_tenant', 'update_company_tenant', 'create_contact_tenant', 'update_contact_tenant', 'create_opportunity', 'update_opportunity', 'create_task', 'update_task', 'create_interaction', 'create_note', 'update_note', 'create_tag_assignment', 'create_list', 'update_list', 'create_list_member', 'create_custom_field', 'update_custom_field', 'upsert_custom_field_value', 'update_custom_field_value', 'delete_custom_field_value' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown crm_api operation: %', p_op;
    end case;

    return public.crm_domain(p_op, p_payload);
end;
$$;

revoke all on function public.crm_api(text, jsonb) from public;
grant execute on function public.crm_api(text, jsonb) to authenticated, service_role;


create or replace function public.portal_api(
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
        when 'get_portal_bootstrap', 'get_portal_settings', 'list_dashboards', 'get_dashboard', 'list_user_preferences', 'get_user_preference', 'upsert_user_preference', 'update_user_preference', 'delete_user_preference', 'list_feature_flags' then
            perform public.edge_require_tenant();
        when 'upsert_portal_settings', 'create_dashboard', 'update_dashboard', 'delete_dashboard', 'create_feature_flag', 'update_feature_flag', 'delete_feature_flag' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown portal_api operation: %', p_op;
    end case;

    return public.portal_domain(p_op, p_payload);
end;
$$;

revoke all on function public.portal_api(text, jsonb) from public;
grant execute on function public.portal_api(text, jsonb) to authenticated, service_role;


create or replace function public.onboarding_api(
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
        when 'list_sessions', 'get_session', 'list_step_states', 'list_room_mappings', 'list_device_mappings', 'list_checklist_items', 'list_notes' then
            perform public.edge_require_tenant();
        when 'create_session', 'update_session', 'delete_session', 'update_step_state', 'create_room_mapping', 'update_room_mapping', 'delete_room_mapping', 'create_device_mapping', 'update_device_mapping', 'delete_device_mapping', 'upsert_checklist_item', 'update_checklist_item', 'delete_checklist_item', 'create_note', 'delete_note' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown onboarding_api operation: %', p_op;
    end case;

    return public.onboarding_domain(p_op, p_payload);
end;
$$;

revoke all on function public.onboarding_api(text, jsonb) from public;
grant execute on function public.onboarding_api(text, jsonb) to authenticated, service_role;


create or replace function public.optimization_api(
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
        when 'list_rules', 'get_rule', 'list_insight_events', 'get_insight_event', 'list_recommendations', 'get_recommendation', 'list_device_usage_scores', 'list_energy_profiles', 'get_energy_profile', 'calculate_property_score' then
            perform public.edge_require_tenant();
        when 'create_rule', 'update_rule', 'delete_rule', 'update_recommendation', 'delete_recommendation' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown optimization_api operation: %', p_op;
    end case;

    return public.optimization_domain(p_op, p_payload);
end;
$$;

revoke all on function public.optimization_api(text, jsonb) from public;
grant execute on function public.optimization_api(text, jsonb) to authenticated, service_role;


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
        when 'list_proposals', 'get_proposal', 'list_proposal_items', 'list_packages', 'get_package', 'list_upsell_campaigns', 'get_upsell_campaign', 'update_upsell_campaign', 'delete_upsell_campaign', 'list_activation_state', 'list_conversion_events', 'list_conversion_scores' then
            perform public.edge_require_tenant();
        when 'create_proposal', 'update_proposal', 'delete_proposal', 'create_proposal_item', 'update_proposal_item', 'delete_proposal_item' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown monetization_api operation: %', p_op;
    end case;

    return public.monetization_domain(p_op, p_payload);
end;
$$;

revoke all on function public.monetization_api(text, jsonb) from public;
grant execute on function public.monetization_api(text, jsonb) to authenticated, service_role;


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
        when 'list_templates', 'get_template', 'list_workflows', 'get_workflow', 'list_workflow_steps', 'list_workflow_triggers', 'list_support_tickets', 'get_support_ticket', 'create_support_ticket', 'update_support_ticket', 'delete_support_ticket', 'list_support_messages', 'create_support_message' then
            perform public.edge_require_tenant();
        when 'create_template', 'update_template', 'delete_template', 'create_workflow', 'update_workflow', 'delete_workflow', 'create_workflow_step', 'update_workflow_step', 'delete_workflow_step', 'create_workflow_trigger', 'update_workflow_trigger', 'delete_workflow_trigger' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown operations_api operation: %', p_op;
    end case;

    return public.operations_domain(p_op, p_payload);
end;
$$;

revoke all on function public.operations_api(text, jsonb) from public;
grant execute on function public.operations_api(text, jsonb) to authenticated, service_role;


create or replace function public.preconfig_api(
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
        when 'list_device_bundles', 'get_device_bundle', 'list_bundle_devices', 'list_onboarding_blueprints', 'get_onboarding_blueprint', 'list_blueprint_steps', 'list_preconfig_templates', 'get_preconfig_template', 'list_preconfig_device_map' then
            perform public.edge_require_tenant();
        else
            raise exception 'unknown preconfig_api operation: %', p_op;
    end case;

    return public.preconfig_domain(p_op, p_payload);
end;
$$;

revoke all on function public.preconfig_api(text, jsonb) from public;
grant execute on function public.preconfig_api(text, jsonb) to authenticated, service_role;


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
        when 'list_providers', 'get_provider', 'list_capabilities', 'list_tenant_integrations', 'get_tenant_integration', 'list_webhook_definitions', 'list_device_maps' then
            perform public.edge_require_tenant();
        when 'connect_integration', 'update_integration', 'disconnect_integration', 'create_webhook_definition', 'update_webhook_definition', 'delete_webhook_definition', 'create_device_map', 'update_device_map', 'delete_device_map' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return public.integrations_domain(p_op, p_payload);
end;
$$;

revoke all on function public.integrations_api(text, jsonb) from public;
grant execute on function public.integrations_api(text, jsonb) to authenticated, service_role;


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
        when 'get_current_tenant', 'list_memberships', 'update_membership', 'revoke_membership', 'get_subscription', 'list_service_accounts' then
            perform public.edge_require_tenant();
        when 'update_tenant', 'update_subscription', 'create_service_account', 'update_service_account', 'delete_service_account' then
            perform public.edge_require_admin();
        else
            raise exception 'unknown auth_api operation: %', p_op;
    end case;

    return public.auth_domain(p_op, p_payload);
end;
$$;

revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;


create or replace function public.automation_api(
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
        when 'list_runs', 'get_run', 'list_run_steps' then
            perform public.edge_require_tenant();
        when 'dispatch_event', 'start_run', 'cancel_run' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown automation_api operation: %', p_op;
    end case;

    return public.automation_domain(p_op, p_payload);
end;
$$;

revoke all on function public.automation_api(text, jsonb) from public;
grant execute on function public.automation_api(text, jsonb) to authenticated, service_role;
