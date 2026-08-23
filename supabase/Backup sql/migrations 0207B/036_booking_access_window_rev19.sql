-- =====================================================
-- 036 BOOKING ACCESS WINDOW (004 SSOT)
-- Window calculation from booking dates + property schedules + rules.
-- Edge must never compute timestamps.
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('036_booking_access_window_rev19', 'REV19.DOMAIN.BOOKING.ACCESS_WINDOW', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. CORE CALCULATION (004 SSOT)
-- =====================================================

create or replace function public.booking_compute_access_window(p_booking_id uuid)
returns table (
    valid_from timestamptz,
    valid_until timestamptz,
    property_id uuid,
    timezone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_booking record;
    v_schedule record;
    v_tz text;
    v_from timestamptz;
    v_until timestamptz;
    v_rule record;
    v_extend_early int := 0;
    v_extend_late int := 0;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    select bk.id, bk.tenant_id, bk.property_id, bk.start_date, bk.end_date, bk.status
    into v_booking
    from public.bookings bk
    where bk.id = p_booking_id and bk.tenant_id = v_tid;

    if not found then
        raise exception 'Booking not found';
    end if;

    select coalesce(p.timezone, 'UTC') into v_tz
    from public.properties p
    where p.id = v_booking.property_id and p.tenant_id = v_tid;

    select
        coalesce(pas.check_in_time, '15:00'::time) as check_in_time,
        coalesce(pas.check_out_time, '11:00'::time) as check_out_time,
        coalesce(pas.early_check_in_minutes, 0) as early_check_in_minutes,
        coalesce(pas.late_checkout_minutes, 0) as late_checkout_minutes,
        coalesce(pas.is_active, true) as is_active
    into v_schedule
    from public.property_access_schedules pas
    where pas.property_id = v_booking.property_id and pas.tenant_id = v_tid;

    if v_schedule is null or v_schedule.is_active = true then
        v_from := (v_booking.start_date::timestamp + coalesce(v_schedule.check_in_time, '15:00'::time))
            at time zone coalesce(v_tz, 'UTC')
            - make_interval(mins => coalesce(v_schedule.early_check_in_minutes, 0));
        v_until := (v_booking.end_date::timestamp + coalesce(v_schedule.check_out_time, '11:00'::time))
            at time zone coalesce(v_tz, 'UTC')
            + make_interval(mins => coalesce(v_schedule.late_checkout_minutes, 0));
    else
        v_from := (v_booking.start_date::timestamp + '15:00'::time) at time zone coalesce(v_tz, 'UTC');
        v_until := (v_booking.end_date::timestamp + '11:00'::time) at time zone coalesce(v_tz, 'UTC');
    end if;

    for v_rule in
        select ar.rule_type, ar.rule_config
        from public.access_rules ar
        where ar.property_id = v_booking.property_id
          and ar.tenant_id = v_tid
          and ar.is_active = true
    loop
        if v_rule.rule_config ? 'extend_early_minutes' then
            v_extend_early := v_extend_early + coalesce((v_rule.rule_config->>'extend_early_minutes')::int, 0);
        end if;
        if v_rule.rule_config ? 'extend_late_minutes' then
            v_extend_late := v_extend_late + coalesce((v_rule.rule_config->>'extend_late_minutes')::int, 0);
        end if;
        if v_rule.rule_type = 'override'::public.access_rule_type
           and v_rule.rule_config ? 'valid_from'
           and v_rule.rule_config ? 'valid_until' then
            v_from := least(v_from, (v_rule.rule_config->>'valid_from')::timestamptz);
            v_until := greatest(v_until, (v_rule.rule_config->>'valid_until')::timestamptz);
        end if;
    end loop;

    v_from := v_from - make_interval(mins => v_extend_early);
    v_until := v_until + make_interval(mins => v_extend_late);

    for v_rule in
        select ap.valid_from as pf, ap.valid_until as pu
        from public.access_policies ap
        where ap.property_id = v_booking.property_id
          and ap.tenant_id = v_tid
          and ap.is_active = true
          and ap.access_type = 'scheduled'::public.access_type
          and tstzrange(ap.valid_from, ap.valid_until) && tstzrange(v_from, v_until)
    loop
        v_from := least(v_from, v_rule.pf);
        v_until := greatest(v_until, v_rule.pu);
    end loop;

    if v_from >= v_until then
        raise exception 'Computed access window is invalid for booking %', p_booking_id;
    end if;

    return query
    select v_from, v_until, v_booking.property_id, coalesce(v_tz, 'UTC');
end;
$$;

revoke all on function public.booking_compute_access_window(uuid) from public;
grant execute on function public.booking_compute_access_window(uuid) to authenticated, service_role;

-- =====================================================
-- 2. BOOKING DOMAIN RPC HELPERS (004)
-- =====================================================

create or replace function public.booking_calculate_access_window(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    return (
        select jsonb_build_object(
            'booking_id', p_booking_id,
            'valid_from', w.valid_from,
            'valid_until', w.valid_until,
            'property_id', w.property_id,
            'timezone', w.timezone
        )
        from public.booking_compute_access_window(p_booking_id) w
    );
end;
$$;

create or replace function public.booking_generate_booking_access(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_window record;
    v_row record;
begin
    perform public.edge_require_manager();
    v_tid := platform.current_tenant_id();

    select * into v_window from public.booking_compute_access_window(p_booking_id);

    insert into public.booking_access (
        tenant_id, booking_id, access_type, valid_from, valid_until
    )
    values (
        v_tid, p_booking_id, 'guest'::public.access_type,
        v_window.valid_from, v_window.valid_until
    )
    on conflict (booking_id) do nothing
    returning id, tenant_id, booking_id, access_type, valid_from, valid_until,
              created_at, updated_at into v_row;

    if not found then
        select ba.id, ba.tenant_id, ba.booking_id, ba.access_type, ba.valid_from,
               ba.valid_until, ba.created_at, ba.updated_at
        into v_row
        from public.booking_access ba
        where ba.booking_id = p_booking_id and ba.tenant_id = v_tid;
    else
        perform platform.log_audit('booking_access.generated', 'booking_access', v_row.id);
    end if;

    return to_jsonb(v_row);
end;
$$;

create or replace function public.booking_regenerate_booking_access(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_window record;
    v_row record;
begin
    perform public.edge_require_manager();
    v_tid := platform.current_tenant_id();

    select * into v_window from public.booking_compute_access_window(p_booking_id);

    update public.booking_access ba set
        valid_from = v_window.valid_from,
        valid_until = v_window.valid_until,
        updated_at = now()
    where ba.booking_id = p_booking_id and ba.tenant_id = v_tid
    returning ba.id, ba.tenant_id, ba.booking_id, ba.access_type, ba.valid_from,
              ba.valid_until, ba.created_at, ba.updated_at into v_row;

    if not found then
        insert into public.booking_access (
            tenant_id, booking_id, access_type, valid_from, valid_until
        )
        values (
            v_tid, p_booking_id, 'guest'::public.access_type,
            v_window.valid_from, v_window.valid_until
        )
        returning id, tenant_id, booking_id, access_type, valid_from, valid_until,
                  created_at, updated_at into v_row;
    end if;

    perform platform.log_audit(
        'booking_access.regenerated',
        'booking_access',
        v_row.id,
        jsonb_build_object('booking_id', p_booking_id)
    );

    return to_jsonb(v_row);
end;
$$;

revoke all on function public.booking_calculate_access_window(uuid) from public;
grant execute on function public.booking_calculate_access_window(uuid) to authenticated, service_role;

revoke all on function public.booking_generate_booking_access(uuid) from public;
grant execute on function public.booking_generate_booking_access(uuid) to authenticated, service_role;

revoke all on function public.booking_regenerate_booking_access(uuid) from public;
grant execute on function public.booking_regenerate_booking_access(uuid) to authenticated, service_role;

-- =====================================================
-- 3. BOOKING ACCESS CREATE (004 SSOT — compat wrapper)
-- Manual override when valid_from/valid_until supplied; otherwise computed generate.
-- =====================================================

create or replace function public.booking_create_booking_access(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_row record;
begin
    perform public.edge_require_manager();
    p_payload := coalesce(p_payload, '{}'::jsonb);

    if not (p_payload ? 'valid_from') or not (p_payload ? 'valid_until') then
        return public.booking_generate_booking_access((p_payload->>'booking_id')::uuid);
    end if;

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
end;
$$;

revoke all on function public.booking_create_booking_access(jsonb) from public;
grant execute on function public.booking_create_booking_access(jsonb) to authenticated, service_role;

-- =====================================================
-- END 036 BOOKING ACCESS WINDOW
-- =====================================================
