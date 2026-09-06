-- =====================================================
-- 020 PLATFORM BOOTSTRAP
-- REV22 / CURRENT ARCHITECTURE
-- =====================================================
--
-- FINAL ORDER:
--
-- 000 Supabase Platform
-- 001 Core Types
-- 002 Core SaaS
-- 003 CRM
-- 004 Property / Device
-- 005 Booking / Lock
-- 006 Device Telemetry
-- 007 Integration
-- 008 Operations
-- 009 Preconfig
-- 010 Logistics
-- 011 Commerce
-- 012 Service Portal
-- 013 Onboarding
-- 014 Optimization
-- 015 Customer Proposal / Monetization
-- 016 Automation
-- 017 Edge / RPC Foundation
-- 018 Security Hardening
-- 019 Grant Matrix
-- 020 Platform Bootstrap
-- 021 Production Finalize
--
-- =====================================================
-- 020 RESPONSIBILITY
-- =====================================================
--
-- 020 is the FINAL CROSS-MODULE PLATFORM BINDING LAYER.
--
-- 020 MAY:
-- - bind types defined by earlier SSOT modules
-- - add final cross-module foreign keys
-- - install platform-owned execution workers
-- - register platform scheduled jobs
-- - finalize RLS safety-net coverage
-- - verify telemetry/platform boundaries
-- - finalize platform payment bindings
-- - verify integration/webhook boundaries
-- - register migration completion
--
-- 020 MUST NOT:
-- - create domain tables
-- - create telemetry SSOT tables
-- - create integration SSOT tables
-- - create business logic
-- - create provider-specific logic
-- - replace explicit domain RLS policies
-- - define the canonical grant matrix
-- - grant blanket CRUD to authenticated
--
-- OWNERSHIP:
--
-- 006 = Device Telemetry Engine
--      - device_telemetry_raw
--      - raw telemetry SSOT
--
-- 007 = Integration Engine
--      - integration_providers
--      - tenant_integrations
--      - device_integration_map
--      - OAuth
--      - webhook mappings
--      - provider identity resolution
--      - integration webhook routing
--
-- 000 = Platform
--      - external_webhooks
--      - payment execution state
--      - platform queues
--      - platform workers
--      - platform scheduling
--
-- 019 = Grant Matrix
--      - canonical application grants
--
-- 020 = final binding / verification only
--
-- =====================================================


-- =====================================================
-- 0. REQUIRED PRECONDITIONS
-- =====================================================
--
-- 020 is not allowed to silently bootstrap an incomplete
-- domain stack.
--
-- These are architectural prerequisites, not business data.
-- =====================================================

do $$
begin

    if to_regclass('public.tenants') is null then
        raise exception
            '020 prerequisite failed: public.tenants is missing (002)';
    end if;

    if to_regclass('public.devices') is null then
        raise exception
            '020 prerequisite failed: public.devices is missing (004)';
    end if;

    if to_regclass('public.device_telemetry_raw') is null then
        raise exception
            '020 prerequisite failed: public.device_telemetry_raw is missing (006)';
    end if;

    if to_regclass('public.integration_providers') is null then
        raise exception
            '020 prerequisite failed: public.integration_providers is missing (007)';
    end if;

    if to_regclass('public.device_integration_map') is null then
        raise exception
            '020 prerequisite failed: public.device_integration_map is missing (007)';
    end if;

    if to_regclass('platform.external_webhooks') is null then
        raise exception
            '020 prerequisite failed: platform.external_webhooks is missing (000)';
    end if;

    if to_regclass('platform.payment_intents') is null then
        raise exception
            '020 prerequisite failed: platform.payment_intents is missing (000)';
    end if;

    if to_regclass('platform.scheduled_jobs') is null then
        raise exception
            '020 prerequisite failed: platform.scheduled_jobs is missing (000)';
    end if;

end $$;


-- =====================================================
-- 1. POST-DOMAIN TYPE BINDS
-- 001 → 000
-- =====================================================

select platform.bind_operation_context_type_column();


-- =====================================================
-- 1A. PAYMENT STATUS TYPE BIND
-- 001 payment_status → 000 payment execution
-- =====================================================

do $$
begin

    if to_regclass('platform.payment_intents') is not null
       and to_regtype('public.payment_status') is not null
    then

        alter table platform.payment_intents
            alter column status drop default;

        alter table platform.payment_intents
            alter column status type public.payment_status
            using status::public.payment_status;

        alter table platform.payment_intents
            alter column status
            set default 'pending'::public.payment_status;

    end if;

end $$;


do $$
begin

    if to_regclass('platform.payment_events') is not null
       and to_regtype('public.payment_status') is not null
    then

        alter table platform.payment_events
            alter column old_status type public.payment_status
            using old_status::public.payment_status;

        alter table platform.payment_events
            alter column new_status type public.payment_status
            using new_status::public.payment_status;

    end if;

end $$;


-- =====================================================
-- 2. PLATFORM ↔ DOMAIN FOREIGN KEY BINDS
-- =====================================================


-- -----------------------------------------------------
-- 2.1 PAYMENT → INTEGRATION PROVIDER
--
-- 007 owns integration_providers.
-- 000 owns payment execution state.
-- -----------------------------------------------------

do $$
begin

    if to_regclass('platform.payment_intents') is not null
       and to_regclass('public.integration_providers') is not null
    then

        begin
            alter table platform.payment_intents
                add constraint fk_payment_intents_provider_code
                foreign key (provider)
                references public.integration_providers(code);
        exception
            when duplicate_object then null;
        end;

    end if;

end $$;


do $$
begin

    if to_regclass('platform.payment_provider_refs') is not null
       and to_regclass('public.integration_providers') is not null
    then

        begin
            alter table platform.payment_provider_refs
                add constraint fk_payment_provider_refs_provider_code
                foreign key (provider)
                references public.integration_providers(code);
        exception
            when duplicate_object then null;
        end;

    end if;

end $$;


-- -----------------------------------------------------
-- 2.2 PAYMENT → TENANT
-- -----------------------------------------------------

do $$
begin

    if to_regclass('platform.payment_intents') is not null
       and to_regclass('public.tenants') is not null
    then

        begin
            alter table platform.payment_intents
                add constraint fk_payment_intents_tenant
                foreign key (tenant_id)
                references public.tenants(id)
                on delete cascade;
        exception
            when duplicate_object then null;
        end;

    end if;

end $$;


-- -----------------------------------------------------
-- 2.3 WEBHOOK PROVIDER/TENANT MAP → TENANT
-- -----------------------------------------------------

do $$
begin

    if to_regclass('platform.webhook_provider_tenant_map') is not null
       and to_regclass('public.tenants') is not null
    then

        begin
            alter table platform.webhook_provider_tenant_map
                add constraint fk_webhook_provider_tenant_map_tenant
                foreign key (tenant_id)
                references public.tenants(id)
                on delete cascade;
        exception
            when duplicate_object then null;
        end;

    end if;

end $$;


-- =====================================================
-- 3. PAYMENT TARGET CONTRACT
-- =====================================================
--
-- target_type is intentionally constrained here because
-- platform.payment_intents is platform execution state.
--
-- Actual target ownership remains in domain modules.
-- =====================================================

do $$
begin

    if to_regclass('platform.payment_intents') is not null then

        begin
            alter table platform.payment_intents
                add constraint chk_payment_intents_target_type
                check (
                    target_type in (
                        'subscription',
                        'proposal',
                        'invoice'
                    )
                );
        exception
            when duplicate_object then null;
        end;

    end if;

end $$;


-- =====================================================
-- 4. PAYMENT TARGET TENANT INTEGRITY
-- =====================================================
--
-- The trigger function is platform-owned infrastructure
-- already defined in 000.
--
-- The target records remain domain-owned.
-- =====================================================

do $$
begin

    if to_regclass('platform.payment_intents') is not null
       and to_regprocedure(
            'platform.enforce_payment_intent_target_tenant()'
          ) is not null
    then

        drop trigger if exists
            trg_payment_intents_target_tenant
            on platform.payment_intents;

        create trigger
            trg_payment_intents_target_tenant
        before insert or update of
            tenant_id,
            target_type,
            target_id
        on platform.payment_intents
        for each row
        execute function platform.enforce_payment_intent_target_tenant();

    end if;

end $$;


-- =====================================================
-- 5. PLATFORM NOTIFICATION WORKERS
-- =====================================================
--
-- Domain ownership:
-- 008 Operations owns notification_queue/history.
--
-- Platform ownership:
-- 000/020 owns worker execution functions.
-- =====================================================


create or replace function platform.fetch_notification_batch(
    p_limit int default 50
)
returns setof public.notification_queue
language plpgsql
security definer
set search_path = ''
as $$
begin

    return query

    with picked as (

        select nq.id

        from public.notification_queue nq

        where nq.status =
            'queued'::public.notification_delivery_status

          and nq.scheduled_at <= now()

        order by nq.scheduled_at

        for update skip locked

        limit greatest(p_limit, 1)

    )

    update public.notification_queue nq

    set
        status =
            'processing'::public.notification_delivery_status,

        attempt_count =
            nq.attempt_count + 1,

        updated_at =
            now()

    from picked

    where nq.id = picked.id

    returning nq.*;

end;
$$;


create or replace function platform.complete_notification_delivery(
    p_queue_id uuid,
    p_success boolean,
    p_error jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare

    v_row public.notification_queue;

    v_status public.notification_delivery_status;

begin

    select *
    into v_row

    from public.notification_queue nq

    where nq.id = p_queue_id

    for update;


    if not found then

        raise exception
            'notification queue item % not found',
            p_queue_id;

    end if;


    if p_success then

        v_status :=
            'sent'::public.notification_delivery_status;


        update public.notification_queue

        set
            status = v_status,
            last_error = null,
            updated_at = now()

        where id = p_queue_id;


        insert into public.notification_history (
            tenant_id,
            queue_id,
            channel,
            recipient,
            status,
            subject,
            body,
            payload,
            error
        )

        values (
            v_row.tenant_id,
            v_row.id,
            v_row.channel,
            v_row.recipient,
            v_status,
            v_row.subject,
            v_row.body,
            v_row.payload,
            null
        );


    else

        if v_row.attempt_count >= v_row.max_attempts then

            v_status :=
                'failed'::public.notification_delivery_status;


            update public.notification_queue

            set
                status = v_status,
                last_error =
                    coalesce(p_error, '{}'::jsonb),
                updated_at = now()

            where id = p_queue_id;


            insert into public.notification_history (
                tenant_id,
                queue_id,
                channel,
                recipient,
                status,
                subject,
                body,
                payload,
                error
            )

            values (
                v_row.tenant_id,
                v_row.id,
                v_row.channel,
                v_row.recipient,
                v_status,
                v_row.subject,
                v_row.body,
                v_row.payload,
                coalesce(p_error, '{}'::jsonb)
            );


        else

            update public.notification_queue

            set
                status =
                    'queued'::public.notification_delivery_status,

                last_error =
                    coalesce(p_error, '{}'::jsonb),

                scheduled_at =
                    now()
                    + (
                        interval '1 minute'
                        * greatest(v_row.attempt_count, 1)
                    ),

                updated_at =
                    now()

            where id = p_queue_id;

        end if;

    end if;

end;
$$;


-- =====================================================
-- 6. SCHEDULED JOB REGISTRATION
-- =====================================================

insert into platform.scheduled_jobs (
    job_name,
    cron_expression,
    handler,
    is_active,
    metadata
)

select *

from (
    values

    (
        'platform-cron-tick',
        '* * * * *',
        'platform.run_platform_cron_tick',
        true,
        '{"description":"Platform watchdog and retry queues"}'::jsonb
    ),

    (
        'platform-daily-maintenance',
        '15 2 * * *',
        'platform.run_platform_daily_maintenance',
        true,
        '{"description":"Partition maintenance, retention and platform housekeeping"}'::jsonb
    )

) as v(
    job_name,
    cron_expression,
    handler,
    is_active,
    metadata
)

where not exists (

    select 1

    from platform.scheduled_jobs sj

    where sj.job_name = v.job_name

);


-- =====================================================
-- 7. PG_CRON WIRING
-- =====================================================

select platform.ensure_pg_cron_jobs();


update platform.scheduled_jobs

set
    is_active =
        exists (
            select 1
            from pg_extension
            where extname = 'pg_cron'
        ),

    metadata =
        case

            when exists (
                select 1
                from pg_extension
                where extname = 'pg_cron'
            )

            then
                coalesce(metadata, '{}'::jsonb)
                - 'pg_cron_missing'

            else
                coalesce(metadata, '{}'::jsonb)
                || '{"pg_cron_missing":true}'::jsonb

        end

where job_name in (
    'platform-cron-tick',
    'platform-daily-maintenance'
);


-- =====================================================
-- 8. TELEMETRY FINALIZATION
-- =====================================================
--
-- 006 = Device Telemetry Engine.
--
-- 020 does NOT create telemetry.
-- 020 verifies the telemetry SSOT contract.
-- =====================================================

do $$
declare

    v_missing text[];

begin

    select array_agg(x.column_name order by x.column_name)
    into v_missing

    from (
        values
            ('tenant_id'),
            ('device_id'),
            ('source'),
            ('provider_event_id'),
            ('observed_at'),
            ('received_at'),
            ('raw_payload')
    ) as x(column_name)

    where not exists (

        select 1

        from information_schema.columns c

        where c.table_schema = 'public'

          and c.table_name =
              'device_telemetry_raw'

          and c.column_name =
              x.column_name

    );


    if v_missing is not null then

        raise exception
            '020 telemetry contract failed: public.device_telemetry_raw is missing columns: %',
            array_to_string(v_missing, ', ');

    end if;

end $$;


-- -----------------------------------------------------
-- Telemetry indexes
-- -----------------------------------------------------

create index if not exists
    idx_device_telemetry_raw_tenant_time

on public.device_telemetry_raw (
    tenant_id,
    observed_at desc
);


create index if not exists
    idx_device_telemetry_raw_device_time

on public.device_telemetry_raw (
    device_id,
    observed_at desc
);


create index if not exists
    idx_device_telemetry_raw_provider_event

on public.device_telemetry_raw (
    source,
    provider_event_id
);


-- =====================================================
-- 9. INTEGRATION FINALIZATION
-- =====================================================
--
-- 007 = Integration Engine.
--
-- 020 verifies the integration identity chain:
--
-- provider
--    ↓
-- tenant integration
--    ↓
-- device integration map
--    ↓
-- SmartHellas device
--
-- 020 does NOT interpret provider payloads.
-- =====================================================

do $$
begin

    if to_regclass('public.device_integration_map') is not null
       and to_regclass('public.devices') is not null
    then

        begin

            alter table public.device_integration_map

                add constraint
                    fk_device_integration_map_device

                foreign key (device_id)

                references public.devices(id)

                on delete cascade;

        exception
            when duplicate_object then null;

        end;

    end if;

end $$;


do $$
begin

    if to_regclass('public.device_integration_map') is not null
       and to_regclass('public.integration_providers') is not null
    then

        begin

            alter table public.device_integration_map

                add constraint
                    fk_device_integration_map_provider

                foreign key (provider_code)

                references public.integration_providers(code);

        exception
            when duplicate_object then null;

        end;

    end if;

end $$;


do $$
begin

    if to_regclass('public.tenant_integrations') is not null
       and to_regclass('public.integration_providers') is not null
    then

        begin

            alter table public.tenant_integrations

                add constraint
                    fk_tenant_integrations_provider

                foreign key (provider_code)

                references public.integration_providers(code);

        exception
            when duplicate_object then null;

        end;

    end if;

end $$;


-- =====================================================
-- 10. GENERIC TENANT RLS SAFETY NET
-- =====================================================
--
-- IMPORTANT:
--
-- Existing explicit policies are NEVER replaced.
--
-- Only public tables with:
--
--     tenant_id
--
-- and ZERO existing policies receive the generic policy set.
--
-- This keeps domain-specific authorization intact.
-- =====================================================

do $$
declare

    v_row record;

begin

    for v_row in

        select distinct
            c.table_name

        from information_schema.columns c

        join information_schema.tables t

          on t.table_schema = c.table_schema

         and t.table_name = c.table_name

        where c.table_schema = 'public'

          and c.column_name = 'tenant_id'

          and t.table_type = 'BASE TABLE'

          and not exists (

              select 1

              from pg_policies p

              where p.schemaname = 'public'

                and p.tablename = c.table_name

          )

        order by c.table_name

    loop

        perform public._apply_public_tenant_rls(
            format(
                'public.%I',
                v_row.table_name
            )::regclass
        );


        raise notice
            '020 bootstrap: generic tenant RLS applied to public.%',
            v_row.table_name;

    end loop;

end $$;


-- =====================================================
-- 11. FORCE RLS FINALIZATION
-- =====================================================
--
-- Any public tenant table must have RLS enabled and forced.
--
-- Explicit domain policies remain untouched.
-- =====================================================

do $$
declare

    v_row record;

begin

    for v_row in

        select distinct

            c.table_name

        from information_schema.columns c

        join information_schema.tables t

          on t.table_schema = c.table_schema

         and t.table_name = c.table_name

        where c.table_schema = 'public'

          and c.column_name = 'tenant_id'

          and t.table_type = 'BASE TABLE'

        order by c.table_name

    loop

        execute format(
            'alter table public.%I enable row level security',
            v_row.table_name
        );


        execute format(
            'alter table public.%I force row level security',
            v_row.table_name
        );

    end loop;

end $$;


-- =====================================================
-- 12. RLS VERIFICATION
-- =====================================================

do $$
declare

    v_row record;

begin

    for v_row in

        select distinct

            c.table_name

        from information_schema.columns c

        join information_schema.tables t

          on t.table_schema = c.table_schema

         and t.table_name = c.table_name

        join pg_class pc

          on pc.relname = c.table_name

        join pg_namespace pn

          on pn.oid = pc.relnamespace

         and pn.nspname = 'public'

        where c.table_schema = 'public'

          and c.column_name = 'tenant_id'

          and t.table_type = 'BASE TABLE'

          and (
                not pc.relrowsecurity

                or not exists (
                    select 1
                    from pg_policies p
                    where p.schemaname = 'public'
                      and p.tablename = c.table_name
                )
          )

        order by c.table_name

    loop

        raise exception
            '020 RLS verification failed: public.% has tenant_id but RLS is disabled or has no policies',
            v_row.table_name;

    end loop;

end $$;


-- =====================================================
-- 13. TELEMETRY RLS EXPLICIT ASSERTION
-- =====================================================
--
-- This is intentionally explicit because telemetry is
-- high-volume and tenant-scoped.
-- =====================================================

do $$
declare

    v_has_policy boolean;

begin

    select exists (

        select 1

        from pg_policies

        where schemaname = 'public'

          and tablename =
              'device_telemetry_raw'

    )

    into v_has_policy;


    if not v_has_policy then

        raise exception
            '020 telemetry RLS verification failed: device_telemetry_raw has no RLS policy';

    end if;

end $$;


-- =====================================================
-- 14. WEBHOOK PIPELINE VERIFICATION
-- =====================================================
--
-- 000:
--   platform.external_webhooks
--
-- 007:
--   provider resolution
--   provider identity
--   event mapping
--   routing
--
-- 006:
--   telemetry SSOT
--
-- 020 only verifies the required boundary.
-- =====================================================

do $$
begin

    if to_regprocedure(
        'platform.process_external_webhook(uuid)'
    ) is null then

        raise exception
            '020 webhook contract failed: platform.process_external_webhook(uuid) missing';

    end if;


    if to_regprocedure(
        'public.process_integration_webhook(uuid)'
    ) is null then

        raise exception
            '020 webhook contract failed: public.process_integration_webhook(uuid) missing';

    end if;

end $$;


-- =====================================================
-- 15. WEBHOOK IDEMPOTENCY VERIFICATION
-- =====================================================

do $$
begin

    if to_regclass('platform.external_webhooks') is not null then

        if not exists (

            select 1

            from pg_indexes

            where schemaname = 'platform'

              and tablename =
                  'external_webhooks'

              and indexdef ilike
                  '%unique%'

              and indexdef ilike
                  '%source%'

              and indexdef ilike
                  '%external_event_id%'

        ) then

            raise exception
                '020 webhook contract failed: external_webhooks lacks unique source/external_event_id idempotency index';

        end if;

    end if;

end $$;


-- =====================================================
-- 16. PLATFORM SECURITY BOUNDARY
-- =====================================================
--
-- 019 is the canonical grant matrix.
--
-- 020 MUST NOT issue blanket authenticated CRUD.
--
-- Therefore no:
--
--   GRANT SELECT, INSERT, UPDATE, DELETE
--   ON ALL TABLES IN SCHEMA public
--   TO authenticated;
--
-- is performed here.
--
-- Platform schema access is deliberately restricted.
-- =====================================================

grant usage on schema platform to service_role;


do $$
declare

    v_row record;

begin

    for v_row in

        select
            c.relname as table_name

        from pg_class c

        join pg_namespace n
          on n.oid = c.relnamespace

        where n.nspname = 'platform'

          and c.relkind = 'r'

          and c.relname <> 'platform_admins'

    loop

        execute format(
            'revoke all on table platform.%I from anon, authenticated',
            v_row.table_name
        );


        execute format(
            'grant all on table platform.%I to service_role',
            v_row.table_name
        );

    end loop;

end $$;


-- =====================================================
-- 17. PLATFORM FUNCTION EXECUTION BOUNDARY
-- =====================================================
--
-- Platform worker functions are service_role-only.
-- =====================================================

do $$
declare

    v_row record;

begin

    for v_row in

        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args

        from pg_proc p

        join pg_namespace n
          on n.oid = p.pronamespace

        where n.nspname = 'platform'

          and p.proname in (
              'fetch_notification_batch',
              'complete_notification_delivery'
          )

    loop

        execute format(
            'revoke all on function %I.%I(%s) from public, anon, authenticated',
            v_row.nspname,
            v_row.proname,
            v_row.args
        );


        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            v_row.nspname,
            v_row.proname,
            v_row.args
        );

    end loop;

end $$;


-- =====================================================
-- 18. NO GLOBAL AUTHENTICATED DEFAULT CRUD
-- =====================================================
--
-- 019 owns application grants.
--
-- Remove any legacy broad default privileges that may
-- have been introduced by an older bootstrap.
--
-- This does NOT define the new grant matrix.
-- =====================================================

alter default privileges
for role postgres
in schema public
revoke all on tables
from authenticated;


alter default privileges
for role postgres
in schema public
revoke all on sequences
from authenticated;


-- =====================================================
-- 19. PLATFORM DEFAULT PRIVILEGES
-- =====================================================
--
-- Platform objects are service_role-owned.
-- =====================================================

alter default privileges
for role postgres
in schema platform
grant all on tables
to service_role;


alter default privileges
for role postgres
in schema platform
grant all on sequences
to service_role;


alter default privileges
for role postgres
in schema platform
revoke all on tables
from anon, authenticated;


-- =====================================================
-- 20. FINAL CROSS-MODULE CONTRACT ASSERTIONS
-- =====================================================

do $$
begin

    -- 006 telemetry SSOT
    if to_regclass('public.device_telemetry_raw') is null then

        raise exception
            '020 final assertion failed: 006 telemetry SSOT missing';

    end if;


    -- 007 integration SSOT
    if to_regclass('public.integration_providers') is null then

        raise exception
            '020 final assertion failed: 007 integration SSOT missing';

    end if;


    -- 004 device SSOT
    if to_regclass('public.devices') is null then

        raise exception
            '020 final assertion failed: 004 device SSOT missing';

    end if;


    -- 000 webhook boundary
    if to_regclass('platform.external_webhooks') is null then

        raise exception
            '020 final assertion failed: platform webhook boundary missing';

    end if;

end $$;


-- =====================================================
-- 21. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)

values (
    '020_platform_bootstrap',
    'REV22.PLATFORM.BOOTSTRAP',
    false
)

on conflict (version)
do nothing;


-- =====================================================
-- END 020 PLATFORM BOOTSTRAP
-- =====================================================