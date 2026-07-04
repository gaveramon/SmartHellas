-- =====================================================
-- 046_edge_api_security_rev19.sql
-- 017 Edge — API allowlist completion + guard hardening
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('046_edge_api_security_rev19', 'REV19.SECURITY.EDGE.API', false)
on conflict (version) do nothing;


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
        when 'switch_tenant' then
            return public.auth_switch_tenant(p_payload);
        when 'invite_member' then
            perform public.edge_require_tenant();
            perform public.edge_require_admin();
            return public.auth_invite_member(p_payload);
        when 'get_auth_context', 'list_user_tenants', 'create_tenant', 'validate_tenant_switch' then
            null;
        when 'resolve_user_by_email' then
            perform public.edge_require_tenant();
            perform public.edge_require_admin();
        when 'get_current_tenant', 'list_memberships', 'revoke_membership',
             'get_subscription', 'list_service_accounts' then
            perform public.edge_require_tenant();
        when 'update_membership' then
            perform public.edge_require_tenant();
        when 'update_tenant', 'update_subscription', 'create_service_account', 'update_service_account',
             'delete_service_account' then
            perform public.edge_require_admin();
        else
            raise exception 'unknown auth_api operation: %', p_op;
    end case;

    return public.auth_domain(p_op, p_payload);
end;
$$;


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
        when 'calculate_access_window' then
            perform public.edge_require_tenant();
            return public.booking_calculate_access_window((p_payload->>'booking_id')::uuid);

        when 'generate_booking_access', 'regenerate_booking_access' then
            perform public.edge_require_tenant();
            perform public.edge_require_manager();
            if p_op = 'generate_booking_access' then
                return public.booking_generate_booking_access((p_payload->>'booking_id')::uuid);
            end if;
            return public.booking_regenerate_booking_access((p_payload->>'booking_id')::uuid);

        when 'create_booking_access' then
            perform public.edge_require_tenant();
            perform public.edge_require_manager();
            return public.booking_create_booking_access(p_payload);

        when 'list_bookings', 'get_booking', 'get_access_schedule', 'get_booking_access',
             'list_access_policies', 'list_access_rules' then
            perform public.edge_require_tenant();
            return public.booking_domain(p_op, p_payload);

        when 'create_booking', 'update_booking', 'delete_booking', 'upsert_access_schedule',
             'delete_booking_access', 'create_access_policy', 'update_access_policy',
             'delete_access_policy', 'create_access_rule', 'update_access_rule',
             'delete_access_rule' then
            perform public.edge_require_manager();
            return public.booking_domain(p_op, p_payload);

        else
            raise exception 'unknown booking_api operation: %', p_op;
    end case;
end;
$$;


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
        when 'list_product_plans', 'get_product_plan', 'list_plan_pricing', 'list_feature_entitlements',
             'list_upsell_rules', 'get_tenant_entitlements' then
            perform public.edge_require_tenant();
        when 'create_product_plan', 'update_product_plan', 'delete_product_plan',
             'create_plan_pricing', 'update_plan_pricing', 'delete_plan_pricing',
             'create_feature_entitlement', 'update_feature_entitlement', 'delete_feature_entitlement' then
            if not platform.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;
        when 'create_upsell_rule', 'update_upsell_rule', 'delete_upsell_rule', 'change_plan' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown commerce_api operation: %', p_op;
    end case;

    return public.commerce_domain(p_op, p_payload);
end;
$$;


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
        when 'list_logistics_templates', 'get_logistics_template', 'list_package_definitions', 'list_carriers',
             'get_carrier', 'list_warehouses', 'get_warehouse', 'list_label_templates', 'list_shipping_rules',
             'list_fulfilment_orders', 'get_fulfilment_order' then
            perform public.edge_require_tenant();
        when 'create_logistics_template', 'update_logistics_template', 'delete_logistics_template',
             'create_package_definition', 'update_package_definition', 'delete_package_definition',
             'create_warehouse', 'update_warehouse', 'delete_warehouse',
             'create_shipping_rule', 'update_shipping_rule', 'delete_shipping_rule',
             'create_fulfilment_order', 'update_fulfilment_order', 'delete_fulfilment_order',
             'dispatch_fulfilment_order' then
            perform public.edge_require_manager();
        when 'create_carrier', 'update_carrier', 'delete_carrier',
             'create_label_template', 'update_label_template', 'delete_label_template' then
            if not platform.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;
        else
            raise exception 'unknown logistics_api operation: %', p_op;
    end case;

    return public.logistics_domain(p_op, p_payload);
end;
$$;


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
        when 'list_pipelines', 'get_pipeline', 'list_pipeline_stages', 'list_campaigns', 'get_campaign', 'list_tags',
             'list_companies', 'get_company', 'list_contacts', 'get_contact', 'list_leads', 'get_lead',
             'list_contact_companies', 'list_company_tenants', 'list_contact_tenants', 'list_opportunities',
             'get_opportunity', 'list_tasks', 'get_task', 'list_interactions', 'list_notes', 'list_tag_assignments',
             'list_lists', 'get_list', 'list_list_members', 'list_custom_fields', 'list_custom_field_values' then
            perform public.edge_require_tenant();
        when 'create_pipeline', 'update_pipeline', 'create_pipeline_stage', 'update_pipeline_stage',
             'create_campaign', 'update_campaign', 'create_tag', 'update_tag', 'create_company', 'update_company',
             'create_contact', 'update_contact', 'create_lead', 'update_lead', 'create_contact_company',
             'update_contact_company', 'create_company_tenant', 'update_company_tenant', 'create_contact_tenant',
             'update_contact_tenant', 'create_opportunity', 'update_opportunity', 'create_task', 'update_task',
             'create_interaction', 'create_note', 'update_note', 'create_tag_assignment', 'create_list', 'update_list',
             'create_list_member', 'create_custom_field', 'update_custom_field', 'upsert_custom_field_value',
             'update_custom_field_value', 'delete_custom_field_value', 'delete_pipeline', 'delete_pipeline_stage',
             'delete_campaign', 'delete_tag', 'delete_company', 'delete_contact', 'delete_lead',
             'delete_contact_company', 'delete_company_tenant', 'delete_contact_tenant', 'delete_opportunity',
             'delete_task', 'soft_delete_interaction', 'delete_note', 'delete_tag_assignment', 'delete_list',
             'delete_list_member', 'delete_custom_field' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown crm_api operation: %', p_op;
    end case;

    return public.crm_domain(p_op, p_payload);
end;
$$;


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
        when 'list_device_bundles', 'get_device_bundle', 'list_bundle_devices', 'list_onboarding_blueprints',
             'get_onboarding_blueprint', 'list_blueprint_steps', 'list_preconfig_templates', 'get_preconfig_template',
             'list_preconfig_device_map' then
            perform public.edge_require_tenant();
        when 'create_device_bundle', 'update_device_bundle', 'delete_device_bundle', 'create_bundle_device',
             'update_bundle_device', 'delete_bundle_device', 'create_onboarding_blueprint', 'update_onboarding_blueprint',
             'delete_onboarding_blueprint', 'create_blueprint_step', 'update_blueprint_step', 'delete_blueprint_step',
             'create_preconfig_template', 'update_preconfig_template', 'delete_preconfig_template',
             'create_preconfig_device_map', 'update_preconfig_device_map', 'delete_preconfig_device_map' then
            if not platform.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;
        else
            raise exception 'unknown preconfig_api operation: %', p_op;
    end case;

    return public.preconfig_domain(p_op, p_payload);
end;
$$;


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
             'list_upsell_campaigns', 'get_upsell_campaign', 'update_upsell_campaign', 'delete_upsell_campaign',
             'list_activation_state', 'list_conversion_events', 'list_conversion_scores' then
            perform public.edge_require_tenant();
        when 'create_proposal', 'update_proposal', 'delete_proposal', 'create_proposal_item', 'update_proposal_item',
             'delete_proposal_item' then
            perform public.edge_require_manager();
        when 'create_package', 'update_package', 'delete_package', 'create_upsell_campaign' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown monetization_api operation: %', p_op;
    end case;

    return public.monetization_domain(p_op, p_payload);
end;
$$;


revoke all on function public.auth_api(text, jsonb) from public;
grant execute on function public.auth_api(text, jsonb) to authenticated, service_role;

revoke all on function public.booking_api(text, jsonb) from public;
grant execute on function public.booking_api(text, jsonb) to authenticated, service_role;

revoke all on function public.commerce_api(text, jsonb) from public;
grant execute on function public.commerce_api(text, jsonb) to authenticated, service_role;

revoke all on function public.logistics_api(text, jsonb) from public;
grant execute on function public.logistics_api(text, jsonb) to authenticated, service_role;

revoke all on function public.crm_api(text, jsonb) from public;
grant execute on function public.crm_api(text, jsonb) to authenticated, service_role;

revoke all on function public.preconfig_api(text, jsonb) from public;
grant execute on function public.preconfig_api(text, jsonb) to authenticated, service_role;

revoke all on function public.monetization_api(text, jsonb) from public;
grant execute on function public.monetization_api(text, jsonb) to authenticated, service_role;
