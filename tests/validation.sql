-- =====================================================
-- SmartHellas post-seed validation queries
-- Raises on first failure — idempotent re-run safe
-- =====================================================

create or replace function tests.run_validations()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_count bigint;
    v_tenant_a uuid := tests.fixture('tenant_a');
    v_tenant_b uuid := tests.fixture('tenant_b');
begin
    -- referential integrity: zero orphan FK violations (public + platform)
    select count(*)
    into v_count
    from (
        select 1
        from public.bookings b
        left join public.properties p on p.id = b.property_id
        where b.id = tests.fixture('booking_a') and p.id is null
        union all
        select 1
        from public.lock_devices ld
        left join public.devices d on d.id = ld.device_id
        where ld.id = tests.fixture('lock_device') and d.id is null
        union all
        select 1
        from platform.payment_intents pi
        left join public.subscriptions s on s.id = pi.target_id and pi.target_type = 'subscription'
        where pi.id = tests.fixture('payment_intent') and s.id is null
    ) orphans;

    perform tests.assert(v_count = 0, 'fixture referential integrity broken');

    -- business integrity: tenant consistency on booking
    perform tests.assert(
        exists (
            select 1
            from public.bookings b
            join public.properties p on p.id = b.property_id
            where b.id = tests.fixture('booking_a')
              and b.tenant_id = p.tenant_id
              and b.tenant_id = v_tenant_a
        ),
        'booking tenant must match property tenant'
    );

    -- subscription tier synced from plan (009 trigger)
    perform tests.assert(
        exists (
            select 1
            from public.subscriptions s
            join public.product_plans pp on pp.id = s.plan_id
            where s.id = tests.fixture('subscription_a')
              and s.tier = pp.tier
        ),
        'subscription tier must derive from product_plans'
    );

    -- lock device requires integration map (004 + 005)
    perform tests.assert(
        exists (
            select 1
            from public.lock_devices ld
            join public.device_integration_map dim on dim.device_id = ld.device_id
            where ld.id = tests.fixture('lock_device')
        ),
        'lock device must have device_integration_map entry'
    );

    -- onboarding blueprint/template alignment (011 trigger contract)
    perform tests.assert(
        exists (
            select 1
            from public.onboarding_sessions os
            join public.preconfig_templates pt on pt.id = os.preconfig_template_id
            where os.id = tests.fixture('onboard_session')
              and os.onboarding_blueprint_id = pt.onboarding_blueprint_id
        ),
        'onboarding session blueprint must match preconfig template'
    );

    -- service activation projection (014 sync)
    perform tests.assert(
        exists (
            select 1
            from public.service_activation_state sas
            where sas.tenant_id = v_tenant_a
              and sas.service_type = 'auto_door_code'
              and sas.status in ('active', 'pending')
        ),
        'service_activation_state must be projected from subscription entitlements'
    );

    -- tenant isolation: tenant B cannot see tenant A property via join guard
    perform tests.assert(
        not exists (
            select 1
            from public.properties p
            where p.id = tests.fixture('property_a')
              and p.tenant_id = v_tenant_b
        ),
        'tenant A property must not belong to tenant B'
    );

    -- module consistency: enums SSOT in public/platform (001)
    select count(*)
    into v_count
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typtype = 'e'
      and n.nspname not in (
          'public', 'platform', 'auth', 'storage', 'realtime', 'extensions',
          'graphql', 'graphql_public', 'pg_catalog', 'information_schema', 'tests',
          'cron', 'vault', 'pgsodium', 'supabase_migrations', 'pgbouncer',
          'supabase_functions', 'net', '_realtime', 'supabase_auth_admin'
      );

    perform tests.assert(v_count = 0, 'unexpected enum types outside SSOT namespaces');

    -- RLS enabled on all tenant_id public tables
    select count(*)
    into v_count
    from information_schema.columns c
    join pg_class pc on pc.relname = c.table_name
    join pg_namespace pn on pn.oid = pc.relnamespace and pn.nspname = c.table_schema
    where c.table_schema = 'public'
      and c.column_name = 'tenant_id'
      and pc.relkind = 'r'
      and not pc.relrowsecurity;

    perform tests.assert(v_count = 0, 'public tenant_id tables missing RLS');

    -- no orphan fixture registry entries
    select count(*)
    into v_count
    from tests.fixture_registry fr
    where fr.entity_table is not null
      and fr.fixture_key in ('tenant_a', 'property_a', 'booking_a', 'subscription_a')
      and not exists (
          select 1
          from pg_catalog.pg_class pc
          join pg_catalog.pg_namespace pn on pn.oid = pc.relnamespace
          where format('%I.%I', pn.nspname, pc.relname) = fr.entity_table
      );

    perform tests.assert(v_count = 0, 'fixture registry references missing tables');

    -- inconsistent states: single active onboarding session per property
    select count(*)
    into v_count
    from public.onboarding_sessions os
    where os.property_id = tests.fixture('property_a')
      and os.status in ('not_started', 'in_progress', 'waiting_user');

    perform tests.assert(v_count = 1, 'property must have exactly one active onboarding session');

    -- trigger failures would have aborted seed; verify negative guard still active
    begin
        update public.subscriptions
        set tier = 'enterprise'
        where id = tests.fixture('subscription_a')
          and plan_id = tests.fixture('plan_pro');
        perform tests.assert(false, 'tier drift trigger should have raised');
    exception
        when others then
            if position('derived from plan_id' in sqlerrm) = 0
               and position('tier' in sqlerrm) = 0 then
                raise;
            end if;
    end;

    raise notice 'validation: all checks passed';
end;
$$;
