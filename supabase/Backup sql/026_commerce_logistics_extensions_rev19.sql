-- =====================================================
-- 026_commerce_logistics_extensions_rev19.sql
-- 009 Commerce + 008 Logistics extensions
-- Domain SSOT: business logic extracted from Edge 020_edge_rpc_commerce_logistics_rev19.sql
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('026_commerce_logistics_extensions_rev19', 'REV19.DOMAIN.COMMERCE_LOGISTICS.EXT', false)
on conflict (version) do nothing;


create or replace function public.commerce_domain(
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
    v_plan record;
    v_sub record;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
        when 'list_product_plans' then

            select coalesce(
                jsonb_agg(to_jsonb(pp) order by pp.tier),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    p.id,
                    p.name,
                    p.description,
                    p.tier,
                    p.is_active,
                    p.created_at,
                    p.updated_at
                from public.product_plans p
                where p.is_active = true
            ) pp;

            return v_result;

        when 'get_product_plan' then

            select
                p.id,
                p.name,
                p.description,
                p.tier,
                p.is_active,
                p.created_at,
                p.updated_at
            into v_plan
            from public.product_plans p
            where p.id = coalesce(
                nullif(p_payload->>'id', '')::uuid,
                nullif(p_payload->>'plan_id', '')::uuid
            );

            if not found then
                raise exception 'Product plan not found';
            end if;

            select jsonb_build_object(
                'plan', to_jsonb(v_plan),
                'pricing', coalesce((
                    select jsonb_agg(to_jsonb(pr) order by pr.currency)
                    from (
                        select
                            pp.id,
                            pp.plan_id,
                            pp.currency,
                            pp.monthly_price,
                            pp.yearly_price,
                            pp.effective_from,
                            pp.created_at
                        from public.plan_pricing pp
                        where pp.plan_id = v_plan.id
                    ) pr
                ), '[]'::jsonb),
                'entitlements', coalesce((
                    select jsonb_agg(to_jsonb(fe) order by fe.feature_key)
                    from (
                        select
                            fe.id,
                            fe.plan_id,
                            fe.feature_key,
                            fe.enabled
                        from public.feature_entitlements fe
                        where fe.plan_id = v_plan.id
                    ) fe
                ), '[]'::jsonb)
            )
            into v_result;

            return v_result;

        when 'create_product_plan' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            insert into public.product_plans (
                name,
                description,
                tier,
                is_active
            )
            values (
                p_payload->>'name',
                p_payload->>'description',
                (p_payload->>'tier')::public.subscription_tier,
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                name,
                description,
                tier,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'product_plan.created',
                'product_plan',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_product_plan' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            update public.product_plans pp
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else pp.name
                end,
                description = case
                    when p_payload ? 'description' then p_payload->>'description'
                    else pp.description
                end,
                tier = case
                    when p_payload ? 'tier'
                        then (p_payload->>'tier')::public.subscription_tier
                    else pp.tier
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else pp.is_active
                end
            where pp.id = (p_payload->>'id')::uuid
            returning
                pp.id,
                pp.name,
                pp.description,
                pp.tier,
                pp.is_active,
                pp.created_at,
                pp.updated_at
            into v_row;

            if not found then
                raise exception 'Product plan not found';
            end if;

            perform platform.log_audit(
                'product_plan.updated',
                'product_plan',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_product_plan' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            delete from public.product_plans pp
            where pp.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Product plan not found';
            end if;

            perform platform.log_audit(
                'product_plan.deleted',
                'product_plan',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_plan_pricing' then

            select coalesce(
                jsonb_agg(to_jsonb(pr) order by pr.currency),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    pp.id,
                    pp.plan_id,
                    pp.currency,
                    pp.monthly_price,
                    pp.yearly_price,
                    pp.effective_from,
                    pp.created_at
                from public.plan_pricing pp
                where pp.plan_id = (p_payload->>'plan_id')::uuid
            ) pr;

            return v_result;

        when 'create_plan_pricing' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            insert into public.plan_pricing (
                plan_id,
                currency,
                monthly_price,
                yearly_price,
                effective_from
            )
            values (
                (p_payload->>'plan_id')::uuid,
                coalesce(p_payload->>'currency', 'EUR'),
                (p_payload->>'monthly_price')::numeric,
                (p_payload->>'yearly_price')::numeric,
                coalesce(
                    (p_payload->>'effective_from')::timestamptz,
                    now()
                )
            )
            returning
                id,
                plan_id,
                currency,
                monthly_price,
                yearly_price,
                effective_from,
                created_at
            into v_row;

            perform platform.log_audit(
                'plan_pricing.created',
                'plan_pricing',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_plan_pricing' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            update public.plan_pricing pp
            set
                currency = case
                    when p_payload ? 'currency' then p_payload->>'currency'
                    else pp.currency
                end,
                monthly_price = case
                    when p_payload ? 'monthly_price'
                        then (p_payload->>'monthly_price')::numeric
                    else pp.monthly_price
                end,
                yearly_price = case
                    when p_payload ? 'yearly_price'
                        then (p_payload->>'yearly_price')::numeric
                    else pp.yearly_price
                end,
                effective_from = case
                    when p_payload ? 'effective_from'
                        then (p_payload->>'effective_from')::timestamptz
                    else pp.effective_from
                end
            where pp.id = (p_payload->>'id')::uuid
            returning
                pp.id,
                pp.plan_id,
                pp.currency,
                pp.monthly_price,
                pp.yearly_price,
                pp.effective_from,
                pp.created_at
            into v_row;

            if not found then
                raise exception 'Plan pricing not found';
            end if;

            perform platform.log_audit(
                'plan_pricing.updated',
                'plan_pricing',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_plan_pricing' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            delete from public.plan_pricing pp
            where pp.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Plan pricing not found';
            end if;

            perform platform.log_audit(
                'plan_pricing.deleted',
                'plan_pricing',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_feature_entitlements' then

            select coalesce(
                jsonb_agg(to_jsonb(fe) order by fe.feature_key),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    f.id,
                    f.plan_id,
                    f.feature_key,
                    f.enabled
                from public.feature_entitlements f
                where f.plan_id = (p_payload->>'plan_id')::uuid
            ) fe;

            return v_result;

        when 'create_feature_entitlement' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            insert into public.feature_entitlements (
                plan_id,
                feature_key,
                enabled
            )
            values (
                (p_payload->>'plan_id')::uuid,
                p_payload->>'feature_key',
                coalesce((p_payload->>'enabled')::boolean, true)
            )
            returning
                id,
                plan_id,
                feature_key,
                enabled
            into v_row;

            perform platform.log_audit(
                'feature_entitlement.created',
                'feature_entitlement',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_feature_entitlement' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            update public.feature_entitlements fe
            set
                feature_key = case
                    when p_payload ? 'feature_key' then p_payload->>'feature_key'
                    else fe.feature_key
                end,
                enabled = case
                    when p_payload ? 'enabled'
                        then (p_payload->>'enabled')::boolean
                    else fe.enabled
                end
            where fe.id = (p_payload->>'id')::uuid
            returning
                fe.id,
                fe.plan_id,
                fe.feature_key,
                fe.enabled
            into v_row;

            if not found then
                raise exception 'Feature entitlement not found';
            end if;

            perform platform.log_audit(
                'feature_entitlement.updated',
                'feature_entitlement',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_feature_entitlement' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            delete from public.feature_entitlements fe
            where fe.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Feature entitlement not found';
            end if;

            perform platform.log_audit(
                'feature_entitlement.deleted',
                'feature_entitlement',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_upsell_rules' then
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(ur) order by ur.created_at),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    u.id,
                    u.tenant_id,
                    u.trigger_event,
                    u.recommended_plan_id,
                    u.rule_config,
                    u.is_active,
                    u.created_at
                from public.upsell_rules u
                where u.is_active = true
                  and (
                      u.tenant_id is null
                      or u.tenant_id = v_tid
                  )
                  and (
                      p_payload->>'trigger_event' is null
                      or u.trigger_event = (p_payload->>'trigger_event')::public.upsell_plan_trigger
                  )
            ) ur;

            return v_result;

        when 'create_upsell_rule' then
            v_tid := platform.current_tenant_id();

            insert into public.upsell_rules (
                tenant_id,
                trigger_event,
                recommended_plan_id,
                rule_config,
                is_active
            )
            values (
                v_tid,
                nullif(p_payload->>'trigger_event', '')::public.upsell_plan_trigger,
                nullif(p_payload->>'recommended_plan_id', '')::uuid,
                p_payload->'rule_config',
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                trigger_event,
                recommended_plan_id,
                rule_config,
                is_active,
                created_at
            into v_row;

            perform platform.log_audit(
                'upsell_rule.created',
                'upsell_rule',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_upsell_rule' then
            v_tid := platform.current_tenant_id();

            update public.upsell_rules u
            set
                trigger_event = case
                    when p_payload ? 'trigger_event'
                        then nullif(p_payload->>'trigger_event', '')::public.upsell_plan_trigger
                    else u.trigger_event
                end,
                recommended_plan_id = case
                    when p_payload ? 'recommended_plan_id'
                        then nullif(p_payload->>'recommended_plan_id', '')::uuid
                    else u.recommended_plan_id
                end,
                rule_config = case
                    when p_payload ? 'rule_config' then p_payload->'rule_config'
                    else u.rule_config
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else u.is_active
                end
            where u.id = (p_payload->>'id')::uuid
              and u.tenant_id = v_tid
            returning
                u.id,
                u.tenant_id,
                u.trigger_event,
                u.recommended_plan_id,
                u.rule_config,
                u.is_active,
                u.created_at
            into v_row;

            if not found then
                raise exception 'Upsell rule not found';
            end if;

            perform platform.log_audit(
                'upsell_rule.updated',
                'upsell_rule',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_upsell_rule' then
            v_tid := platform.current_tenant_id();

            delete from public.upsell_rules u
            where u.id = (p_payload->>'id')::uuid
              and u.tenant_id = v_tid;

            if not found then
                raise exception 'Upsell rule not found';
            end if;

            perform platform.log_audit(
                'upsell_rule.deleted',
                'upsell_rule',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'get_tenant_entitlements' then
            v_tid := platform.current_tenant_id();

            select s.plan_id, s.tier
            into v_sub
            from public.subscriptions s
            where s.tenant_id = v_tid;

            if not found then
                raise exception 'Subscription not found for tenant';
            end if;

            if v_sub.plan_id is null then
                return jsonb_build_object(
                    'tenant_id', v_tid,
                    'plan_id', null,
                    'tier', v_sub.tier,
                    'features', '[]'::jsonb
                );
            end if;

            select jsonb_build_object(
                'tenant_id', v_tid,
                'plan_id', v_sub.plan_id,
                'tier', v_sub.tier,
                'features', coalesce((
                    select jsonb_agg(to_jsonb(fe) order by fe.feature_key)
                    from (
                        select
                            f.id,
                            f.plan_id,
                            f.feature_key,
                            f.enabled
                        from public.feature_entitlements f
                        where f.plan_id = v_sub.plan_id
                          and f.enabled = true
                    ) fe
                ), '[]'::jsonb)
            )
            into v_result;

            return v_result;

        when 'change_plan' then
            v_result := public.commerce_change_subscription_plan(
                (p_payload->>'plan_id')::uuid
            );

            perform platform.log_audit(
                'subscription.plan_changed',
                'subscription',
                (v_result->>'subscription_id')::uuid,
                jsonb_build_object(
                    'plan_id', v_result->>'plan_id',
                    'tier', v_result->>'tier'
                )
            );

            return v_result;

        else
            raise exception 'unknown commerce operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.commerce_domain(text, jsonb) from public;
grant execute on function public.commerce_domain(text, jsonb) to authenticated, service_role;


create or replace function public.logistics_domain(
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
    v_template record;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
        when 'list_logistics_templates' then

            select coalesce(
                jsonb_agg(to_jsonb(lt) order by lt.name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    l.id,
                    l.tenant_id,
                    l.is_system,
                    l.name,
                    l.description,
                    l.is_active,
                    l.created_at,
                    l.updated_at
                from public.logistics_templates l
            ) lt;

            return v_result;

        when 'get_logistics_template' then

            select
                l.id,
                l.tenant_id,
                l.is_system,
                l.name,
                l.description,
                l.is_active,
                l.created_at,
                l.updated_at
            into v_template
            from public.logistics_templates l
            where l.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Logistics template not found';
            end if;

            select jsonb_build_object(
                'template', to_jsonb(v_template),
                'packages', coalesce((
                    select jsonb_agg(to_jsonb(pd) order by pd.name)
                    from (
                        select
                            p.id,
                            p.template_id,
                            p.device_bundle_id,
                            p.name,
                            p.description
                        from public.package_definitions p
                        where p.template_id = v_template.id
                    ) pd
                ), '[]'::jsonb)
            )
            into v_result;

            return v_result;

        when 'create_logistics_template' then
            v_tid := platform.current_tenant_id();

            insert into public.logistics_templates (
                tenant_id,
                is_system,
                name,
                description,
                is_active
            )
            values (
                v_tid,
                false,
                p_payload->>'name',
                p_payload->>'description',
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                is_system,
                name,
                description,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'logistics_template.created',
                'logistics_template',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_logistics_template' then
            v_tid := platform.current_tenant_id();

            update public.logistics_templates l
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else l.name
                end,
                description = case
                    when p_payload ? 'description' then p_payload->>'description'
                    else l.description
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else l.is_active
                end
            where l.id = (p_payload->>'id')::uuid
              and l.is_system = false
            returning
                l.id,
                l.tenant_id,
                l.is_system,
                l.name,
                l.description,
                l.is_active,
                l.created_at,
                l.updated_at
            into v_row;

            if not found then
                raise exception 'Logistics template not found';
            end if;

            perform platform.log_audit(
                'logistics_template.updated',
                'logistics_template',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_logistics_template' then
            v_tid := platform.current_tenant_id();

            delete from public.logistics_templates l
            where l.id = (p_payload->>'id')::uuid
              and l.is_system = false;

            if not found then
                raise exception 'Logistics template not found';
            end if;

            perform platform.log_audit(
                'logistics_template.deleted',
                'logistics_template',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_package_definitions' then

            select coalesce(
                jsonb_agg(to_jsonb(pd) order by pd.name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    p.id,
                    p.template_id,
                    p.device_bundle_id,
                    p.name,
                    p.description
                from public.package_definitions p
                where p.template_id = (p_payload->>'template_id')::uuid
            ) pd;

            return v_result;

        when 'create_package_definition' then
            v_tid := platform.current_tenant_id();

            insert into public.package_definitions (
                template_id,
                device_bundle_id,
                name,
                description
            )
            values (
                (p_payload->>'template_id')::uuid,
                (p_payload->>'device_bundle_id')::uuid,
                p_payload->>'name',
                p_payload->>'description'
            )
            returning
                id,
                template_id,
                device_bundle_id,
                name,
                description
            into v_row;

            perform platform.log_audit(
                'package_definition.created',
                'package_definition',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_package_definition' then
            v_tid := platform.current_tenant_id();

            update public.package_definitions p
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else p.name
                end,
                description = case
                    when p_payload ? 'description' then p_payload->>'description'
                    else p.description
                end
            where p.id = (p_payload->>'id')::uuid
            returning
                p.id,
                p.template_id,
                p.device_bundle_id,
                p.name,
                p.description
            into v_row;

            if not found then
                raise exception 'Package definition not found';
            end if;

            perform platform.log_audit(
                'package_definition.updated',
                'package_definition',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_package_definition' then
            v_tid := platform.current_tenant_id();

            delete from public.package_definitions p
            where p.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Package definition not found';
            end if;

            perform platform.log_audit(
                'package_definition.deleted',
                'package_definition',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_carriers' then

            select coalesce(
                jsonb_agg(to_jsonb(c) order by c.name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    sc.id,
                    sc.name,
                    sc.provider_code,
                    sc.is_active,
                    sc.created_at
                from public.shipping_carriers sc
                where sc.is_active = true
            ) c;

            return v_result;

        when 'get_carrier' then

            select
                sc.id,
                sc.name,
                sc.provider_code,
                sc.is_active,
                sc.created_at
            into v_row
            from public.shipping_carriers sc
            where sc.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Shipping carrier not found';
            end if;

            return to_jsonb(v_row);

        when 'create_carrier' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            insert into public.shipping_carriers (
                name,
                provider_code,
                is_active
            )
            values (
                p_payload->>'name',
                p_payload->>'provider_code',
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                name,
                provider_code,
                is_active,
                created_at
            into v_row;

            perform platform.log_audit(
                'shipping_carrier.created',
                'shipping_carrier',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_carrier' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            update public.shipping_carriers sc
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else sc.name
                end,
                provider_code = case
                    when p_payload ? 'provider_code' then p_payload->>'provider_code'
                    else sc.provider_code
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else sc.is_active
                end
            where sc.id = (p_payload->>'id')::uuid
            returning
                sc.id,
                sc.name,
                sc.provider_code,
                sc.is_active,
                sc.created_at
            into v_row;

            if not found then
                raise exception 'Shipping carrier not found';
            end if;

            perform platform.log_audit(
                'shipping_carrier.updated',
                'shipping_carrier',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_carrier' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            delete from public.shipping_carriers sc
            where sc.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Shipping carrier not found';
            end if;

            perform platform.log_audit(
                'shipping_carrier.deleted',
                'shipping_carrier',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_warehouses' then

            select coalesce(
                jsonb_agg(to_jsonb(w) order by w.name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    wh.id,
                    wh.tenant_id,
                    wh.is_system,
                    wh.name,
                    wh.address,
                    wh.country_code,
                    wh.default_carrier_id,
                    wh.is_active,
                    wh.created_at,
                    wh.updated_at
                from public.warehouses wh
            ) w;

            return v_result;

        when 'get_warehouse' then

            select
                wh.id,
                wh.tenant_id,
                wh.is_system,
                wh.name,
                wh.address,
                wh.country_code,
                wh.default_carrier_id,
                wh.is_active,
                wh.created_at,
                wh.updated_at
            into v_row
            from public.warehouses wh
            where wh.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Warehouse not found';
            end if;

            return to_jsonb(v_row);

        when 'create_warehouse' then
            v_tid := platform.current_tenant_id();

            insert into public.warehouses (
                tenant_id,
                is_system,
                name,
                address,
                country_code,
                default_carrier_id,
                is_active
            )
            values (
                v_tid,
                false,
                p_payload->>'name',
                p_payload->>'address',
                coalesce(p_payload->>'country_code', 'GR'),
                nullif(p_payload->>'default_carrier_id', '')::uuid,
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                is_system,
                name,
                address,
                country_code,
                default_carrier_id,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'warehouse.created',
                'warehouse',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_warehouse' then
            v_tid := platform.current_tenant_id();

            update public.warehouses wh
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else wh.name
                end,
                address = case
                    when p_payload ? 'address' then p_payload->>'address'
                    else wh.address
                end,
                country_code = case
                    when p_payload ? 'country_code' then p_payload->>'country_code'
                    else wh.country_code
                end,
                default_carrier_id = case
                    when p_payload ? 'default_carrier_id'
                        then nullif(p_payload->>'default_carrier_id', '')::uuid
                    else wh.default_carrier_id
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else wh.is_active
                end
            where wh.id = (p_payload->>'id')::uuid
              and wh.is_system = false
            returning
                wh.id,
                wh.tenant_id,
                wh.is_system,
                wh.name,
                wh.address,
                wh.country_code,
                wh.default_carrier_id,
                wh.is_active,
                wh.created_at,
                wh.updated_at
            into v_row;

            if not found then
                raise exception 'Warehouse not found';
            end if;

            perform platform.log_audit(
                'warehouse.updated',
                'warehouse',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_warehouse' then
            v_tid := platform.current_tenant_id();

            delete from public.warehouses wh
            where wh.id = (p_payload->>'id')::uuid
              and wh.is_system = false;

            if not found then
                raise exception 'Warehouse not found';
            end if;

            perform platform.log_audit(
                'warehouse.deleted',
                'warehouse',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_label_templates' then

            select coalesce(
                jsonb_agg(to_jsonb(lt) order by lt.name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    sl.id,
                    sl.carrier_id,
                    sl.name,
                    sl.label_format,
                    sl.service_code,
                    sl.config,
                    sl.is_active,
                    sl.created_at,
                    sl.updated_at
                from public.shipping_label_templates sl
                where sl.is_active = true
                  and (
                      p_payload->>'carrier_id' is null
                      or sl.carrier_id = (p_payload->>'carrier_id')::uuid
                  )
            ) lt;

            return v_result;

        when 'create_label_template' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            insert into public.shipping_label_templates (
                carrier_id,
                name,
                label_format,
                service_code,
                config,
                is_active
            )
            values (
                (p_payload->>'carrier_id')::uuid,
                p_payload->>'name',
                coalesce(p_payload->>'label_format', 'pdf'),
                p_payload->>'service_code',
                coalesce(p_payload->'config', '{}'::jsonb),
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                carrier_id,
                name,
                label_format,
                service_code,
                config,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'shipping_label_template.created',
                'shipping_label_template',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_label_template' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            update public.shipping_label_templates sl
            set
                name = case
                    when p_payload ? 'name' then p_payload->>'name'
                    else sl.name
                end,
                label_format = case
                    when p_payload ? 'label_format' then p_payload->>'label_format'
                    else sl.label_format
                end,
                service_code = case
                    when p_payload ? 'service_code' then p_payload->>'service_code'
                    else sl.service_code
                end,
                config = case
                    when p_payload ? 'config' then p_payload->'config'
                    else sl.config
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else sl.is_active
                end
            where sl.id = (p_payload->>'id')::uuid
            returning
                sl.id,
                sl.carrier_id,
                sl.name,
                sl.label_format,
                sl.service_code,
                sl.config,
                sl.is_active,
                sl.created_at,
                sl.updated_at
            into v_row;

            if not found then
                raise exception 'Shipping label template not found';
            end if;

            perform platform.log_audit(
                'shipping_label_template.updated',
                'shipping_label_template',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_label_template' then
            if (select auth.uid()) is null then
                raise exception 'authentication required';
            end if;
            if not public.is_platform_admin() then
                raise exception 'platform admin role required';
            end if;

            delete from public.shipping_label_templates sl
            where sl.id = (p_payload->>'id')::uuid;

            if not found then
                raise exception 'Shipping label template not found';
            end if;

            perform platform.log_audit(
                'shipping_label_template.deleted',
                'shipping_label_template',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_shipping_rules' then

            select coalesce(
                jsonb_agg(to_jsonb(sr) order by sr.rule_name),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    s.id,
                    s.tenant_id,
                    s.is_system,
                    s.carrier_id,
                    s.rule_name,
                    s.rule_config,
                    s.is_active,
                    s.created_at,
                    s.updated_at
                from public.shipping_rules s
            ) sr;

            return v_result;

        when 'create_shipping_rule' then
            v_tid := platform.current_tenant_id();

            insert into public.shipping_rules (
                tenant_id,
                is_system,
                carrier_id,
                rule_name,
                rule_config,
                is_active
            )
            values (
                v_tid,
                false,
                nullif(p_payload->>'carrier_id', '')::uuid,
                p_payload->>'rule_name',
                coalesce(p_payload->'rule_config', '{}'::jsonb),
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                is_system,
                carrier_id,
                rule_name,
                rule_config,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'shipping_rule.created',
                'shipping_rule',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_shipping_rule' then
            v_tid := platform.current_tenant_id();

            update public.shipping_rules s
            set
                rule_name = case
                    when p_payload ? 'rule_name' then p_payload->>'rule_name'
                    else s.rule_name
                end,
                carrier_id = case
                    when p_payload ? 'carrier_id'
                        then nullif(p_payload->>'carrier_id', '')::uuid
                    else s.carrier_id
                end,
                rule_config = case
                    when p_payload ? 'rule_config' then p_payload->'rule_config'
                    else s.rule_config
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else s.is_active
                end
            where s.id = (p_payload->>'id')::uuid
              and s.is_system = false
            returning
                s.id,
                s.tenant_id,
                s.is_system,
                s.carrier_id,
                s.rule_name,
                s.rule_config,
                s.is_active,
                s.created_at,
                s.updated_at
            into v_row;

            if not found then
                raise exception 'Shipping rule not found';
            end if;

            perform platform.log_audit(
                'shipping_rule.updated',
                'shipping_rule',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_shipping_rule' then
            v_tid := platform.current_tenant_id();

            delete from public.shipping_rules s
            where s.id = (p_payload->>'id')::uuid
              and s.is_system = false;

            if not found then
                raise exception 'Shipping rule not found';
            end if;

            perform platform.log_audit(
                'shipping_rule.deleted',
                'shipping_rule',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_fulfilment_orders' then
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(fo) order by fo.created_at desc),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    f.id,
                    f.tenant_id,
                    f.property_id,
                    f.package_definition_id,
                    f.device_bundle_id,
                    f.carrier_id,
                    f.warehouse_id,
                    f.label_template_id,
                    f.customer_proposal_id,
                    f.status,
                    f.created_at,
                    f.updated_at
                from public.fulfilment_orders f
                where f.tenant_id = v_tid
                  and (
                      p_payload->>'status' is null
                      or f.status = (p_payload->>'status')::public.fulfilment_status
                  )
                  and (
                      p_payload->>'property_id' is null
                      or f.property_id = (p_payload->>'property_id')::uuid
                  )
            ) fo;

            return v_result;

        when 'get_fulfilment_order' then
            v_tid := platform.current_tenant_id();

            select
                f.id,
                f.tenant_id,
                f.property_id,
                f.package_definition_id,
                f.device_bundle_id,
                f.carrier_id,
                f.warehouse_id,
                f.label_template_id,
                f.customer_proposal_id,
                f.status,
                f.created_at,
                f.updated_at
            into v_row
            from public.fulfilment_orders f
            where f.id = (p_payload->>'id')::uuid
              and f.tenant_id = v_tid;

            if not found then
                raise exception 'Fulfilment order not found';
            end if;

            return to_jsonb(v_row);

        when 'create_fulfilment_order' then
            v_tid := platform.current_tenant_id();

            insert into public.fulfilment_orders (
                tenant_id,
                property_id,
                package_definition_id,
                device_bundle_id,
                carrier_id,
                warehouse_id,
                label_template_id,
                customer_proposal_id,
                status
            )
            values (
                v_tid,
                (p_payload->>'property_id')::uuid,
                nullif(p_payload->>'package_definition_id', '')::uuid,
                nullif(p_payload->>'device_bundle_id', '')::uuid,
                nullif(p_payload->>'carrier_id', '')::uuid,
                nullif(p_payload->>'warehouse_id', '')::uuid,
                nullif(p_payload->>'label_template_id', '')::uuid,
                nullif(p_payload->>'customer_proposal_id', '')::uuid,
                coalesce(
                    (p_payload->>'status')::public.fulfilment_status,
                    'draft'::public.fulfilment_status
                )
            )
            returning
                id,
                tenant_id,
                property_id,
                package_definition_id,
                device_bundle_id,
                carrier_id,
                warehouse_id,
                label_template_id,
                customer_proposal_id,
                status,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'fulfilment_order.created',
                'fulfilment_order',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_fulfilment_order' then
            v_tid := platform.current_tenant_id();

            update public.fulfilment_orders f
            set
                property_id = case
                    when p_payload ? 'property_id'
                        then (p_payload->>'property_id')::uuid
                    else f.property_id
                end,
                package_definition_id = case
                    when p_payload ? 'package_definition_id'
                        then nullif(p_payload->>'package_definition_id', '')::uuid
                    else f.package_definition_id
                end,
                device_bundle_id = case
                    when p_payload ? 'device_bundle_id'
                        then nullif(p_payload->>'device_bundle_id', '')::uuid
                    else f.device_bundle_id
                end,
                carrier_id = case
                    when p_payload ? 'carrier_id'
                        then nullif(p_payload->>'carrier_id', '')::uuid
                    else f.carrier_id
                end,
                warehouse_id = case
                    when p_payload ? 'warehouse_id'
                        then nullif(p_payload->>'warehouse_id', '')::uuid
                    else f.warehouse_id
                end,
                label_template_id = case
                    when p_payload ? 'label_template_id'
                        then nullif(p_payload->>'label_template_id', '')::uuid
                    else f.label_template_id
                end,
                customer_proposal_id = case
                    when p_payload ? 'customer_proposal_id'
                        then nullif(p_payload->>'customer_proposal_id', '')::uuid
                    else f.customer_proposal_id
                end,
                status = case
                    when p_payload ? 'status'
                        then (p_payload->>'status')::public.fulfilment_status
                    else f.status
                end
            where f.id = (p_payload->>'id')::uuid
              and f.tenant_id = v_tid
            returning
                f.id,
                f.tenant_id,
                f.property_id,
                f.package_definition_id,
                f.device_bundle_id,
                f.carrier_id,
                f.warehouse_id,
                f.label_template_id,
                f.customer_proposal_id,
                f.status,
                f.created_at,
                f.updated_at
            into v_row;

            if not found then
                raise exception 'Fulfilment order not found';
            end if;

            perform platform.log_audit(
                'fulfilment_order.updated',
                'fulfilment_order',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_fulfilment_order' then
            v_tid := platform.current_tenant_id();

            delete from public.fulfilment_orders f
            where f.id = (p_payload->>'id')::uuid
              and f.tenant_id = v_tid;

            if not found then
                raise exception 'Fulfilment order not found';
            end if;

            perform platform.log_audit(
                'fulfilment_order.deleted',
                'fulfilment_order',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'dispatch_fulfilment_order' then
            v_result := public.logistics_dispatch_fulfilment_order(
                (p_payload->>'fulfilment_order_id')::uuid,
                coalesce(p_payload->'payload', '{}'::jsonb)
            );

            perform platform.log_audit(
                'fulfilment_order.dispatch_queued',
                'fulfilment_order',
                (v_result->>'fulfilment_order_id')::uuid,
                jsonb_build_object(
                    'dispatch_queue_id', v_result->>'dispatch_queue_id'
                )
            );

            return v_result;

        else
            raise exception 'unknown logistics operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.logistics_domain(text, jsonb) from public;
grant execute on function public.logistics_domain(text, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- 009 Commerce: subscription plan change (002 binding)
-- -----------------------------------------------------

create or replace function public.commerce_change_subscription_plan(p_plan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_sub record;
begin
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

revoke all on function public.commerce_change_subscription_plan(uuid) from public;
grant execute on function public.commerce_change_subscription_plan(uuid) to authenticated, service_role;

-- -----------------------------------------------------
-- 008 Logistics: fulfilment dispatch workflow
-- -----------------------------------------------------

create or replace function public.logistics_dispatch_fulfilment_order(
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

revoke all on function public.logistics_dispatch_fulfilment_order(uuid, jsonb) from public;
grant execute on function public.logistics_dispatch_fulfilment_order(uuid, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- 013 Monetization: proposal status timestamps
-- -----------------------------------------------------

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
