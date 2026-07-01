-- =====================================================
-- 019 EDGE RPC BOOKING & LOCKS (REV19)
-- SQL SSOT for booking and lock edge orchestration
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('019_edge_rpc_booking_locks_rev19', 'REV19.EDGE.RPC.BOOKING_LOCKS', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. BOOKING API
-- =====================================================

create or replace function public.booking_api(
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
        when 'list_bookings' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(b) order by b.start_date desc),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    bk.id,
                    bk.tenant_id,
                    bk.property_id,
                    bk.guest_name,
                    bk.guest_email,
                    bk.start_date,
                    bk.end_date,
                    bk.status,
                    bk.created_at,
                    bk.updated_at
                from public.bookings bk
                where bk.tenant_id = v_tid
                  and (
                      p_payload->>'property_id' is null
                      or bk.property_id = (p_payload->>'property_id')::uuid
                  )
            ) b;

            return v_result;

        when 'get_booking' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select
                bk.id,
                bk.tenant_id,
                bk.property_id,
                bk.guest_name,
                bk.guest_email,
                bk.start_date,
                bk.end_date,
                bk.status,
                bk.created_at,
                bk.updated_at
            into v_row
            from public.bookings bk
            where bk.id = (p_payload->>'id')::uuid
              and bk.tenant_id = v_tid;

            if not found then
                raise exception 'Booking not found';
            end if;

            return to_jsonb(v_row);

        when 'create_booking' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            insert into public.bookings (
                tenant_id,
                property_id,
                guest_name,
                guest_email,
                start_date,
                end_date,
                status
            )
            values (
                v_tid,
                (p_payload->>'property_id')::uuid,
                p_payload->>'guest_name',
                p_payload->>'guest_email',
                (p_payload->>'start_date')::date,
                (p_payload->>'end_date')::date,
                coalesce(
                    (p_payload->>'status')::public.booking_status,
                    'pending'::public.booking_status
                )
            )
            returning
                id,
                tenant_id,
                property_id,
                guest_name,
                guest_email,
                start_date,
                end_date,
                status,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'booking.created',
                'booking',
                v_row.id,
                jsonb_build_object('property_id', v_row.property_id)
            );

            return to_jsonb(v_row);

        when 'update_booking' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            update public.bookings bk
            set
                guest_name = case
                    when p_payload ? 'guest_name' then p_payload->>'guest_name'
                    else bk.guest_name
                end,
                guest_email = case
                    when p_payload ? 'guest_email' then p_payload->>'guest_email'
                    else bk.guest_email
                end,
                start_date = case
                    when p_payload ? 'start_date' then (p_payload->>'start_date')::date
                    else bk.start_date
                end,
                end_date = case
                    when p_payload ? 'end_date' then (p_payload->>'end_date')::date
                    else bk.end_date
                end,
                status = case
                    when p_payload ? 'status' then (p_payload->>'status')::public.booking_status
                    else bk.status
                end
            where bk.id = (p_payload->>'id')::uuid
              and bk.tenant_id = v_tid
            returning
                bk.id,
                bk.tenant_id,
                bk.property_id,
                bk.guest_name,
                bk.guest_email,
                bk.start_date,
                bk.end_date,
                bk.status,
                bk.created_at,
                bk.updated_at
            into v_row;

            if not found then
                raise exception 'Booking not found';
            end if;

            perform platform.log_audit(
                'booking.updated',
                'booking',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_booking' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            delete from public.bookings bk
            where bk.id = (p_payload->>'id')::uuid
              and bk.tenant_id = v_tid;

            if not found then
                raise exception 'Booking not found';
            end if;

            perform platform.log_audit(
                'booking.deleted',
                'booking',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'get_access_schedule' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select to_jsonb(pas)
            into v_result
            from public.property_access_schedules pas
            where pas.property_id = (p_payload->>'property_id')::uuid
              and pas.tenant_id = v_tid;

            return v_result;

        when 'upsert_access_schedule' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            select pas.id
            into v_existing
            from public.property_access_schedules pas
            where pas.property_id = (p_payload->>'property_id')::uuid
              and pas.tenant_id = v_tid;

            if v_existing is not null then
                update public.property_access_schedules pas
                set
                    check_in_time = coalesce(
                        (p_payload->>'check_in_time')::time,
                        pas.check_in_time
                    ),
                    check_out_time = coalesce(
                        (p_payload->>'check_out_time')::time,
                        pas.check_out_time
                    ),
                    early_check_in_minutes = coalesce(
                        (p_payload->>'early_check_in_minutes')::int,
                        pas.early_check_in_minutes
                    ),
                    late_checkout_minutes = coalesce(
                        (p_payload->>'late_checkout_minutes')::int,
                        pas.late_checkout_minutes
                    ),
                    is_active = coalesce(
                        (p_payload->>'is_active')::boolean,
                        pas.is_active
                    )
                where pas.property_id = (p_payload->>'property_id')::uuid
                  and pas.tenant_id = v_tid
                returning
                    pas.id,
                    pas.tenant_id,
                    pas.property_id,
                    pas.check_in_time,
                    pas.check_out_time,
                    pas.early_check_in_minutes,
                    pas.late_checkout_minutes,
                    pas.is_active,
                    pas.created_at,
                    pas.updated_at
                into v_row;

                perform platform.log_audit(
                    'access_schedule.updated',
                    'property_access_schedule',
                    v_row.id
                );
            else
                insert into public.property_access_schedules (
                    tenant_id,
                    property_id,
                    check_in_time,
                    check_out_time,
                    early_check_in_minutes,
                    late_checkout_minutes,
                    is_active
                )
                values (
                    v_tid,
                    (p_payload->>'property_id')::uuid,
                    coalesce((p_payload->>'check_in_time')::time, '15:00'::time),
                    coalesce((p_payload->>'check_out_time')::time, '11:00'::time),
                    coalesce((p_payload->>'early_check_in_minutes')::int, 0),
                    coalesce((p_payload->>'late_checkout_minutes')::int, 0),
                    coalesce((p_payload->>'is_active')::boolean, true)
                )
                returning
                    id,
                    tenant_id,
                    property_id,
                    check_in_time,
                    check_out_time,
                    early_check_in_minutes,
                    late_checkout_minutes,
                    is_active,
                    created_at,
                    updated_at
                into v_row;

                perform platform.log_audit(
                    'access_schedule.created',
                    'property_access_schedule',
                    v_row.id
                );
            end if;

            return to_jsonb(v_row);

        when 'get_booking_access' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select to_jsonb(ba)
            into v_result
            from public.booking_access ba
            where ba.booking_id = (p_payload->>'booking_id')::uuid
              and ba.tenant_id = v_tid;

            return v_result;

        when 'create_booking_access' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            insert into public.booking_access (
                tenant_id,
                booking_id,
                access_type,
                valid_from,
                valid_until
            )
            values (
                v_tid,
                (p_payload->>'booking_id')::uuid,
                'guest'::public.access_type,
                (p_payload->>'valid_from')::timestamptz,
                (p_payload->>'valid_until')::timestamptz
            )
            returning
                id,
                tenant_id,
                booking_id,
                access_type,
                valid_from,
                valid_until,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'booking_access.created',
                'booking_access',
                v_row.id,
                p_payload
            );

            return to_jsonb(v_row);

        when 'delete_booking_access' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            delete from public.booking_access ba
            where ba.booking_id = (p_payload->>'booking_id')::uuid
              and ba.tenant_id = v_tid;

            if not found then
                raise exception 'Booking access not found';
            end if;

            perform platform.log_audit(
                'booking_access.deleted',
                'booking',
                (p_payload->>'booking_id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'booking_id', p_payload->>'booking_id'
            );

        when 'list_access_policies' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(ap) order by ap.created_at),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    p.id,
                    p.tenant_id,
                    p.property_id,
                    p.access_type,
                    p.valid_from,
                    p.valid_until,
                    p.is_active,
                    p.created_at,
                    p.updated_at
                from public.access_policies p
                where p.tenant_id = v_tid
                  and (
                      p_payload->>'property_id' is null
                      or p.property_id = (p_payload->>'property_id')::uuid
                  )
            ) ap;

            return v_result;

        when 'create_access_policy' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            insert into public.access_policies (
                tenant_id,
                property_id,
                access_type,
                valid_from,
                valid_until,
                is_active
            )
            values (
                v_tid,
                (p_payload->>'property_id')::uuid,
                (p_payload->>'access_type')::public.access_type,
                (p_payload->>'valid_from')::timestamptz,
                (p_payload->>'valid_until')::timestamptz,
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                property_id,
                access_type,
                valid_from,
                valid_until,
                is_active,
                created_at,
                updated_at
            into v_row;

            perform platform.log_audit(
                'access_policy.created',
                'access_policy',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_access_policy' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            update public.access_policies ap
            set
                access_type = case
                    when p_payload ? 'access_type'
                        then (p_payload->>'access_type')::public.access_type
                    else ap.access_type
                end,
                valid_from = case
                    when p_payload ? 'valid_from'
                        then (p_payload->>'valid_from')::timestamptz
                    else ap.valid_from
                end,
                valid_until = case
                    when p_payload ? 'valid_until'
                        then (p_payload->>'valid_until')::timestamptz
                    else ap.valid_until
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else ap.is_active
                end
            where ap.id = (p_payload->>'id')::uuid
              and ap.tenant_id = v_tid
            returning
                ap.id,
                ap.tenant_id,
                ap.property_id,
                ap.access_type,
                ap.valid_from,
                ap.valid_until,
                ap.is_active,
                ap.created_at,
                ap.updated_at
            into v_row;

            if not found then
                raise exception 'Access policy not found';
            end if;

            perform platform.log_audit(
                'access_policy.updated',
                'access_policy',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_access_policy' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            delete from public.access_policies ap
            where ap.id = (p_payload->>'id')::uuid
              and ap.tenant_id = v_tid;

            if not found then
                raise exception 'Access policy not found';
            end if;

            perform platform.log_audit(
                'access_policy.deleted',
                'access_policy',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_access_rules' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(ar) order by ar.created_at),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    r.id,
                    r.tenant_id,
                    r.property_id,
                    r.rule_type,
                    r.rule_config,
                    r.is_active,
                    r.created_at
                from public.access_rules r
                where r.tenant_id = v_tid
                  and (
                      p_payload->>'property_id' is null
                      or r.property_id = (p_payload->>'property_id')::uuid
                  )
            ) ar;

            return v_result;

        when 'create_access_rule' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            insert into public.access_rules (
                tenant_id,
                property_id,
                rule_type,
                rule_config,
                is_active
            )
            values (
                v_tid,
                (p_payload->>'property_id')::uuid,
                (p_payload->>'rule_type')::public.access_rule_type,
                p_payload->'rule_config',
                coalesce((p_payload->>'is_active')::boolean, true)
            )
            returning
                id,
                tenant_id,
                property_id,
                rule_type,
                rule_config,
                is_active,
                created_at
            into v_row;

            perform platform.log_audit(
                'access_rule.created',
                'access_rule',
                v_row.id
            );

            return to_jsonb(v_row);

        when 'update_access_rule' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            update public.access_rules ar
            set
                rule_type = case
                    when p_payload ? 'rule_type'
                        then (p_payload->>'rule_type')::public.access_rule_type
                    else ar.rule_type
                end,
                rule_config = case
                    when p_payload ? 'rule_config' then p_payload->'rule_config'
                    else ar.rule_config
                end,
                is_active = case
                    when p_payload ? 'is_active'
                        then (p_payload->>'is_active')::boolean
                    else ar.is_active
                end
            where ar.id = (p_payload->>'id')::uuid
              and ar.tenant_id = v_tid
            returning
                ar.id,
                ar.tenant_id,
                ar.property_id,
                ar.rule_type,
                ar.rule_config,
                ar.is_active,
                ar.created_at
            into v_row;

            if not found then
                raise exception 'Access rule not found';
            end if;

            perform platform.log_audit(
                'access_rule.updated',
                'access_rule',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_access_rule' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            delete from public.access_rules ar
            where ar.id = (p_payload->>'id')::uuid
              and ar.tenant_id = v_tid;

            if not found then
                raise exception 'Access rule not found';
            end if;

            perform platform.log_audit(
                'access_rule.deleted',
                'access_rule',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        else
            raise exception 'unknown booking operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.booking_api(text, jsonb) from public;
grant execute on function public.booking_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- 2. LOCKS API
-- =====================================================

create or replace function public.locks_api(
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
    v_lock record;
    v_existing record;
    v_command_id uuid;
    v_correlation_id uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
        when 'list_lock_devices' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(ld) order by ld.created_at),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    l.id,
                    l.tenant_id,
                    l.device_id,
                    l.property_id,
                    l.is_primary,
                    l.created_at
                from public.lock_devices l
                where l.tenant_id = v_tid
                  and (
                      p_payload->>'property_id' is null
                      or l.property_id = (p_payload->>'property_id')::uuid
                  )
            ) ld;

            return v_result;

        when 'get_lock_device' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select
                l.id,
                l.tenant_id,
                l.device_id,
                l.property_id,
                l.is_primary,
                l.created_at
            into v_row
            from public.lock_devices l
            where l.id = (p_payload->>'id')::uuid
              and l.tenant_id = v_tid;

            if not found then
                raise exception 'Lock device not found';
            end if;

            return to_jsonb(v_row);

        when 'create_lock_device' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            insert into public.lock_devices (
                tenant_id,
                device_id,
                property_id,
                is_primary
            )
            values (
                v_tid,
                (p_payload->>'device_id')::uuid,
                (p_payload->>'property_id')::uuid,
                coalesce((p_payload->>'is_primary')::boolean, false)
            )
            returning
                id,
                tenant_id,
                device_id,
                property_id,
                is_primary,
                created_at
            into v_row;

            perform platform.log_audit(
                'lock_device.created',
                'lock_device',
                v_row.id,
                p_payload
            );

            return to_jsonb(v_row);

        when 'update_lock_device' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            update public.lock_devices ld
            set
                is_primary = case
                    when p_payload ? 'is_primary'
                        then (p_payload->>'is_primary')::boolean
                    else ld.is_primary
                end
            where ld.id = (p_payload->>'id')::uuid
              and ld.tenant_id = v_tid
            returning
                ld.id,
                ld.tenant_id,
                ld.device_id,
                ld.property_id,
                ld.is_primary,
                ld.created_at
            into v_row;

            if not found then
                raise exception 'Lock device not found';
            end if;

            perform platform.log_audit(
                'lock_device.updated',
                'lock_device',
                v_row.id,
                p_payload - 'id'
            );

            return to_jsonb(v_row);

        when 'delete_lock_device' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            delete from public.lock_devices ld
            where ld.id = (p_payload->>'id')::uuid
              and ld.tenant_id = v_tid;

            if not found then
                raise exception 'Lock device not found';
            end if;

            perform platform.log_audit(
                'lock_device.deleted',
                'lock_device',
                (p_payload->>'id')::uuid
            );

            return jsonb_build_object(
                'deleted', true,
                'id', p_payload->>'id'
            );

        when 'list_credentials' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select coalesce(
                jsonb_agg(to_jsonb(ac) order by ac.created_at),
                '[]'::jsonb
            )
            into v_result
            from (
                select
                    c.id,
                    c.tenant_id,
                    c.booking_id,
                    c.lock_device_id,
                    c.booking_access_id,
                    c.provider_code,
                    c.credential_ref,
                    c.external_credential_id,
                    c.status,
                    c.valid_from,
                    c.valid_until,
                    c.revoked_at,
                    c.created_at,
                    c.updated_at
                from public.access_credentials c
                where c.tenant_id = v_tid
                  and (
                      p_payload->>'booking_id' is null
                      or c.booking_id = (p_payload->>'booking_id')::uuid
                  )
            ) ac;

            return v_result;

        when 'get_credential' then
            perform public.edge_require_tenant();
            v_tid := platform.current_tenant_id();

            select
                c.id,
                c.tenant_id,
                c.booking_id,
                c.lock_device_id,
                c.booking_access_id,
                c.provider_code,
                c.credential_ref,
                c.external_credential_id,
                c.status,
                c.valid_from,
                c.valid_until,
                c.revoked_at,
                c.created_at,
                c.updated_at
            into v_row
            from public.access_credentials c
            where c.id = (p_payload->>'id')::uuid
              and c.tenant_id = v_tid;

            if not found then
                raise exception 'Credential not found';
            end if;

            return to_jsonb(v_row);

        when 'issue_credential' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            select
                ld.id,
                ld.tenant_id,
                ld.device_id,
                ld.property_id
            into v_lock
            from public.lock_devices ld
            where ld.id = (p_payload->>'lock_device_id')::uuid
              and ld.tenant_id = v_tid;

            if not found then
                raise exception 'Lock device not found for tenant';
            end if;

            insert into public.access_credentials (
                tenant_id,
                booking_id,
                lock_device_id,
                booking_access_id,
                credential_ref,
                status,
                valid_from,
                valid_until
            )
            values (
                v_tid,
                (p_payload->>'booking_id')::uuid,
                (p_payload->>'lock_device_id')::uuid,
                nullif(p_payload->>'booking_access_id', '')::uuid,
                p_payload->>'credential_ref',
                'pending'::public.access_credential_status,
                coalesce(
                    (p_payload->>'valid_from')::timestamptz,
                    now()
                ),
                coalesce(
                    (p_payload->>'valid_until')::timestamptz,
                    now() + interval '1 day'
                )
            )
            returning
                id,
                tenant_id,
                booking_id,
                lock_device_id,
                booking_access_id,
                provider_code,
                credential_ref,
                external_credential_id,
                status,
                valid_from,
                valid_until,
                revoked_at,
                created_at,
                updated_at
            into v_row;

            v_correlation_id := gen_random_uuid();

            insert into platform.device_commands (
                tenant_id,
                user_id,
                device_id,
                correlation_id,
                idempotency_key,
                command_type,
                payload,
                status
            )
            values (
                v_tid,
                auth.uid(),
                v_lock.device_id,
                v_correlation_id,
                coalesce(
                    p_payload->>'idempotency_key',
                    'credential-issue-' || v_row.id::text
                ),
                'issue_credential',
                jsonb_build_object(
                    'credential_id', v_row.id,
                    'booking_id', v_row.booking_id,
                    'lock_device_id', v_row.lock_device_id,
                    'credential_ref', v_row.credential_ref
                ),
                'queued'
            )
            returning id into v_command_id;

            perform platform.log_audit(
                'credential.issue_requested',
                'access_credential',
                v_row.id,
                jsonb_build_object('command_id', v_command_id)
            );

            return jsonb_build_object(
                'credential', to_jsonb(v_row),
                'command_id', v_command_id,
                'correlation_id', v_correlation_id
            );

        when 'revoke_credential' then
            perform public.edge_require_manager();
            v_tid := platform.current_tenant_id();

            select
                c.id,
                c.tenant_id,
                c.booking_id,
                c.lock_device_id,
                c.booking_access_id,
                c.provider_code,
                c.credential_ref,
                c.external_credential_id,
                c.status,
                c.valid_from,
                c.valid_until,
                c.revoked_at,
                c.created_at,
                c.updated_at
            into v_existing
            from public.access_credentials c
            where c.id = (p_payload->>'credential_id')::uuid
              and c.tenant_id = v_tid;

            if not found then
                raise exception 'Credential not found';
            end if;

            select
                ld.id,
                ld.device_id
            into v_lock
            from public.lock_devices ld
            where ld.id = v_existing.lock_device_id;

            if not found then
                raise exception 'Lock device not found';
            end if;

            update public.access_credentials c
            set status = 'revoked'::public.access_credential_status
            where c.id = v_existing.id
            returning
                c.id,
                c.tenant_id,
                c.booking_id,
                c.lock_device_id,
                c.booking_access_id,
                c.provider_code,
                c.credential_ref,
                c.external_credential_id,
                c.status,
                c.valid_from,
                c.valid_until,
                c.revoked_at,
                c.created_at,
                c.updated_at
            into v_row;

            v_correlation_id := gen_random_uuid();

            insert into platform.device_commands (
                tenant_id,
                user_id,
                device_id,
                correlation_id,
                idempotency_key,
                command_type,
                payload,
                status
            )
            values (
                v_tid,
                auth.uid(),
                v_lock.device_id,
                v_correlation_id,
                coalesce(
                    p_payload->>'idempotency_key',
                    'credential-revoke-' || v_existing.id::text
                ),
                'revoke_credential',
                jsonb_build_object(
                    'credential_id', v_existing.id,
                    'external_credential_id', v_existing.external_credential_id
                ),
                'queued'
            )
            returning id into v_command_id;

            perform platform.log_audit(
                'credential.revoke_requested',
                'access_credential',
                v_existing.id,
                jsonb_build_object('command_id', v_command_id)
            );

            return jsonb_build_object(
                'credential', to_jsonb(v_row),
                'command_id', v_command_id,
                'correlation_id', v_correlation_id
            );

        else
            raise exception 'unknown locks operation: %', p_op;
    end case;
end;
$$;

revoke all on function public.locks_api(text, jsonb) from public;
grant execute on function public.locks_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- END 019 EDGE RPC BOOKING & LOCKS
-- =====================================================
