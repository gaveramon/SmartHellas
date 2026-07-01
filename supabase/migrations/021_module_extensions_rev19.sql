-- =====================================================
-- 027_module_extensions_rev19.sql
-- 010–011–012–013–006–007–005–002 module extensions
-- Domain SSOT: business logic extracted from Edge 021_edge_rpc_modules_rev19.sql
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('027_module_extensions_rev19', 'REV19.DOMAIN.MODULES.EXT', false)
on conflict (version) do nothing;


create or replace function public.portal_domain(
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
    v_existing uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'get_portal_bootstrap' then
        v_tid := platform.current_tenant_id();
        select jsonb_build_object(
            'settings', (
                select to_jsonb(t) from (
                    select s.id, s.tenant_id, s.theme, s.default_language, s.created_at, s.updated_at
                    from public.tenant_portal_settings s where s.tenant_id = v_tid
                ) t
            ),
            'default_dashboard', (
                select to_jsonb(t) from (
                    select d.id, d.tenant_id, d.name, d.layout, d.is_default, d.created_at
                    from public.dashboard_configs d
                    where d.tenant_id = v_tid and d.is_default = true
                ) t
            ),
            'feature_flags', coalesce((
                select jsonb_agg(to_jsonb(f) order by f.feature_key)
                from (
                    select ff.id, ff.tenant_id, ff.feature_key, ff.enabled, ff.created_at
                    from public.portal_feature_flags ff where ff.tenant_id = v_tid
                ) f
            ), '[]'::jsonb)
        ) into v_result;

    when 'get_portal_settings' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select s.id, s.tenant_id, s.theme, s.default_language, s.created_at, s.updated_at
            from public.tenant_portal_settings s where s.tenant_id = v_tid
        ) t;

    when 'upsert_portal_settings' then
        v_tid := platform.current_tenant_id();
        select s.id into v_existing from public.tenant_portal_settings s where s.tenant_id = v_tid;
        if found then
            update public.tenant_portal_settings s set
                theme = case when p_payload ? 'theme' then p_payload->'theme' else s.theme end,
                default_language = case when p_payload ? 'default_language' then p_payload->>'default_language' else s.default_language end
            where s.tenant_id = v_tid
            returning s.id, s.tenant_id, s.theme, s.default_language, s.created_at, s.updated_at into v_row;
            perform platform.log_audit('portal_settings.updated', 'tenant_portal_settings', v_row.id, p_payload);
        else
            insert into public.tenant_portal_settings (tenant_id, theme, default_language)
            values (
                v_tid,
                case when p_payload ? 'theme' then p_payload->'theme' else null end,
                coalesce(p_payload->>'default_language', 'en')
            )
            returning id, tenant_id, theme, default_language, created_at, updated_at into v_row;
            perform platform.log_audit('portal_settings.created', 'tenant_portal_settings', v_row.id);
        end if;
        v_result := to_jsonb(v_row);

    when 'list_dashboards' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select d.id, d.tenant_id, d.name, d.layout, d.is_default, d.created_at
            from public.dashboard_configs d where d.tenant_id = v_tid
        ) t;

    when 'get_dashboard' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select d.id, d.tenant_id, d.name, d.layout, d.is_default, d.created_at
            from public.dashboard_configs d
            where d.id = (p_payload->>'id')::uuid and d.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Dashboard config not found'; end if;

    when 'create_dashboard' then
        v_tid := platform.current_tenant_id();
        if coalesce((p_payload->>'is_default')::boolean, false) then
            update public.dashboard_configs set is_default = false
            where tenant_id = v_tid and is_default = true;
        end if;
        insert into public.dashboard_configs (tenant_id, name, layout, is_default)
        values (
            v_tid,
            p_payload->>'name',
            case when p_payload ? 'layout' then p_payload->'layout' else null end,
            coalesce((p_payload->>'is_default')::boolean, false)
        )
        returning id, tenant_id, name, layout, is_default, created_at into v_row;
        perform platform.log_audit('dashboard_config.created', 'dashboard_config', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_dashboard' then
        v_tid := platform.current_tenant_id();
        if coalesce((p_payload->>'is_default')::boolean, false) then
            update public.dashboard_configs set is_default = false
            where tenant_id = v_tid and is_default = true;
        end if;
        update public.dashboard_configs d set
            name = case when p_payload ? 'name' then p_payload->>'name' else d.name end,
            layout = case when p_payload ? 'layout' then p_payload->'layout' else d.layout end,
            is_default = case when p_payload ? 'is_default' then (p_payload->>'is_default')::boolean else d.is_default end
        where d.id = (p_payload->>'id')::uuid and d.tenant_id = v_tid
        returning d.id, d.tenant_id, d.name, d.layout, d.is_default, d.created_at into v_row;
        if not found then raise exception 'Dashboard config not found'; end if;
        perform platform.log_audit('dashboard_config.updated', 'dashboard_config', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_dashboard' then
        v_tid := platform.current_tenant_id();
        delete from public.dashboard_configs d
        where d.id = (p_payload->>'id')::uuid and d.tenant_id = v_tid;
        if not found then raise exception 'Dashboard config not found'; end if;
        perform platform.log_audit('dashboard_config.deleted', 'dashboard_config', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_user_preferences' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.preference_key), '[]'::jsonb) into v_result
        from (
            select p.id, p.tenant_id, p.user_id, p.preference_key, p.value, p.created_at, p.updated_at
            from public.portal_user_preferences p
            where p.tenant_id = v_tid and p.user_id = v_uid
        ) t;

    when 'get_user_preference' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select p.id, p.tenant_id, p.user_id, p.preference_key, p.value, p.created_at, p.updated_at
            from public.portal_user_preferences p
            where p.tenant_id = v_tid and p.user_id = v_uid
              and p.preference_key = p_payload->>'preference_key'
        ) t;

    when 'upsert_user_preference' then
        v_tid := platform.current_tenant_id();
        select p.id into v_existing from public.portal_user_preferences p
        where p.tenant_id = v_tid and p.user_id = v_uid
          and p.preference_key = p_payload->>'preference_key';
        if found then
            update public.portal_user_preferences p set value = p_payload->'value'
            where p.id = v_existing
            returning p.id, p.tenant_id, p.user_id, p.preference_key, p.value, p.created_at, p.updated_at into v_row;
        else
            insert into public.portal_user_preferences (tenant_id, user_id, preference_key, value)
            values (v_tid, v_uid, p_payload->>'preference_key', p_payload->'value')
            returning id, tenant_id, user_id, preference_key, value, created_at, updated_at into v_row;
        end if;
        v_result := to_jsonb(v_row);

    when 'update_user_preference' then
        v_tid := platform.current_tenant_id();
        update public.portal_user_preferences p set
            value = case when p_payload ? 'value' then p_payload->'value' else p.value end
        where p.tenant_id = v_tid and p.user_id = v_uid
          and p.preference_key = p_payload->>'preference_key'
        returning p.id, p.tenant_id, p.user_id, p.preference_key, p.value, p.created_at, p.updated_at into v_row;
        if not found then raise exception 'Preference not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_user_preference' then
        v_tid := platform.current_tenant_id();
        delete from public.portal_user_preferences p
        where p.tenant_id = v_tid and p.user_id = v_uid
          and p.preference_key = p_payload->>'preference_key';
        v_result := jsonb_build_object('deleted', true, 'preference_key', p_payload->>'preference_key');

    when 'list_feature_flags' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.feature_key), '[]'::jsonb) into v_result
        from (
            select ff.id, ff.tenant_id, ff.feature_key, ff.enabled, ff.created_at
            from public.portal_feature_flags ff where ff.tenant_id = v_tid
        ) t;

    when 'create_feature_flag' then
        v_tid := platform.current_tenant_id();
        insert into public.portal_feature_flags (tenant_id, feature_key, enabled)
        values (
            v_tid,
            p_payload->>'feature_key',
            coalesce((p_payload->>'enabled')::boolean, true)
        )
        returning id, tenant_id, feature_key, enabled, created_at into v_row;
        perform platform.log_audit('portal_feature_flag.created', 'portal_feature_flag', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_feature_flag' then
        v_tid := platform.current_tenant_id();
        update public.portal_feature_flags ff set
            feature_key = case when p_payload ? 'feature_key' then p_payload->>'feature_key' else ff.feature_key end,
            enabled = case when p_payload ? 'enabled' then (p_payload->>'enabled')::boolean else ff.enabled end
        where ff.id = (p_payload->>'id')::uuid and ff.tenant_id = v_tid
        returning ff.id, ff.tenant_id, ff.feature_key, ff.enabled, ff.created_at into v_row;
        if not found then raise exception 'Feature flag not found'; end if;
        perform platform.log_audit('portal_feature_flag.updated', 'portal_feature_flag', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_feature_flag' then
        v_tid := platform.current_tenant_id();
        delete from public.portal_feature_flags ff
        where ff.id = (p_payload->>'id')::uuid and ff.tenant_id = v_tid;
        if not found then raise exception 'Feature flag not found'; end if;
        perform platform.log_audit('portal_feature_flag.deleted', 'portal_feature_flag', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        raise exception 'unknown portal_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.portal_domain(text, jsonb) from public;
grant execute on function public.portal_domain(text, jsonb) to authenticated, service_role;


create or replace function public.onboarding_domain(
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
    v_existing uuid;
    v_blueprint_id uuid;
    v_session_id uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'list_sessions' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select s.id, s.tenant_id, s.property_id, s.preconfig_template_id, s.onboarding_blueprint_id,
                   s.status, s.current_step, s.created_at, s.updated_at
            from public.onboarding_sessions s
            where s.tenant_id = v_tid
              and (p_payload->>'property_id' is null or s.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_session' then
        v_tid := platform.current_tenant_id();
        v_session_id := (p_payload->>'id')::uuid;
        select jsonb_build_object(
            'session', (
                select to_jsonb(t) from (
                    select s.id, s.tenant_id, s.property_id, s.preconfig_template_id, s.onboarding_blueprint_id,
                           s.status, s.current_step, s.created_at, s.updated_at
                    from public.onboarding_sessions s
                    where s.id = v_session_id and s.tenant_id = v_tid
                ) t
            ),
            'steps', coalesce((
                select jsonb_agg(to_jsonb(st) order by st.step_type)
                from (
                    select ss.id, ss.tenant_id, ss.session_id, ss.step_type, ss.status, ss.completed_at
                    from public.onboarding_step_state ss where ss.session_id = v_session_id
                ) st
            ), '[]'::jsonb),
            'room_mappings', coalesce((
                select jsonb_agg(to_jsonb(rm) order by rm.created_at)
                from (
                    select r.id, r.tenant_id, r.session_id, r.room_name, r.room_type, r.promoted_room_id, r.created_at
                    from public.onboarding_room_mapping r where r.session_id = v_session_id
                ) rm
            ), '[]'::jsonb),
            'device_mappings', coalesce((
                select jsonb_agg(to_jsonb(dm) order by dm.created_at)
                from (
                    select d.id, d.tenant_id, d.session_id, d.category_code, d.room_name, d.desired_action,
                           d.device_id, d.scan_status, d.scanned_at, d.created_at
                    from public.onboarding_device_mapping d where d.session_id = v_session_id
                ) dm
            ), '[]'::jsonb),
            'checklist', coalesce((
                select jsonb_agg(to_jsonb(c))
                from (
                    select c.id, c.tenant_id, c.session_id, c.checklist_key, c.is_completed, c.updated_at
                    from public.onboarding_checklist c where c.session_id = v_session_id
                ) c
            ), '[]'::jsonb),
            'notes', coalesce((
                select jsonb_agg(to_jsonb(n) order by n.created_at)
                from (
                    select n.id, n.tenant_id, n.session_id, n.author_user_id, n.note, n.created_at
                    from public.onboarding_notes n where n.session_id = v_session_id
                ) n
            ), '[]'::jsonb)
        ) into v_result;
        if v_result->'session' = 'null'::jsonb then raise exception 'Onboarding session not found'; end if;

    when 'create_session' then
        v_tid := platform.current_tenant_id();
        v_blueprint_id := case when p_payload ? 'onboarding_blueprint_id' and p_payload->>'onboarding_blueprint_id' is not null
            then (p_payload->>'onboarding_blueprint_id')::uuid else null end;
        if p_payload ? 'preconfig_template_id' and p_payload->>'preconfig_template_id' is not null and v_blueprint_id is null then
            select pt.onboarding_blueprint_id into v_blueprint_id
            from public.preconfig_templates pt
            where pt.id = (p_payload->>'preconfig_template_id')::uuid;
        end if;
        insert into public.onboarding_sessions (
            tenant_id, property_id, preconfig_template_id, onboarding_blueprint_id, status, current_step
        )
        values (
            v_tid,
            (p_payload->>'property_id')::uuid,
            case when p_payload ? 'preconfig_template_id' then (p_payload->>'preconfig_template_id')::uuid else null end,
            v_blueprint_id,
            coalesce((p_payload->>'status')::public.onboarding_status, 'not_started'::public.onboarding_status),
            case when p_payload ? 'current_step' and p_payload->>'current_step' is not null
                then (p_payload->>'current_step')::public.onboarding_step_type else null end
        )
        returning id, tenant_id, property_id, preconfig_template_id, onboarding_blueprint_id,
                  status, current_step, created_at, updated_at into v_row;
        v_session_id := v_row.id;
        if v_blueprint_id is not null then
            insert into public.onboarding_step_state (session_id, step_type, status)
            select v_session_id, obs.step_type, 'pending'::public.onboarding_step_status
            from public.onboarding_blueprint_steps obs
            where obs.blueprint_id = v_blueprint_id
            order by obs.step_order;
        end if;
        perform platform.log_audit('onboarding_session.created', 'onboarding_session', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_session' then
        v_tid := platform.current_tenant_id();
        update public.onboarding_sessions s set
            preconfig_template_id = case when p_payload ? 'preconfig_template_id'
                then (p_payload->>'preconfig_template_id')::uuid else s.preconfig_template_id end,
            onboarding_blueprint_id = case when p_payload ? 'onboarding_blueprint_id'
                then (p_payload->>'onboarding_blueprint_id')::uuid else s.onboarding_blueprint_id end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.onboarding_status else s.status end,
            current_step = case when p_payload ? 'current_step'
                then case when p_payload->>'current_step' is null then null
                     else (p_payload->>'current_step')::public.onboarding_step_type end
                else s.current_step end
        where s.id = (p_payload->>'id')::uuid and s.tenant_id = v_tid
        returning s.id, s.tenant_id, s.property_id, s.preconfig_template_id, s.onboarding_blueprint_id,
                  s.status, s.current_step, s.created_at, s.updated_at into v_row;
        if not found then raise exception 'Onboarding session not found'; end if;
        perform platform.log_audit('onboarding_session.updated', 'onboarding_session', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_session' then
        v_tid := platform.current_tenant_id();
        delete from public.onboarding_sessions s
        where s.id = (p_payload->>'id')::uuid and s.tenant_id = v_tid;
        if not found then raise exception 'Onboarding session not found'; end if;
        perform platform.log_audit('onboarding_session.deleted', 'onboarding_session', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_step_states' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_result
        from (
            select ss.id, ss.tenant_id, ss.session_id, ss.step_type, ss.status, ss.completed_at
            from public.onboarding_step_state ss
            where ss.session_id = (p_payload->>'session_id')::uuid and ss.tenant_id = v_tid
        ) t;

    when 'update_step_state' then
        v_tid := platform.current_tenant_id();
        update public.onboarding_step_state ss set
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.onboarding_step_status else ss.status end,
            completed_at = case
                when p_payload ? 'completed_at' then (p_payload->>'completed_at')::timestamptz
                when p_payload ? 'status' and p_payload->>'status' = 'completed' then now()
                else ss.completed_at
            end
        where ss.id = (p_payload->>'id')::uuid and ss.tenant_id = v_tid
        returning ss.id, ss.tenant_id, ss.session_id, ss.step_type, ss.status, ss.completed_at into v_row;
        if not found then raise exception 'Step state not found'; end if;
        perform platform.log_audit('onboarding_step_state.updated', 'onboarding_step_state', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_room_mappings' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select r.id, r.tenant_id, r.session_id, r.room_name, r.room_type, r.promoted_room_id, r.created_at
            from public.onboarding_room_mapping r
            where r.session_id = (p_payload->>'session_id')::uuid and r.tenant_id = v_tid
        ) t;

    when 'create_room_mapping' then
        v_tid := platform.current_tenant_id();
        insert into public.onboarding_room_mapping (session_id, room_name, room_type)
        values (
            (p_payload->>'session_id')::uuid,
            p_payload->>'room_name',
            case when p_payload ? 'room_type' and p_payload->>'room_type' is not null
                then (p_payload->>'room_type')::public.room_type else null end
        )
        returning id, tenant_id, session_id, room_name, room_type, promoted_room_id, created_at into v_row;
        perform platform.log_audit('onboarding_room_mapping.created', 'onboarding_room_mapping', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_room_mapping' then
        v_tid := platform.current_tenant_id();
        update public.onboarding_room_mapping r set
            room_name = case when p_payload ? 'room_name' then p_payload->>'room_name' else r.room_name end,
            room_type = case when p_payload ? 'room_type'
                then case when p_payload->>'room_type' is null then null else (p_payload->>'room_type')::public.room_type end
                else r.room_type end,
            promoted_room_id = case when p_payload ? 'promoted_room_id'
                then (p_payload->>'promoted_room_id')::uuid else r.promoted_room_id end
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid
        returning r.id, r.tenant_id, r.session_id, r.room_name, r.room_type, r.promoted_room_id, r.created_at into v_row;
        if not found then raise exception 'Room mapping not found'; end if;
        perform platform.log_audit('onboarding_room_mapping.updated', 'onboarding_room_mapping', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_room_mapping' then
        v_tid := platform.current_tenant_id();
        delete from public.onboarding_room_mapping r
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid;
        if not found then raise exception 'Room mapping not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_mappings' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select d.id, d.tenant_id, d.session_id, d.category_code, d.room_name, d.desired_action,
                   d.device_id, d.scan_status, d.scanned_at, d.created_at
            from public.onboarding_device_mapping d
            where d.session_id = (p_payload->>'session_id')::uuid and d.tenant_id = v_tid
        ) t;

    when 'create_device_mapping' then
        v_tid := platform.current_tenant_id();
        insert into public.onboarding_device_mapping (
            session_id, category_code, room_name, desired_action, scan_status
        )
        values (
            (p_payload->>'session_id')::uuid,
            p_payload->>'category_code',
            p_payload->>'room_name',
            p_payload->>'desired_action',
            coalesce((p_payload->>'scan_status')::public.onboarding_step_status, 'pending'::public.onboarding_step_status)
        )
        returning id, tenant_id, session_id, category_code, room_name, desired_action,
                  device_id, scan_status, scanned_at, created_at into v_row;
        perform platform.log_audit('onboarding_device_mapping.created', 'onboarding_device_mapping', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_device_mapping' then
        v_tid := platform.current_tenant_id();
        update public.onboarding_device_mapping d set
            category_code = case when p_payload ? 'category_code' then p_payload->>'category_code' else d.category_code end,
            room_name = case when p_payload ? 'room_name' then p_payload->>'room_name' else d.room_name end,
            desired_action = case when p_payload ? 'desired_action' then p_payload->>'desired_action' else d.desired_action end,
            device_id = case when p_payload ? 'device_id'
                then (p_payload->>'device_id')::uuid else d.device_id end,
            scan_status = case when p_payload ? 'scan_status'
                then (p_payload->>'scan_status')::public.onboarding_step_status else d.scan_status end,
            scanned_at = case
                when p_payload ? 'scanned_at' then (p_payload->>'scanned_at')::timestamptz
                when p_payload ? 'device_id' and p_payload->>'device_id' is not null then now()
                else d.scanned_at
            end
        where d.id = (p_payload->>'id')::uuid and d.tenant_id = v_tid
        returning d.id, d.tenant_id, d.session_id, d.category_code, d.room_name, d.desired_action,
                  d.device_id, d.scan_status, d.scanned_at, d.created_at into v_row;
        if not found then raise exception 'Device mapping not found'; end if;
        perform platform.log_audit('onboarding_device_mapping.updated', 'onboarding_device_mapping', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_device_mapping' then
        v_tid := platform.current_tenant_id();
        delete from public.onboarding_device_mapping d
        where d.id = (p_payload->>'id')::uuid and d.tenant_id = v_tid;
        if not found then raise exception 'Device mapping not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_checklist_items' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) into v_result
        from (
            select c.id, c.tenant_id, c.session_id, c.checklist_key, c.is_completed, c.updated_at
            from public.onboarding_checklist c
            where c.session_id = (p_payload->>'session_id')::uuid and c.tenant_id = v_tid
        ) t;

    when 'upsert_checklist_item' then
        v_tid := platform.current_tenant_id();
        select c.id into v_existing from public.onboarding_checklist c
        where c.session_id = (p_payload->>'session_id')::uuid
          and c.checklist_key = p_payload->>'checklist_key';
        if found then
            update public.onboarding_checklist c set
                is_completed = coalesce((p_payload->>'is_completed')::boolean, true)
            where c.id = v_existing
            returning c.id, c.tenant_id, c.session_id, c.checklist_key, c.is_completed, c.updated_at into v_row;
        else
            insert into public.onboarding_checklist (session_id, checklist_key, is_completed)
            values (
                (p_payload->>'session_id')::uuid,
                p_payload->>'checklist_key',
                coalesce((p_payload->>'is_completed')::boolean, false)
            )
            returning id, tenant_id, session_id, checklist_key, is_completed, updated_at into v_row;
            perform platform.log_audit('onboarding_checklist.created', 'onboarding_checklist', v_row.id);
        end if;
        v_result := to_jsonb(v_row);

    when 'update_checklist_item' then
        v_tid := platform.current_tenant_id();
        update public.onboarding_checklist c set
            is_completed = case when p_payload ? 'is_completed'
                then (p_payload->>'is_completed')::boolean else c.is_completed end
        where c.id = (p_payload->>'id')::uuid and c.tenant_id = v_tid
        returning c.id, c.tenant_id, c.session_id, c.checklist_key, c.is_completed, c.updated_at into v_row;
        if not found then raise exception 'Checklist item not found'; end if;
        v_result := to_jsonb(v_row);

    when 'delete_checklist_item' then
        v_tid := platform.current_tenant_id();
        delete from public.onboarding_checklist c
        where c.id = (p_payload->>'id')::uuid and c.tenant_id = v_tid;
        if not found then raise exception 'Checklist item not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_notes' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select n.id, n.tenant_id, n.session_id, n.author_user_id, n.note, n.created_at
            from public.onboarding_notes n
            where n.session_id = (p_payload->>'session_id')::uuid and n.tenant_id = v_tid
        ) t;

    when 'create_note' then
        v_tid := platform.current_tenant_id();
        insert into public.onboarding_notes (session_id, author_user_id, note)
        values ((p_payload->>'session_id')::uuid, v_uid, p_payload->>'note')
        returning id, tenant_id, session_id, author_user_id, note, created_at into v_row;
        perform platform.log_audit('onboarding_note.created', 'onboarding_note', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_note' then
        v_tid := platform.current_tenant_id();
        delete from public.onboarding_notes n
        where n.id = (p_payload->>'id')::uuid and n.tenant_id = v_tid;
        if not found then raise exception 'Note not found'; end if;
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        raise exception 'unknown onboarding_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.onboarding_domain(text, jsonb) from public;
grant execute on function public.onboarding_domain(text, jsonb) to authenticated, service_role;


create or replace function public.optimization_domain(
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
    v_avg numeric;
    v_count int;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_rules' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at
            from public.optimization_rules r where r.tenant_id = v_tid
        ) t;

    when 'get_rule' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at
            from public.optimization_rules r
            where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Optimization rule not found'; end if;

    when 'create_rule' then
        v_tid := platform.current_tenant_id();
        insert into public.optimization_rules (tenant_id, rule_name, description, category, rule_config, is_active)
        values (
            v_tid,
            p_payload->>'rule_name',
            p_payload->>'description',
            case when p_payload ? 'category' and p_payload->>'category' is not null
                then (p_payload->>'category')::public.optimization_category else null end,
            p_payload->'rule_config',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, rule_name, description, category, rule_config, is_active, created_at into v_row;
        perform platform.log_audit('optimization_rule.created', 'optimization_rule', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_rule' then
        v_tid := platform.current_tenant_id();
        update public.optimization_rules r set
            rule_name = case when p_payload ? 'rule_name' then p_payload->>'rule_name' else r.rule_name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else r.description end,
            category = case when p_payload ? 'category'
                then case when p_payload->>'category' is null then null else (p_payload->>'category')::public.optimization_category end
                else r.category end,
            rule_config = case when p_payload ? 'rule_config' then p_payload->'rule_config' else r.rule_config end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else r.is_active end
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid
        returning r.id, r.tenant_id, r.rule_name, r.description, r.category, r.rule_config, r.is_active, r.created_at into v_row;
        if not found then raise exception 'Optimization rule not found'; end if;
        perform platform.log_audit('optimization_rule.updated', 'optimization_rule', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_rule' then
        v_tid := platform.current_tenant_id();
        delete from public.optimization_rules r
        where r.id = (p_payload->>'id')::uuid and r.tenant_id = v_tid;
        if not found then raise exception 'Optimization rule not found'; end if;
        perform platform.log_audit('optimization_rule.deleted', 'optimization_rule', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_insight_events' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select i.id, i.tenant_id, i.property_id, i.insight_type, i.severity, i.message, i.metadata,
                   i.dedup_key, i.confidence, i.ai_metadata, i.related_recommendation_id, i.created_at
            from public.insight_events i
            where i.tenant_id = v_tid
              and (p_payload->>'property_id' is null or i.property_id = (p_payload->>'property_id')::uuid)
              and (p_payload->>'insight_type' is null or i.insight_type::text = p_payload->>'insight_type')
        ) t;

    when 'get_insight_event' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select i.id, i.tenant_id, i.property_id, i.insight_type, i.severity, i.message, i.metadata,
                   i.dedup_key, i.confidence, i.ai_metadata, i.related_recommendation_id, i.created_at
            from public.insight_events i
            where i.id = (p_payload->>'id')::uuid and i.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Insight event not found'; end if;

    when 'list_recommendations' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                   rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                   rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at
            from public.optimization_recommendations rec
            where rec.tenant_id = v_tid
              and (p_payload->>'status' is null or rec.status::text = p_payload->>'status')
              and (p_payload->>'property_id' is null or rec.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_recommendation' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                   rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                   rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at
            from public.optimization_recommendations rec
            where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Recommendation not found'; end if;

    when 'update_recommendation' then
        v_tid := platform.current_tenant_id();
        update public.optimization_recommendations rec set
            status = (p_payload->>'status')::public.recommendation_status
        where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid
        returning rec.id, rec.tenant_id, rec.property_id, rec.source_rule_id, rec.source_insight_id,
                  rec.recommendation_type, rec.severity, rec.status, rec.explanation, rec.suggested_changes,
                  rec.confidence, rec.dedup_key, rec.ai_metadata, rec.customer_proposal_id, rec.created_at into v_row;
        if not found then raise exception 'Recommendation not found'; end if;
        perform platform.log_audit('optimization_recommendation.updated', 'optimization_recommendation', v_row.id,
            jsonb_build_object('status', v_row.status));
        v_result := to_jsonb(v_row);

    when 'delete_recommendation' then
        v_tid := platform.current_tenant_id();
        delete from public.optimization_recommendations rec
        where rec.id = (p_payload->>'id')::uuid and rec.tenant_id = v_tid;
        if not found then raise exception 'Recommendation not found'; end if;
        perform platform.log_audit('optimization_recommendation.deleted', 'optimization_recommendation', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_usage_scores' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.calculated_at desc), '[]'::jsonb) into v_result
        from (
            select s.id, s.tenant_id, s.device_id, s.score, s.category, s.score_period, s.calculated_at
            from public.device_usage_scores s
            where s.tenant_id = v_tid
              and (p_payload->>'device_id' is null or s.device_id = (p_payload->>'device_id')::uuid)
        ) t;

    when 'list_energy_profiles' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.computed_at desc), '[]'::jsonb) into v_result
        from (
            select e.id, e.tenant_id, e.property_id, e.period_start, e.period_end, e.consumption_unit,
                   e.baseline_consumption, e.optimized_consumption, e.potential_savings_percent, e.computed_at
            from public.energy_profiles e
            where e.tenant_id = v_tid
              and (p_payload->>'property_id' is null or e.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_energy_profile' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select e.id, e.tenant_id, e.property_id, e.period_start, e.period_end, e.consumption_unit,
                   e.baseline_consumption, e.optimized_consumption, e.potential_savings_percent, e.computed_at
            from public.energy_profiles e
            where e.id = (p_payload->>'id')::uuid and e.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Energy profile not found'; end if;

    when 'calculate_property_score' then
        v_tid := platform.current_tenant_id();
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        select avg(s.score)::numeric, count(*)::int
        into v_avg, v_count
        from public.device_usage_scores s
        join public.devices d on d.id = s.device_id
        join public.device_assignments da on da.device_id = d.id
        join public.rooms r on r.id = da.room_id
        where s.tenant_id = v_tid
          and r.property_id = (p_payload->>'property_id')::uuid;
        v_result := jsonb_build_object(
            'property_id', p_payload->>'property_id',
            'score', coalesce(v_avg, 0),
            'device_count', coalesce(v_count, 0),
            'calculated_at', now()
        );

    else
        raise exception 'unknown optimization_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.optimization_domain(text, jsonb) from public;
grant execute on function public.optimization_domain(text, jsonb) to authenticated, service_role;


create or replace function public.monetization_domain(
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
    v_proposal_id uuid;
    v_limit int;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_proposals' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select cp.id, cp.tenant_id, cp.property_id, cp.status, cp.total_estimated_value,
                   cp.presented_at, cp.accepted_at, cp.expires_at, cp.source_campaign_id, cp.created_at, cp.updated_at
            from public.customer_proposals cp
            where cp.tenant_id = v_tid
              and (p_payload->>'status' is null or cp.status::text = p_payload->>'status')
              and (p_payload->>'property_id' is null or cp.property_id = (p_payload->>'property_id')::uuid)
        ) t;

    when 'get_proposal' then
        v_tid := platform.current_tenant_id();
        v_proposal_id := (p_payload->>'id')::uuid;
        select jsonb_build_object(
            'proposal', (
                select to_jsonb(t) from (
                    select cp.id, cp.tenant_id, cp.property_id, cp.status, cp.total_estimated_value,
                           cp.presented_at, cp.accepted_at, cp.expires_at, cp.source_campaign_id, cp.created_at, cp.updated_at
                    from public.customer_proposals cp
                    where cp.id = v_proposal_id and cp.tenant_id = v_tid
                ) t
            ),
            'items', coalesce((
                select jsonb_agg(to_jsonb(pi) order by pi.created_at)
                from (
                    select pi.id, pi.tenant_id, pi.proposal_id, pi.item_type, pi.plan_id,
                           pi.monetization_package_id, pi.reference_id, pi.quantity, pi.price_estimate, pi.created_at
                    from public.proposal_items pi where pi.proposal_id = v_proposal_id
                ) pi
            ), '[]'::jsonb)
        ) into v_result;
        if v_result->'proposal' = 'null'::jsonb then raise exception 'Customer proposal not found'; end if;

    when 'create_proposal' then
        v_tid := platform.current_tenant_id();
        insert into public.customer_proposals (
            tenant_id, property_id, total_estimated_value, expires_at, source_campaign_id, status
        )
        values (
            v_tid,
            case when p_payload ? 'property_id' then (p_payload->>'property_id')::uuid else null end,
            case when p_payload ? 'total_estimated_value' then (p_payload->>'total_estimated_value')::numeric else null end,
            case when p_payload ? 'expires_at' then (p_payload->>'expires_at')::timestamptz else null end,
            case when p_payload ? 'source_campaign_id' then (p_payload->>'source_campaign_id')::uuid else null end,
            'draft'::public.proposal_status
        )
        returning id, tenant_id, property_id, status, total_estimated_value, presented_at, accepted_at,
                  expires_at, source_campaign_id, created_at, updated_at into v_row;
        perform platform.log_audit('customer_proposal.created', 'customer_proposal', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_proposal' then
        v_tid := platform.current_tenant_id();
        update public.customer_proposals cp set
            property_id = case when p_payload ? 'property_id'
                then (p_payload->>'property_id')::uuid else cp.property_id end,
            total_estimated_value = case when p_payload ? 'total_estimated_value'
                then (p_payload->>'total_estimated_value')::numeric else cp.total_estimated_value end,
            expires_at = case when p_payload ? 'expires_at'
                then (p_payload->>'expires_at')::timestamptz else cp.expires_at end,
            source_campaign_id = case when p_payload ? 'source_campaign_id'
                then (p_payload->>'source_campaign_id')::uuid else cp.source_campaign_id end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.proposal_status else cp.status end
        where cp.id = (p_payload->>'id')::uuid and cp.tenant_id = v_tid
        returning cp.id, cp.tenant_id, cp.property_id, cp.status, cp.total_estimated_value, cp.presented_at,
                  cp.accepted_at, cp.expires_at, cp.source_campaign_id, cp.created_at, cp.updated_at into v_row;
        if not found then raise exception 'Customer proposal not found'; end if;
        perform platform.log_audit('customer_proposal.updated', 'customer_proposal', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_proposal' then
        v_tid := platform.current_tenant_id();
        delete from public.customer_proposals cp
        where cp.id = (p_payload->>'id')::uuid and cp.tenant_id = v_tid;
        if not found then raise exception 'Customer proposal not found'; end if;
        perform platform.log_audit('customer_proposal.deleted', 'customer_proposal', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_proposal_items' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select pi.id, pi.tenant_id, pi.proposal_id, pi.item_type, pi.plan_id,
                   pi.monetization_package_id, pi.reference_id, pi.quantity, pi.price_estimate, pi.created_at
            from public.proposal_items pi
            where pi.proposal_id = (p_payload->>'proposal_id')::uuid and pi.tenant_id = v_tid
        ) t;

    when 'create_proposal_item' then
        v_tid := platform.current_tenant_id();
        insert into public.proposal_items (
            tenant_id, proposal_id, item_type, plan_id, monetization_package_id, reference_id, quantity, price_estimate
        )
        values (
            v_tid,
            (p_payload->>'proposal_id')::uuid,
            (p_payload->>'item_type')::public.proposal_item_type,
            case when p_payload ? 'plan_id' then (p_payload->>'plan_id')::uuid else null end,
            case when p_payload ? 'monetization_package_id' then (p_payload->>'monetization_package_id')::uuid else null end,
            case when p_payload ? 'reference_id' then (p_payload->>'reference_id')::uuid else null end,
            coalesce((p_payload->>'quantity')::int, 1),
            case when p_payload ? 'price_estimate' then (p_payload->>'price_estimate')::numeric else null end
        )
        returning id, tenant_id, proposal_id, item_type, plan_id, monetization_package_id,
                  reference_id, quantity, price_estimate, created_at into v_row;
        perform platform.log_audit('proposal_item.created', 'proposal_item', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_proposal_item' then
        v_tid := platform.current_tenant_id();
        update public.proposal_items pi set
            item_type = case when p_payload ? 'item_type'
                then (p_payload->>'item_type')::public.proposal_item_type else pi.item_type end,
            plan_id = case when p_payload ? 'plan_id' then (p_payload->>'plan_id')::uuid else pi.plan_id end,
            monetization_package_id = case when p_payload ? 'monetization_package_id'
                then (p_payload->>'monetization_package_id')::uuid else pi.monetization_package_id end,
            reference_id = case when p_payload ? 'reference_id'
                then (p_payload->>'reference_id')::uuid else pi.reference_id end,
            quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::int else pi.quantity end,
            price_estimate = case when p_payload ? 'price_estimate'
                then (p_payload->>'price_estimate')::numeric else pi.price_estimate end
        where pi.id = (p_payload->>'id')::uuid and pi.tenant_id = v_tid
        returning pi.id, pi.tenant_id, pi.proposal_id, pi.item_type, pi.plan_id, pi.monetization_package_id,
                  pi.reference_id, pi.quantity, pi.price_estimate, pi.created_at into v_row;
        if not found then raise exception 'Proposal item not found'; end if;
        perform platform.log_audit('proposal_item.updated', 'proposal_item', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_proposal_item' then
        v_tid := platform.current_tenant_id();
        delete from public.proposal_items pi
        where pi.id = (p_payload->>'id')::uuid and pi.tenant_id = v_tid;
        if not found then raise exception 'Proposal item not found'; end if;
        perform platform.log_audit('proposal_item.deleted', 'proposal_item', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_packages' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select mp.id, mp.name, mp.description, mp.package_type, mp.device_bundle_id,
                   mp.base_price, mp.is_active, mp.created_at, mp.updated_at
            from public.monetization_packages mp
            where coalesce((p_payload->>'active_only')::boolean, true) = false or mp.is_active = true
        ) t;

    when 'get_package' then
        select to_jsonb(t) into v_result from (
            select mp.id, mp.name, mp.description, mp.package_type, mp.device_bundle_id,
                   mp.base_price, mp.is_active, mp.created_at, mp.updated_at
            from public.monetization_packages mp where mp.id = (p_payload->>'id')::uuid
        ) t;
        if v_result is null then raise exception 'Monetization package not found'; end if;

    when 'create_package' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.monetization_packages (name, description, package_type, device_bundle_id, base_price, is_active)
        values (
            p_payload->>'name',
            p_payload->>'description',
            (p_payload->>'package_type')::public.package_type,
            case when p_payload ? 'device_bundle_id' then (p_payload->>'device_bundle_id')::uuid else null end,
            case when p_payload ? 'base_price' then (p_payload->>'base_price')::numeric else null end,
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, name, description, package_type, device_bundle_id, base_price, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('monetization_package.created', 'monetization_package', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_package' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.monetization_packages mp set
            name = case when p_payload ? 'name' then p_payload->>'name' else mp.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else mp.description end,
            package_type = case when p_payload ? 'package_type'
                then (p_payload->>'package_type')::public.package_type else mp.package_type end,
            device_bundle_id = case when p_payload ? 'device_bundle_id'
                then (p_payload->>'device_bundle_id')::uuid else mp.device_bundle_id end,
            base_price = case when p_payload ? 'base_price'
                then (p_payload->>'base_price')::numeric else mp.base_price end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else mp.is_active end
        where mp.id = (p_payload->>'id')::uuid
        returning mp.id, mp.name, mp.description, mp.package_type, mp.device_bundle_id,
                  mp.base_price, mp.is_active, mp.created_at, mp.updated_at into v_row;
        if not found then raise exception 'Monetization package not found'; end if;
        perform platform.log_audit('monetization_package.updated', 'monetization_package', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_package' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.monetization_packages mp where mp.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Monetization package not found'; end if;
        perform platform.log_audit('monetization_package.deleted', 'monetization_package', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_upsell_campaigns' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select uc.id, uc.tenant_id, uc.trigger_event, uc.target_package_id, uc.campaign_rules, uc.is_active, uc.created_at
            from public.upsell_campaigns uc
            where (uc.tenant_id is null or uc.tenant_id = v_tid or platform.is_platform_admin())
              and (coalesce((p_payload->>'active_only')::boolean, true) = false or uc.is_active = true)
              and (p_payload->>'trigger_event' is null or uc.trigger_event::text = p_payload->>'trigger_event')
        ) t;

    when 'get_upsell_campaign' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select uc.id, uc.tenant_id, uc.trigger_event, uc.target_package_id, uc.campaign_rules, uc.is_active, uc.created_at
            from public.upsell_campaigns uc
            where uc.id = (p_payload->>'id')::uuid
              and (uc.tenant_id is null or uc.tenant_id = v_tid or platform.is_platform_admin())
        ) t;
        if v_result is null then raise exception 'Upsell campaign not found'; end if;

    when 'create_upsell_campaign' then
        if platform.is_platform_admin() then
            v_tid := case when p_payload ? 'tenant_id' then (p_payload->>'tenant_id')::uuid else null end;
        else
            v_tid := platform.current_tenant_id();
            if p_payload ? 'tenant_id' and (p_payload->>'tenant_id')::uuid is distinct from v_tid then
                raise exception 'Tenant managers can only create campaigns for their tenant';
            end if;
        end if;
        insert into public.upsell_campaigns (tenant_id, trigger_event, target_package_id, campaign_rules, is_active)
        values (
            v_tid,
            case when p_payload ? 'trigger_event' and p_payload->>'trigger_event' is not null
                then (p_payload->>'trigger_event')::public.upsell_package_trigger else null end,
            case when p_payload ? 'target_package_id' then (p_payload->>'target_package_id')::uuid else null end,
            case when p_payload ? 'campaign_rules' then p_payload->'campaign_rules' else null end,
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, trigger_event, target_package_id, campaign_rules, is_active, created_at into v_row;
        perform platform.log_audit('upsell_campaign.created', 'upsell_campaign', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_upsell_campaign' then
        if not platform.is_platform_admin() then perform public.edge_require_manager(); end if;
        v_tid := platform.current_tenant_id();
        update public.upsell_campaigns uc set
            trigger_event = case when p_payload ? 'trigger_event'
                then case when p_payload->>'trigger_event' is null then null
                     else (p_payload->>'trigger_event')::public.upsell_package_trigger end
                else uc.trigger_event end,
            target_package_id = case when p_payload ? 'target_package_id'
                then (p_payload->>'target_package_id')::uuid else uc.target_package_id end,
            campaign_rules = case when p_payload ? 'campaign_rules' then p_payload->'campaign_rules' else uc.campaign_rules end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else uc.is_active end
        where uc.id = (p_payload->>'id')::uuid
          and (platform.is_platform_admin() or uc.tenant_id = v_tid)
        returning uc.id, uc.tenant_id, uc.trigger_event, uc.target_package_id, uc.campaign_rules, uc.is_active, uc.created_at into v_row;
        if not found then raise exception 'Upsell campaign not found'; end if;
        perform platform.log_audit('upsell_campaign.updated', 'upsell_campaign', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_upsell_campaign' then
        if not platform.is_platform_admin() then perform public.edge_require_manager(); end if;
        v_tid := platform.current_tenant_id();
        delete from public.upsell_campaigns uc
        where uc.id = (p_payload->>'id')::uuid
          and (platform.is_platform_admin() or uc.tenant_id = v_tid);
        if not found then raise exception 'Upsell campaign not found'; end if;
        perform platform.log_audit('upsell_campaign.deleted', 'upsell_campaign', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_activation_state' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.updated_at desc), '[]'::jsonb) into v_result
        from (
            select sas.id, sas.tenant_id, sas.property_id, sas.service_type, sas.status,
                   sas.source_proposal_id, sas.source_subscription_id, sas.created_at, sas.updated_at
            from public.service_activation_state sas
            where sas.tenant_id = v_tid
              and (p_payload->>'property_id' is null or sas.property_id = (p_payload->>'property_id')::uuid)
              and (p_payload->>'service_type' is null or sas.service_type::text = p_payload->>'service_type')
        ) t;

    when 'list_conversion_events' then
        v_tid := platform.current_tenant_id();
        v_limit := least(coalesce((p_payload->>'limit')::int, 100), 500);
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select ce.id, ce.tenant_id, ce.property_id, ce.proposal_id, ce.event_type, ce.source, ce.metadata, ce.created_at
            from public.conversion_events ce
            where ce.tenant_id = v_tid
              and (p_payload->>'proposal_id' is null or ce.proposal_id = (p_payload->>'proposal_id')::uuid)
              and (p_payload->>'event_type' is null or ce.event_type::text = p_payload->>'event_type')
            order by ce.created_at desc
            limit v_limit
        ) t;

    when 'list_conversion_scores' then
        v_tid := platform.current_tenant_id();
        v_limit := least(coalesce((p_payload->>'limit')::int, 50), 200);
        select coalesce(jsonb_agg(to_jsonb(t) order by t.calculated_at desc), '[]'::jsonb) into v_result
        from (
            select cs.id, cs.tenant_id, cs.property_id, cs.score, cs.factors, cs.calculated_at
            from public.conversion_scores cs
            where cs.tenant_id = v_tid
              and (p_payload->>'property_id' is null or cs.property_id = (p_payload->>'property_id')::uuid)
            order by cs.calculated_at desc
            limit v_limit
        ) t;

    else
        raise exception 'unknown monetization_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.monetization_domain(text, jsonb) from public;
grant execute on function public.monetization_domain(text, jsonb) to authenticated, service_role;


create or replace function public.operations_domain(
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
    v_workflow_tenant uuid;
    v_workflow_id uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'list_templates' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select ot.id, ot.tenant_id, ot.is_system, ot.name, ot.description, ot.template, ot.version, ot.is_active, ot.created_at, ot.updated_at
            from public.operation_templates ot
            where ot.is_system = true or ot.tenant_id = v_tid or platform.is_platform_admin()
        ) t;

    when 'get_template' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select ot.id, ot.tenant_id, ot.is_system, ot.name, ot.description, ot.template, ot.version, ot.is_active, ot.created_at, ot.updated_at
            from public.operation_templates ot
            where ot.id = (p_payload->>'id')::uuid
              and (ot.is_system = true or ot.tenant_id = v_tid or platform.is_platform_admin())
        ) t;
        if v_result is null then raise exception 'Template not found'; end if;

    when 'create_template' then
        v_tid := platform.current_tenant_id();
        insert into public.operation_templates (tenant_id, is_system, name, description, template, version, is_active)
        values (
            v_tid, false, p_payload->>'name', p_payload->>'description',
            p_payload->'template', coalesce((p_payload->>'version')::int, 1),
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, is_system, name, description, template, version, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('operation_template.created', 'operation_template', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_template' then
        v_tid := platform.current_tenant_id();
        update public.operation_templates ot set
            name = case when p_payload ? 'name' then p_payload->>'name' else ot.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else ot.description end,
            template = case when p_payload ? 'template' then p_payload->'template' else ot.template end,
            version = case when p_payload ? 'version' then (p_payload->>'version')::int else ot.version end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else ot.is_active end
        where ot.id = (p_payload->>'id')::uuid and ot.is_system = false and ot.tenant_id = v_tid
        returning ot.id, ot.tenant_id, ot.is_system, ot.name, ot.description, ot.template, ot.version, ot.is_active, ot.created_at, ot.updated_at into v_row;
        if not found then raise exception 'Template not found'; end if;
        perform platform.log_audit('operation_template.updated', 'operation_template', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_template' then
        v_tid := platform.current_tenant_id();
        delete from public.operation_templates ot
        where ot.id = (p_payload->>'id')::uuid and ot.is_system = false and ot.tenant_id = v_tid;
        if not found then raise exception 'Template not found'; end if;
        perform platform.log_audit('operation_template.deleted', 'operation_template', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_workflows' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select ow.id, ow.tenant_id, ow.source_template_id, ow.name, ow.description, ow.is_active, ow.version, ow.created_at, ow.updated_at
            from public.operation_workflows ow where ow.tenant_id = v_tid
        ) t;

    when 'get_workflow' then
        v_tid := platform.current_tenant_id();
        v_workflow_id := (p_payload->>'id')::uuid;
        select jsonb_build_object(
            'workflow', (
                select to_jsonb(t) from (
                    select ow.id, ow.tenant_id, ow.source_template_id, ow.name, ow.description, ow.is_active, ow.version, ow.created_at, ow.updated_at
                    from public.operation_workflows ow where ow.id = v_workflow_id and ow.tenant_id = v_tid
                ) t
            ),
            'steps', coalesce((
                select jsonb_agg(to_jsonb(ws) order by ws.step_order)
                from (
                    select ws.id, ws.tenant_id, ws.workflow_id, ws.step_order, ws.action_type, ws.config, ws.delay_seconds, ws.created_at
                    from public.workflow_steps ws where ws.workflow_id = v_workflow_id
                ) ws
            ), '[]'::jsonb),
            'triggers', coalesce((
                select jsonb_agg(to_jsonb(wt) order by wt.created_at)
                from (
                    select wt.id, wt.tenant_id, wt.workflow_id, wt.property_id, wt.trigger_type, wt.trigger_config, wt.is_active, wt.created_at
                    from public.workflow_triggers wt where wt.workflow_id = v_workflow_id
                ) wt
            ), '[]'::jsonb)
        ) into v_result;
        if v_result->'workflow' = 'null'::jsonb then raise exception 'Workflow not found'; end if;

    when 'create_workflow' then
        v_tid := platform.current_tenant_id();
        insert into public.operation_workflows (tenant_id, name, description, source_template_id, is_active, version)
        values (
            v_tid, p_payload->>'name', p_payload->>'description',
            case when p_payload ? 'source_template_id' then (p_payload->>'source_template_id')::uuid else null end,
            coalesce((p_payload->>'is_active')::boolean, true),
            coalesce((p_payload->>'version')::int, 1)
        )
        returning id, tenant_id, source_template_id, name, description, is_active, version, created_at, updated_at into v_row;
        perform platform.log_audit('operation_workflow.created', 'operation_workflow', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_workflow' then
        v_tid := platform.current_tenant_id();
        update public.operation_workflows ow set
            name = case when p_payload ? 'name' then p_payload->>'name' else ow.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else ow.description end,
            source_template_id = case when p_payload ? 'source_template_id'
                then (p_payload->>'source_template_id')::uuid else ow.source_template_id end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else ow.is_active end,
            version = case when p_payload ? 'version' then (p_payload->>'version')::int else ow.version end
        where ow.id = (p_payload->>'id')::uuid and ow.tenant_id = v_tid
        returning ow.id, ow.tenant_id, ow.source_template_id, ow.name, ow.description, ow.is_active, ow.version, ow.created_at, ow.updated_at into v_row;
        if not found then raise exception 'Workflow not found'; end if;
        perform platform.log_audit('operation_workflow.updated', 'operation_workflow', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_workflow' then
        v_tid := platform.current_tenant_id();
        delete from public.operation_workflows ow
        where ow.id = (p_payload->>'id')::uuid and ow.tenant_id = v_tid;
        if not found then raise exception 'Workflow not found'; end if;
        perform platform.log_audit('operation_workflow.deleted', 'operation_workflow', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_workflow_steps' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.step_order), '[]'::jsonb) into v_result
        from (
            select ws.id, ws.tenant_id, ws.workflow_id, ws.step_order, ws.action_type, ws.config, ws.delay_seconds, ws.created_at
            from public.workflow_steps ws
            join public.operation_workflows ow on ow.id = ws.workflow_id
            where ws.workflow_id = (p_payload->>'workflow_id')::uuid and ow.tenant_id = v_tid
        ) t;

    when 'create_workflow_step' then
        v_tid := platform.current_tenant_id();
        select ow.tenant_id into v_workflow_tenant from public.operation_workflows ow
        where ow.id = (p_payload->>'workflow_id')::uuid and ow.tenant_id = v_tid;
        if not found then raise exception 'Workflow not found'; end if;
        insert into public.workflow_steps (tenant_id, workflow_id, step_order, action_type, config, delay_seconds)
        values (
            v_workflow_tenant,
            (p_payload->>'workflow_id')::uuid,
            (p_payload->>'step_order')::int,
            (p_payload->>'action_type')::public.automation_action_type,
            coalesce(p_payload->'config', '{}'::jsonb),
            coalesce((p_payload->>'delay_seconds')::int, 0)
        )
        returning id, tenant_id, workflow_id, step_order, action_type, config, delay_seconds, created_at into v_row;
        perform platform.log_audit('workflow_step.created', 'workflow_step', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_workflow_step' then
        v_tid := platform.current_tenant_id();
        update public.workflow_steps ws set
            step_order = case when p_payload ? 'step_order' then (p_payload->>'step_order')::int else ws.step_order end,
            action_type = case when p_payload ? 'action_type'
                then (p_payload->>'action_type')::public.automation_action_type else ws.action_type end,
            config = case when p_payload ? 'config' then p_payload->'config' else ws.config end,
            delay_seconds = case when p_payload ? 'delay_seconds' then (p_payload->>'delay_seconds')::int else ws.delay_seconds end
        where ws.id = (p_payload->>'id')::uuid and ws.tenant_id = v_tid
        returning ws.id, ws.tenant_id, ws.workflow_id, ws.step_order, ws.action_type, ws.config, ws.delay_seconds, ws.created_at into v_row;
        if not found then raise exception 'Workflow step not found'; end if;
        perform platform.log_audit('workflow_step.updated', 'workflow_step', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_workflow_step' then
        v_tid := platform.current_tenant_id();
        delete from public.workflow_steps ws where ws.id = (p_payload->>'id')::uuid and ws.tenant_id = v_tid;
        if not found then raise exception 'Workflow step not found'; end if;
        perform platform.log_audit('workflow_step.deleted', 'workflow_step', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_workflow_triggers' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select wt.id, wt.tenant_id, wt.workflow_id, wt.property_id, wt.trigger_type, wt.trigger_config, wt.is_active, wt.created_at
            from public.workflow_triggers wt
            join public.operation_workflows ow on ow.id = wt.workflow_id
            where wt.workflow_id = (p_payload->>'workflow_id')::uuid and ow.tenant_id = v_tid
        ) t;

    when 'create_workflow_trigger' then
        v_tid := platform.current_tenant_id();
        select ow.tenant_id into v_workflow_tenant from public.operation_workflows ow
        where ow.id = (p_payload->>'workflow_id')::uuid and ow.tenant_id = v_tid;
        if not found then raise exception 'Workflow not found'; end if;
        insert into public.workflow_triggers (tenant_id, workflow_id, property_id, trigger_type, trigger_config, is_active)
        values (
            v_workflow_tenant,
            (p_payload->>'workflow_id')::uuid,
            case when p_payload ? 'property_id' then (p_payload->>'property_id')::uuid else null end,
            (p_payload->>'trigger_type')::public.automation_trigger_type,
            coalesce(p_payload->'trigger_config', '{}'::jsonb),
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, workflow_id, property_id, trigger_type, trigger_config, is_active, created_at into v_row;
        perform platform.log_audit('workflow_trigger.created', 'workflow_trigger', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_workflow_trigger' then
        v_tid := platform.current_tenant_id();
        update public.workflow_triggers wt set
            trigger_type = case when p_payload ? 'trigger_type'
                then (p_payload->>'trigger_type')::public.automation_trigger_type else wt.trigger_type end,
            property_id = case when p_payload ? 'property_id'
                then (p_payload->>'property_id')::uuid else wt.property_id end,
            trigger_config = case when p_payload ? 'trigger_config' then p_payload->'trigger_config' else wt.trigger_config end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else wt.is_active end
        where wt.id = (p_payload->>'id')::uuid and wt.tenant_id = v_tid
        returning wt.id, wt.tenant_id, wt.workflow_id, wt.property_id, wt.trigger_type, wt.trigger_config, wt.is_active, wt.created_at into v_row;
        if not found then raise exception 'Workflow trigger not found'; end if;
        perform platform.log_audit('workflow_trigger.updated', 'workflow_trigger', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_workflow_trigger' then
        v_tid := platform.current_tenant_id();
        delete from public.workflow_triggers wt where wt.id = (p_payload->>'id')::uuid and wt.tenant_id = v_tid;
        if not found then raise exception 'Workflow trigger not found'; end if;
        perform platform.log_audit('workflow_trigger.deleted', 'workflow_trigger', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_support_tickets' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select st.id, st.tenant_id, st.user_id, st.subject, st.description, st.status, st.priority, st.created_at, st.updated_at
            from public.support_tickets st
            where st.tenant_id = v_tid
              and (p_payload->>'status' is null or st.status::text = p_payload->>'status')
              and (p_payload->>'priority' is null or st.priority::text = p_payload->>'priority')
        ) t;

    when 'get_support_ticket' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select st.id, st.tenant_id, st.user_id, st.subject, st.description, st.status, st.priority, st.created_at, st.updated_at
            from public.support_tickets st
            where st.id = (p_payload->>'id')::uuid and st.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Support ticket not found'; end if;

    when 'create_support_ticket' then
        v_tid := platform.current_tenant_id();
        insert into public.support_tickets (tenant_id, user_id, subject, description, priority)
        values (
            v_tid,
            coalesce((p_payload->>'user_id')::uuid, v_uid),
            p_payload->>'subject',
            p_payload->>'description',
            coalesce((p_payload->>'priority')::public.priority_level, 'normal'::public.priority_level)
        )
        returning id, tenant_id, user_id, subject, description, status, priority, created_at, updated_at into v_row;
        perform platform.log_audit('support_ticket.created', 'support_ticket', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_support_ticket' then
        v_tid := platform.current_tenant_id();
        update public.support_tickets st set
            subject = case when p_payload ? 'subject' then p_payload->>'subject' else st.subject end,
            description = case when p_payload ? 'description' then p_payload->>'description' else st.description end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.support_ticket_status else st.status end,
            priority = case when p_payload ? 'priority'
                then (p_payload->>'priority')::public.priority_level else st.priority end,
            user_id = case when p_payload ? 'user_id' then (p_payload->>'user_id')::uuid else st.user_id end
        where st.id = (p_payload->>'id')::uuid and st.tenant_id = v_tid
        returning st.id, st.tenant_id, st.user_id, st.subject, st.description, st.status, st.priority, st.created_at, st.updated_at into v_row;
        if not found then raise exception 'Support ticket not found'; end if;
        perform platform.log_audit('support_ticket.updated', 'support_ticket', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_support_ticket' then
        v_tid := platform.current_tenant_id();
        delete from public.support_tickets st where st.id = (p_payload->>'id')::uuid and st.tenant_id = v_tid;
        if not found then raise exception 'Support ticket not found'; end if;
        perform platform.log_audit('support_ticket.deleted', 'support_ticket', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_support_messages' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select sm.id, sm.tenant_id, sm.ticket_id, sm.sender_type, sm.message, sm.created_at
            from public.support_messages sm
            where sm.ticket_id = (p_payload->>'ticket_id')::uuid and sm.tenant_id = v_tid
        ) t;

    when 'create_support_message' then
        v_tid := platform.current_tenant_id();
        if coalesce(p_payload->>'sender_type', 'user') <> 'user' then
            raise exception 'Tenant portal may only send user messages';
        end if;
        insert into public.support_messages (tenant_id, ticket_id, sender_type, message)
        values (
            v_tid,
            (p_payload->>'ticket_id')::uuid,
            'user'::public.support_sender_type,
            p_payload->>'message'
        )
        returning id, tenant_id, ticket_id, sender_type, message, created_at into v_row;
        perform platform.log_audit('support_message.created', 'support_message', v_row.id);
        v_result := to_jsonb(v_row);

    else
        raise exception 'unknown operations_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.operations_domain(text, jsonb) from public;
grant execute on function public.operations_domain(text, jsonb) to authenticated, service_role;


create or replace function public.preconfig_domain(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row record;
    v_result jsonb;
    v_bundle_id uuid;
    v_blueprint_id uuid;
    v_template_id uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_device_bundles' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.code), '[]'::jsonb) into v_result
        from (
            select db.id, db.code, db.version, db.name, db.description, db.property_type, db.is_active, db.is_system, db.created_at, db.updated_at
            from public.device_bundles db
            where (coalesce((p_payload->>'active_only')::boolean, true) = false or db.is_active = true)
              and (p_payload->>'property_type' is null or db.property_type::text = p_payload->>'property_type')
        ) t;

    when 'get_device_bundle' then
        if p_payload ? 'code' then
            select to_jsonb(t) into v_result from (
                select db.id, db.code, db.version, db.name, db.description, db.property_type, db.is_active, db.is_system, db.created_at, db.updated_at
                from public.device_bundles db
                where db.code = p_payload->>'code'
                  and (p_payload->>'version' is null or db.version = (p_payload->>'version')::int)
                order by db.version desc
                limit 1
            ) t;
        else
            select to_jsonb(t) into v_result from (
                select db.id, db.code, db.version, db.name, db.description, db.property_type, db.is_active, db.is_system, db.created_at, db.updated_at
                from public.device_bundles db where db.id = (p_payload->>'id')::uuid
            ) t;
        end if;
        if v_result is null then raise exception 'Device bundle not found'; end if;

    when 'list_bundle_devices' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.category_code), '[]'::jsonb) into v_result
        from (
            select bd.id, bd.bundle_id, bd.category_code, bd.quantity, bd.is_required, bd.config_hint, bd.created_at
            from public.bundle_devices bd where bd.bundle_id = (p_payload->>'bundle_id')::uuid
        ) t;

    when 'list_onboarding_blueprints' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select ob.id, ob.code, ob.name, ob.description, ob.property_type, ob.is_system, ob.is_active, ob.created_at, ob.updated_at
            from public.onboarding_blueprints ob
            where (coalesce((p_payload->>'active_only')::boolean, true) = false or ob.is_active = true)
              and (p_payload->>'property_type' is null or ob.property_type::text = p_payload->>'property_type')
        ) t;

    when 'get_onboarding_blueprint' then
        if p_payload ? 'code' then
            select id into v_blueprint_id from public.onboarding_blueprints where code = p_payload->>'code';
            if not found then raise exception 'Onboarding blueprint not found'; end if;
        else
            v_blueprint_id := (p_payload->>'id')::uuid;
        end if;
        select jsonb_build_object(
            'blueprint', (
                select to_jsonb(t) from (
                    select ob.id, ob.code, ob.name, ob.description, ob.property_type, ob.is_system, ob.is_active, ob.created_at, ob.updated_at
                    from public.onboarding_blueprints ob where ob.id = v_blueprint_id
                ) t
            ),
            'steps', coalesce((
                select jsonb_agg(to_jsonb(s) order by s.step_order)
                from (
                    select obs.id, obs.blueprint_id, obs.step_order, obs.step_type, obs.config, obs.created_at
                    from public.onboarding_blueprint_steps obs where obs.blueprint_id = v_blueprint_id
                ) s
            ), '[]'::jsonb)
        ) into v_result;
        if v_result->'blueprint' = 'null'::jsonb then raise exception 'Onboarding blueprint not found'; end if;

    when 'list_blueprint_steps' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.step_order), '[]'::jsonb) into v_result
        from (
            select obs.id, obs.blueprint_id, obs.step_order, obs.step_type, obs.config, obs.created_at
            from public.onboarding_blueprint_steps obs where obs.blueprint_id = (p_payload->>'blueprint_id')::uuid
        ) t;

    when 'list_preconfig_templates' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select pt.id, pt.device_bundle_id, pt.onboarding_blueprint_id, pt.name, pt.description, pt.property_type, pt.is_active, pt.version, pt.created_at, pt.updated_at
            from public.preconfig_templates pt
            where (coalesce((p_payload->>'active_only')::boolean, true) = false or pt.is_active = true)
              and (p_payload->>'property_type' is null or pt.property_type::text = p_payload->>'property_type')
        ) t;

    when 'get_preconfig_template' then
        v_template_id := (p_payload->>'id')::uuid;
        select pt.device_bundle_id into v_bundle_id from public.preconfig_templates pt where pt.id = v_template_id;
        if not found then raise exception 'Preconfig template not found'; end if;
        select jsonb_build_object(
            'template', (
                select to_jsonb(t) from (
                    select pt.id, pt.device_bundle_id, pt.onboarding_blueprint_id, pt.name, pt.description, pt.property_type, pt.is_active, pt.version, pt.created_at, pt.updated_at
                    from public.preconfig_templates pt where pt.id = v_template_id
                ) t
            ),
            'device_map', coalesce((
                select jsonb_agg(to_jsonb(dm) order by dm.room_type)
                from (
                    select pdm.id, pdm.template_id, pdm.category_code, pdm.room_type, pdm.recommended_protocol, pdm.default_config, pdm.created_at
                    from public.preconfig_device_map pdm where pdm.template_id = v_template_id
                ) dm
            ), '[]'::jsonb),
            'bundle_devices', coalesce((
                select jsonb_agg(to_jsonb(bd) order by bd.category_code)
                from (
                    select bd.id, bd.bundle_id, bd.category_code, bd.quantity, bd.is_required, bd.config_hint, bd.created_at
                    from public.bundle_devices bd where bd.bundle_id = v_bundle_id
                ) bd
            ), '[]'::jsonb)
        ) into v_result;

    when 'list_preconfig_device_map' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.room_type), '[]'::jsonb) into v_result
        from (
            select pdm.id, pdm.template_id, pdm.category_code, pdm.room_type, pdm.recommended_protocol, pdm.default_config, pdm.created_at
            from public.preconfig_device_map pdm where pdm.template_id = (p_payload->>'template_id')::uuid
        ) t;

    when 'create_device_bundle' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.device_bundles (code, name, description, property_type, version, is_active, is_system)
        values (
            p_payload->>'code', p_payload->>'name', p_payload->>'description',
            case when p_payload ? 'property_type' and p_payload->>'property_type' is not null
                then (p_payload->>'property_type')::public.property_type else null end,
            coalesce((p_payload->>'version')::int, 1),
            coalesce((p_payload->>'is_active')::boolean, true),
            coalesce((p_payload->>'is_system')::boolean, false)
        )
        returning id, code, version, name, description, property_type, is_active, is_system, created_at, updated_at into v_row;
        perform platform.log_audit('device_bundle.created', 'device_bundle', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_device_bundle' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.device_bundles db set
            code = case when p_payload ? 'code' then p_payload->>'code' else db.code end,
            name = case when p_payload ? 'name' then p_payload->>'name' else db.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else db.description end,
            property_type = case when p_payload ? 'property_type'
                then case when p_payload->>'property_type' is null then null else (p_payload->>'property_type')::public.property_type end
                else db.property_type end,
            version = case when p_payload ? 'version' then (p_payload->>'version')::int else db.version end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else db.is_active end,
            is_system = case when p_payload ? 'is_system' then (p_payload->>'is_system')::boolean else db.is_system end
        where db.id = (p_payload->>'id')::uuid
        returning db.id, db.code, db.version, db.name, db.description, db.property_type, db.is_active, db.is_system, db.created_at, db.updated_at into v_row;
        if not found then raise exception 'Device bundle not found'; end if;
        perform platform.log_audit('device_bundle.updated', 'device_bundle', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_device_bundle' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.device_bundles db where db.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Device bundle not found'; end if;
        perform platform.log_audit('device_bundle.deleted', 'device_bundle', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'create_bundle_device' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.bundle_devices (bundle_id, category_code, quantity, is_required, config_hint)
        values (
            (p_payload->>'bundle_id')::uuid, p_payload->>'category_code',
            coalesce((p_payload->>'quantity')::int, 1),
            coalesce((p_payload->>'is_required')::boolean, true),
            coalesce(p_payload->'config_hint', '{}'::jsonb)
        )
        returning id, bundle_id, category_code, quantity, is_required, config_hint, created_at into v_row;
        perform platform.log_audit('bundle_device.created', 'bundle_device', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_bundle_device' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.bundle_devices bd set
            quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::int else bd.quantity end,
            is_required = case when p_payload ? 'is_required' then (p_payload->>'is_required')::boolean else bd.is_required end,
            config_hint = case when p_payload ? 'config_hint' then p_payload->'config_hint' else bd.config_hint end
        where bd.id = (p_payload->>'id')::uuid
        returning bd.id, bd.bundle_id, bd.category_code, bd.quantity, bd.is_required, bd.config_hint, bd.created_at into v_row;
        if not found then raise exception 'Bundle device not found'; end if;
        perform platform.log_audit('bundle_device.updated', 'bundle_device', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_bundle_device' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.bundle_devices bd where bd.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Bundle device not found'; end if;
        perform platform.log_audit('bundle_device.deleted', 'bundle_device', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'create_onboarding_blueprint' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.onboarding_blueprints (code, name, description, property_type, is_system, is_active)
        values (
            p_payload->>'code', p_payload->>'name', p_payload->>'description',
            case when p_payload ? 'property_type' and p_payload->>'property_type' is not null
                then (p_payload->>'property_type')::public.property_type else null end,
            coalesce((p_payload->>'is_system')::boolean, false),
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, code, name, description, property_type, is_system, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('onboarding_blueprint.created', 'onboarding_blueprint', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_onboarding_blueprint' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.onboarding_blueprints ob set
            code = case when p_payload ? 'code' then p_payload->>'code' else ob.code end,
            name = case when p_payload ? 'name' then p_payload->>'name' else ob.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else ob.description end,
            property_type = case when p_payload ? 'property_type'
                then case when p_payload->>'property_type' is null then null else (p_payload->>'property_type')::public.property_type end
                else ob.property_type end,
            is_system = case when p_payload ? 'is_system' then (p_payload->>'is_system')::boolean else ob.is_system end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else ob.is_active end
        where ob.id = (p_payload->>'id')::uuid
        returning ob.id, ob.code, ob.name, ob.description, ob.property_type, ob.is_system, ob.is_active, ob.created_at, ob.updated_at into v_row;
        if not found then raise exception 'Onboarding blueprint not found'; end if;
        perform platform.log_audit('onboarding_blueprint.updated', 'onboarding_blueprint', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_onboarding_blueprint' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.onboarding_blueprints ob where ob.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Onboarding blueprint not found'; end if;
        perform platform.log_audit('onboarding_blueprint.deleted', 'onboarding_blueprint', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'create_blueprint_step' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.onboarding_blueprint_steps (blueprint_id, step_order, step_type, config)
        values (
            (p_payload->>'blueprint_id')::uuid,
            (p_payload->>'step_order')::int,
            (p_payload->>'step_type')::public.onboarding_step_type,
            coalesce(p_payload->'config', '{}'::jsonb)
        )
        returning id, blueprint_id, step_order, step_type, config, created_at into v_row;
        perform platform.log_audit('onboarding_blueprint_step.created', 'onboarding_blueprint_step', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_blueprint_step' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.onboarding_blueprint_steps obs set
            step_order = case when p_payload ? 'step_order' then (p_payload->>'step_order')::int else obs.step_order end,
            step_type = case when p_payload ? 'step_type'
                then (p_payload->>'step_type')::public.onboarding_step_type else obs.step_type end,
            config = case when p_payload ? 'config' then p_payload->'config' else obs.config end
        where obs.id = (p_payload->>'id')::uuid
        returning obs.id, obs.blueprint_id, obs.step_order, obs.step_type, obs.config, obs.created_at into v_row;
        if not found then raise exception 'Blueprint step not found'; end if;
        perform platform.log_audit('onboarding_blueprint_step.updated', 'onboarding_blueprint_step', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_blueprint_step' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.onboarding_blueprint_steps obs where obs.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Blueprint step not found'; end if;
        perform platform.log_audit('onboarding_blueprint_step.deleted', 'onboarding_blueprint_step', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'create_preconfig_template' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.preconfig_templates (
            device_bundle_id, onboarding_blueprint_id, name, description, property_type, is_active, version
        )
        values (
            (p_payload->>'device_bundle_id')::uuid,
            case when p_payload ? 'onboarding_blueprint_id' then (p_payload->>'onboarding_blueprint_id')::uuid else null end,
            p_payload->>'name', p_payload->>'description',
            case when p_payload ? 'property_type' and p_payload->>'property_type' is not null
                then (p_payload->>'property_type')::public.property_type else null end,
            coalesce((p_payload->>'is_active')::boolean, true),
            coalesce((p_payload->>'version')::int, 1)
        )
        returning id, device_bundle_id, onboarding_blueprint_id, name, description, property_type, is_active, version, created_at, updated_at into v_row;
        perform platform.log_audit('preconfig_template.created', 'preconfig_template', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_preconfig_template' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.preconfig_templates pt set
            device_bundle_id = case when p_payload ? 'device_bundle_id'
                then (p_payload->>'device_bundle_id')::uuid else pt.device_bundle_id end,
            onboarding_blueprint_id = case when p_payload ? 'onboarding_blueprint_id'
                then (p_payload->>'onboarding_blueprint_id')::uuid else pt.onboarding_blueprint_id end,
            name = case when p_payload ? 'name' then p_payload->>'name' else pt.name end,
            description = case when p_payload ? 'description' then p_payload->>'description' else pt.description end,
            property_type = case when p_payload ? 'property_type'
                then case when p_payload->>'property_type' is null then null else (p_payload->>'property_type')::public.property_type end
                else pt.property_type end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else pt.is_active end,
            version = case when p_payload ? 'version' then (p_payload->>'version')::int else pt.version end
        where pt.id = (p_payload->>'id')::uuid
        returning pt.id, pt.device_bundle_id, pt.onboarding_blueprint_id, pt.name, pt.description, pt.property_type, pt.is_active, pt.version, pt.created_at, pt.updated_at into v_row;
        if not found then raise exception 'Preconfig template not found'; end if;
        perform platform.log_audit('preconfig_template.updated', 'preconfig_template', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_preconfig_template' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.preconfig_templates pt where pt.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Preconfig template not found'; end if;
        perform platform.log_audit('preconfig_template.deleted', 'preconfig_template', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'create_preconfig_device_map' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        insert into public.preconfig_device_map (template_id, category_code, room_type, recommended_protocol, default_config)
        values (
            (p_payload->>'template_id')::uuid,
            p_payload->>'category_code',
            (p_payload->>'room_type')::public.room_type,
            case when p_payload ? 'recommended_protocol' and p_payload->>'recommended_protocol' is not null
                then (p_payload->>'recommended_protocol')::public.device_protocol else null end,
            coalesce(p_payload->'default_config', '{}'::jsonb)
        )
        returning id, template_id, category_code, room_type, recommended_protocol, default_config, created_at into v_row;
        perform platform.log_audit('preconfig_device_map.created', 'preconfig_device_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_preconfig_device_map' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        update public.preconfig_device_map pdm set
            category_code = case when p_payload ? 'category_code' then p_payload->>'category_code' else pdm.category_code end,
            room_type = case when p_payload ? 'room_type'
                then (p_payload->>'room_type')::public.room_type else pdm.room_type end,
            recommended_protocol = case when p_payload ? 'recommended_protocol'
                then case when p_payload->>'recommended_protocol' is null then null
                     else (p_payload->>'recommended_protocol')::public.device_protocol end
                else pdm.recommended_protocol end,
            default_config = case when p_payload ? 'default_config' then p_payload->'default_config' else pdm.default_config end
        where pdm.id = (p_payload->>'id')::uuid
        returning pdm.id, pdm.template_id, pdm.category_code, pdm.room_type, pdm.recommended_protocol, pdm.default_config, pdm.created_at into v_row;
        if not found then raise exception 'Preconfig device map not found'; end if;
        perform platform.log_audit('preconfig_device_map.updated', 'preconfig_device_map', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_preconfig_device_map' then
        if not platform.is_platform_admin() then raise exception 'platform admin role required'; end if;
        delete from public.preconfig_device_map pdm where pdm.id = (p_payload->>'id')::uuid;
        if not found then raise exception 'Preconfig device map not found'; end if;
        perform platform.log_audit('preconfig_device_map.deleted', 'preconfig_device_map', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        raise exception 'unknown preconfig_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.preconfig_domain(text, jsonb) from public;
grant execute on function public.preconfig_domain(text, jsonb) to authenticated, service_role;


create or replace function public.integrations_domain(
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
    v_existing uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_providers' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.is_active = true
        ) t;

    when 'get_provider' then
        select to_jsonb(t) into v_result from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.code = p_payload->>'code'
        ) t;
        if v_result is null then raise exception 'Integration provider not found'; end if;

    when 'list_capabilities' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ic.provider_code, ic.capability_code, ic.description, ic.is_supported
            from public.integration_capabilities ic
            where ic.is_supported = true
              and (p_payload->>'provider_code' is null or ic.provider_code = p_payload->>'provider_code')
        ) t;

    when 'list_tenant_integrations' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti where ti.tenant_id = v_tid
        ) t;

    when 'get_tenant_integration' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti
            where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        ) t;

    when 'connect_integration' then
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.integration_providers ip where ip.code = p_payload->>'provider_code') then
            raise exception 'Integration provider not found';
        end if;
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if found then
            update public.tenant_integrations ti set
                credentials_ref = coalesce(p_payload->>'credentials_ref', ti.credentials_ref),
                config = coalesce(p_payload->'config', ti.config),
                is_enabled = coalesce((p_payload->>'is_enabled')::boolean, ti.is_enabled)
            where ti.id = v_existing
            returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
            perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id);
        else
            insert into public.tenant_integrations (tenant_id, provider_code, credentials_ref, config, is_enabled)
            values (
                v_tid, p_payload->>'provider_code', p_payload->>'credentials_ref',
                coalesce(p_payload->'config', '{}'::jsonb),
                coalesce((p_payload->>'is_enabled')::boolean, true)
            )
            returning id, tenant_id, provider_code, credentials_ref, config, is_enabled, created_at, updated_at into v_row;
            perform platform.log_audit('integration.connected', 'tenant_integration', v_row.id,
                jsonb_build_object('provider_code', p_payload->>'provider_code'));
        end if;
        v_result := to_jsonb(v_row);

    when 'update_integration' then
        v_tid := platform.current_tenant_id();
        update public.tenant_integrations ti set
            credentials_ref = case when p_payload ? 'credentials_ref' then p_payload->>'credentials_ref' else ti.credentials_ref end,
            config = case when p_payload ? 'config' then p_payload->'config' else ti.config end,
            is_enabled = case when p_payload ? 'is_enabled' then (p_payload->>'is_enabled')::boolean else ti.is_enabled end
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
        if not found then raise exception 'Integration not found'; end if;
        perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'disconnect_integration' then
        v_tid := platform.current_tenant_id();
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if not found then raise exception 'Integration not found'; end if;
        delete from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        perform platform.log_audit('integration.disconnected', 'tenant_integration', v_existing,
            jsonb_build_object('provider_code', p_payload->>'provider_code'));
        v_result := jsonb_build_object('disconnected', true, 'provider_code', p_payload->>'provider_code');

    when 'list_webhook_definitions' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at
            from public.webhook_definitions wd
            where wd.tenant_id = v_tid
              and (p_payload->>'provider_code' is null or wd.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_webhook_definition' then
        v_tid := platform.current_tenant_id();
        insert into public.webhook_definitions (tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active)
        values (
            v_tid, p_payload->>'provider_code', p_payload->>'event_type', p_payload->>'target_url',
            p_payload->>'signing_secret_ref',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('webhook_definition.created', 'webhook_definition', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_webhook_definition' then
        v_tid := platform.current_tenant_id();
        update public.webhook_definitions wd set
            event_type = case when p_payload ? 'event_type' then p_payload->>'event_type' else wd.event_type end,
            target_url = case when p_payload ? 'target_url' then p_payload->>'target_url' else wd.target_url end,
            signing_secret_ref = case when p_payload ? 'signing_secret_ref' then p_payload->>'signing_secret_ref' else wd.signing_secret_ref end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else wd.is_active end
        where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid
        returning wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at into v_row;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.updated', 'webhook_definition', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_webhook_definition' then
        v_tid := platform.current_tenant_id();
        delete from public.webhook_definitions wd where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.deleted', 'webhook_definition', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_maps' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at
            from public.device_integration_map dim
            where dim.tenant_id = v_tid
              and (p_payload->>'device_id' is null or dim.device_id = (p_payload->>'device_id')::uuid)
              and (p_payload->>'provider_code' is null or dim.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_device_map' then
        v_tid := platform.current_tenant_id();
        insert into public.device_integration_map (device_id, provider_code, external_id, config)
        values (
            (p_payload->>'device_id')::uuid,
            p_payload->>'provider_code',
            p_payload->>'external_id',
            coalesce(p_payload->'config', '{}'::jsonb)
        )
        returning id, tenant_id, device_id, provider_code, external_id, config, created_at into v_row;
        perform platform.log_audit('device_integration_map.created', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_device_map' then
        v_tid := platform.current_tenant_id();
        update public.device_integration_map dim set
            external_id = case when p_payload ? 'external_id' then p_payload->>'external_id' else dim.external_id end,
            config = case when p_payload ? 'config' then p_payload->'config' else dim.config end
        where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid
        returning dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at into v_row;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.updated', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_device_map' then
        v_tid := platform.current_tenant_id();
        delete from public.device_integration_map dim where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.deleted', 'device_integration_map', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        raise exception 'unknown integrations_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.integrations_domain(text, jsonb) from public;
grant execute on function public.integrations_domain(text, jsonb) to authenticated, service_role;


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
        v_role := null;
        v_tenant_status := null;
        if v_tid is not null then
            select tm.role::text, t.status::text
            into v_role, v_tenant_status
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.tenant_id = v_tid and tm.user_id = v_uid and tm.is_active = true;
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
        select to_jsonb(t) into v_result from (
            select tn.id, tn.name, tn.status, tn.created_at, tn.updated_at
            from public.tenants tn where tn.id = v_tid
        ) t;
        if v_result is null then raise exception 'Tenant not found'; end if;

    when 'create_tenant' then
        if v_uid is null then raise exception 'authentication required'; end if;
        insert into public.tenants (name) values (p_payload->>'name')
        returning id, name, status, created_at, updated_at into v_row;
        perform platform.log_audit('tenant.created', 'tenant', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'created_by', v_uid));
        v_result := to_jsonb(v_row);

    when 'update_tenant' then
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
        select tm.id, tm.user_id, tm.tenant_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id = v_uid then
            if p_payload ? 'role' then raise exception 'Cannot change your own role via this endpoint'; end if;
        else
        end if;
        update public.tenant_memberships tm set
            role = case when p_payload ? 'role' then (p_payload->>'role')::public.user_role else tm.role end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else tm.is_active end,
            revoked_at = case
                when p_payload ? 'is_active' and not (p_payload->>'is_active')::boolean then now()
                when p_payload ? 'is_active' and (p_payload->>'is_active')::boolean then null
                else tm.revoked_at
            end
        where tm.id = (p_payload->>'membership_id')::uuid
        returning tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at, tm.created_at into v_row;
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
        select tm.id, tm.user_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id <> v_uid then perform public.edge_require_admin(); end if;
        delete from public.tenant_memberships tm where tm.id = (p_payload->>'membership_id')::uuid;
        perform platform.log_audit('membership.revoked', 'tenant_membership', (p_payload->>'membership_id')::uuid,
            jsonb_build_object('tenant_id', v_tid, 'revoked_by', v_uid));
        v_result := jsonb_build_object('revoked', true, 'membership_id', p_payload->>'membership_id');

    when 'get_subscription' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at
            from public.subscriptions s where s.tenant_id = v_tid
        ) t;

    when 'update_subscription' then
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.subscriptions s where s.tenant_id = v_tid) then
            raise exception 'Subscription not found for tenant';
        end if;
        update public.subscriptions s set
            tier = case when p_payload ? 'tier' then (p_payload->>'tier')::public.subscription_tier else s.tier end,
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
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at
            from public.service_accounts sa where sa.tenant_id = v_tid
        ) t;

    when 'create_service_account' then
        v_tid := platform.current_tenant_id();
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
        v_tid := platform.current_tenant_id();
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
        v_tid := platform.current_tenant_id();
        delete from public.service_accounts sa
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.deleted', 'service_account', (p_payload->>'service_account_id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'service_account_id', p_payload->>'service_account_id');

    else
        raise exception 'unknown auth_api operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.auth_domain(text, jsonb) from public;
grant execute on function public.auth_domain(text, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- 005 Integrations: OAuth completion (service_role SSOT)
-- -----------------------------------------------------

create or replace function public.integrations_complete_oauth(
    p_tenant_id uuid,
    p_provider_code text,
    p_credentials_ref text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.tenant_integrations;
begin
    if p_tenant_id is null or p_provider_code is null or p_credentials_ref is null then
        raise exception 'tenant_id, provider_code, and credentials_ref are required';
    end if;

    if not exists (
        select 1 from public.integration_providers ip where ip.code = p_provider_code
    ) then
        raise exception 'Integration provider not found';
    end if;

    insert into public.tenant_integrations (
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled
    )
    values (
        p_tenant_id,
        p_provider_code,
        p_credentials_ref,
        '{}'::jsonb,
        true
    )
    on conflict (tenant_id, provider_code) do update
        set credentials_ref = excluded.credentials_ref,
            is_enabled = true,
            updated_at = now()
    returning
        id,
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled,
        created_at,
        updated_at
    into v_row;

    perform platform.log_audit(
        'integration.oauth_completed',
        'tenant_integration',
        v_row.id,
        jsonb_build_object('provider_code', p_provider_code)
    );

    return to_jsonb(v_row);
end;
$$;

revoke all on function public.integrations_complete_oauth(uuid, text, text) from public;
grant execute on function public.integrations_complete_oauth(uuid, text, text) to service_role;
