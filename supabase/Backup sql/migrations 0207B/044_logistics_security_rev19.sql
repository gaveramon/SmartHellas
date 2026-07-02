-- 044_logistics_security_rev19.sql
-- 008 Logistics Engine security hardening

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('044_logistics_security_rev19', 'REV19.SECURITY.LOGISTICS', false)
on conflict (version) do nothing;

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
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
                where l.tenant_id = v_tid
                   or l.is_system = true
            ) lt;

            return v_result;

        when 'get_logistics_template' then
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            where l.id = (p_payload->>'id')::uuid
              and (l.tenant_id = v_tid or l.is_system = true);

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
              and l.tenant_id = v_tid
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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

            delete from public.logistics_templates l
            where l.id = (p_payload->>'id')::uuid
              and l.is_system = false
              and l.tenant_id = v_tid;

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
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
                join public.logistics_templates lt on lt.id = p.template_id
                where p.template_id = (p_payload->>'template_id')::uuid
                  and (lt.tenant_id = v_tid or lt.is_system = true)
            ) pd;

            return v_result;

        when 'create_package_definition' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

            if not exists (
                select 1
                from public.logistics_templates lt
                where lt.id = (p_payload->>'template_id')::uuid
                  and lt.tenant_id = v_tid
                  and lt.is_system = false
            ) then
                raise exception 'Logistics template not found';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            from public.logistics_templates lt
            where p.id = (p_payload->>'id')::uuid
              and p.template_id = lt.id
              and lt.tenant_id = v_tid
              and lt.is_system = false
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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

            delete from public.package_definitions p
            using public.logistics_templates lt
            where p.id = (p_payload->>'id')::uuid
              and p.template_id = lt.id
              and lt.tenant_id = v_tid
              and lt.is_system = false;

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
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
                where wh.tenant_id = v_tid
                   or wh.is_system = true
            ) w;

            return v_result;

        when 'get_warehouse' then
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            where wh.id = (p_payload->>'id')::uuid
              and (wh.tenant_id = v_tid or wh.is_system = true);

            if not found then
                raise exception 'Warehouse not found';
            end if;

            return to_jsonb(v_row);

        when 'create_warehouse' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
              and wh.tenant_id = v_tid
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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

            delete from public.warehouses wh
            where wh.id = (p_payload->>'id')::uuid
              and wh.is_system = false
              and wh.tenant_id = v_tid;

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
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
                where s.tenant_id = v_tid
                   or s.is_system = true
            ) sr;

            return v_result;

        when 'create_shipping_rule' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
              and s.tenant_id = v_tid
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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

            delete from public.shipping_rules s
            where s.id = (p_payload->>'id')::uuid
              and s.is_system = false
              and s.tenant_id = v_tid;

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
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();
            if v_tid is null then
                raise exception 'no active tenant';
            end if;

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

-- Direct domain access revoked; callers must use logistics_api (017 Edge layer).
revoke all on function public.logistics_domain(text, jsonb) from public, authenticated;
grant execute on function public.logistics_domain(text, jsonb) to service_role;
