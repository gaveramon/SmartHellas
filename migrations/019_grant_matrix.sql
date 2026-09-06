-- =====================================================
-- REV22 GREENFIELD BASELINE
-- 019_SECURITY_GRANT_BOUNDARY.sql
--
-- Enterprise Security Boundary Enforcement
--
-- Authority:
-- Enterprise Auditor
-- KGS-001 Principles
-- SECURITY RULES
-- SSOT RULES
--
-- Purpose:
-- Single source of truth for:
-- - EXECUTE privileges
-- - API exposure
-- - domain isolation
-- - platform isolation
-- - SECURITY DEFINER hardening
--
-- Application-owned schemas:
-- - public
-- - platform
--
-- Managed / extension-owned functions:
-- - EXCLUDED from application grant matrix
--
-- Security model:
--
-- PUBLIC        -> no EXECUTE
-- anon          -> no EXECUTE
-- authenticated -> explicit API/helper surface only
-- service_role  -> internal platform/domain execution
--
-- =====================================================


begin;


-- =====================================================
-- 001 DEFAULT FUNCTION PRIVILEGES
--
-- Prevent newly-created application functions from
-- automatically receiving PUBLIC EXECUTE.
--
-- This applies to functions subsequently created by
-- the postgres role.
-- =====================================================

alter default privileges
for role postgres
revoke execute on functions
from public;

alter default privileges
for role postgres
revoke execute on functions
from anon;

alter default privileges
for role postgres
revoke execute on functions
from authenticated;

REVOKE REFERENCES, TRIGGER, TRUNCATE
ON TABLE public.integration_oauth_configs
FROM anon, authenticated;

-- =====================================================
-- 002 GLOBAL FUNCTION SECURITY RESET
--
-- Remove uncontrolled execution from application-owned
-- functions.
--
-- PostgreSQL / Supabase extension-owned functions are
-- explicitly excluded.
--
-- Existing functions are handled here.
-- Default privileges above protect future functions.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where n.nspname in (
            'public',
            'platform'
        )

        -- Exclude extension-owned functions
        and not exists (
            select 1
            from pg_depend d
            join pg_extension e
                on e.oid = d.refobjid
            where d.classid = 'pg_proc'::regclass
              and d.objid = p.oid
              and d.deptype = 'e'
        )

    loop

        execute format(
            'revoke execute on function %I.%I(%s)
             from public, anon, authenticated',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end $$;


-- =====================================================
-- 003 SECURITY DEFINER HARDENING
--
-- Harden application SECURITY DEFINER functions against
-- search_path manipulation.
--
-- Managed extension functions are excluded.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where p.prosecdef = true

          and n.nspname in (
              'public',
              'platform'
          )

          -- Exclude extension-owned functions
          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

    loop

        execute format(
            'alter function %I.%I(%s)
             set search_path = ''''',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end $$;


-- =====================================================
-- 004 PLATFORM INTERNAL FUNCTIONS
--
-- Platform functions are internal by default.
--
-- Execution:
-- - service_role -> allowed
-- - authenticated -> denied unless explicitly approved
-- - anon -> denied
-- - public -> denied
--
-- Managed extension functions are excluded.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where n.nspname = 'platform'

          -- Exclude extension-owned functions
          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

    loop

        execute format(
            'grant execute on function %I.%I(%s)
             to service_role',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end $$;


-- =====================================================
-- 005 DOMAIN INTERNAL FUNCTIONS
--
-- Domain-internal functions are service_role-only.
--
-- These functions remain inaccessible to
-- authenticated users unless explicitly exposed through
-- an approved API contract.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where n.nspname = 'public'

          and (
              p.proname like '%\_domain'
              escape '\'
              or
              p.proname like '%\_domain_ext%'
              escape '\'
          )

          -- Exclude extension-owned functions
          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

    loop

        execute format(
            'revoke execute on function %I.%I(%s)
             from authenticated',
            r.schema_name,
            r.function_name,
            r.arguments
        );

        execute format(
            'revoke execute on function %I.%I(%s)
             from anon',
            r.schema_name,
            r.function_name,
            r.arguments
        );

        execute format(
            'grant execute on function %I.%I(%s)
             to service_role',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end $$;


-- =====================================================
-- GRANT LOCKDOWN
-- Authenticated role: *_api entrypoints + infrastructure guards only
-- =====================================================


-- Revoke authenticated execute on non-API exposure surface (idempotent)

-- do $block$
-- declare
--     r record;


-- begin
--     for r in
--         select
--             n.nspname,
--             p.proname,
--             pg_get_function_identity_arguments(p.oid) as args
--         from pg_proc p
--         join pg_namespace n on n.oid = p.pronamespace
--         where (n.nspname = 'platform' and p.proname = 'has_tenant_membership')
--            or (n.nspname = 'public' and p.proname = any (array[
--             'auth_resolve_tenant_switch',
--             'auth_switch_tenant',
--             'auth_invite_member',
--             'auth_domain',
--             'auth_domain_ext',
--             'auth_domain_ext_031',
--             'integrations_oauth_url_encode',
--             'integrations_start_oauth',
--             'integrations_domain',
--             'integrations_domain_ext',
--             'booking_compute_access_window',
--             'booking_calculate_access_window',
--             'booking_generate_booking_access',
--             'booking_regenerate_booking_access',
--             'booking_create_booking_access',
--             'booking_domain',
--             'locks_domain',
--             'get_onboarding_lifecycle',
--             'list_onboarding_lifecycle_transitions',
--             'onboarding_lifecycle_transition',
--             'create_property',
--             'assign_device',
--             'generate_lock_code',
--             'create_booking',
--             'onboarding_step_update',
--             'create_subscription',
--             'log_event',
--             'calculate_optimization_score',
--             'generate_monetization_proposal',
--             'insert_event',
--             'assign_device_to_room',
--             'change_subscription_plan',
--             'dispatch_fulfilment_order',
--             'edge_soft_delete_row',
--             'automation_domain',
--             'automation_domain_ext',
--             'automation_cancel_run',
--             'automation_start_run',
--             'automation_dispatch_event',
--             'automation_enqueue_notification',
--             'commerce_domain',
--             'logistics_domain',
--             'crm_domain',
--             'portal_domain',
--             'onboarding_domain',
--             'optimization_domain',
--             'monetization_domain',
--             'operations_domain',
--             'preconfig_domain',
--             'notification_domain',
--             'payment_domain',
--             'devices_domain',
--             'devices_assign_device_to_room',
--             'crm_soft_delete_row',
--             'commerce_change_subscription_plan',
--             'commerce_create_subscription',
--             'logistics_dispatch_fulfilment_order',
--             'payment_transition_status'
--         ]))
--     loop
--         execute format(
--             'revoke all on function %I.%I(%s) from public, authenticated',
--             r.nspname, r.proname, r.args
--         );

--     end loop;

-- end;
-- $block$;





do $$
declare
    v_row record;
begin
    for v_row in
        select c.relname as table_name
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'platform'
          and c.relkind = 'r'
          and c.relname <> 'platform_admins'
        order by c.relname
    loop
        execute format(
            'revoke all on table platform.%I from authenticated, anon',
            v_row.table_name
        );
        execute format(
            'grant all on table platform.%I to service_role',
            v_row.table_name
        );
    end loop;
end $$;



-- =====================================================
-- 006 APPROVED API SURFACE
--
-- These are the only public application API contracts
-- exposed directly to authenticated users.
-- =====================================================

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n
            ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = ANY (ARRAY[
            'auth_api',
            'booking_api',
            'locks_api',
            'commerce_api',
            'logistics_api',
            'crm_api',
            'portal_api',
            'onboarding_api',
            'optimization_api',
            'monetization_api',
            'operations_api',
            'preconfig_api',
            'integrations_api',
            'automation_api',
            'devices_api',
            'payment_api',
            'notification_api'
          ])
    LOOP

        -- 1. Remove all privileges inherited through PUBLIC
        EXECUTE format(
            'REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC',
            r.nspname,
            r.proname,
            r.args
        );

        -- 2. Explicitly allow authenticated to execute
        EXECUTE format(
            'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO authenticated',
            r.nspname,
            r.proname,
            r.args
        );

    END LOOP;
END;
$$;


-- =====================================================
-- 002: FUNCTION SECURITY LOCKDOWN
-- =====================================================

do $block$
declare
    r record;
begin

    for r in
        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n
            on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = any (array[
            'auth_domain_ext',
            'auth_domain_ext_031',
            'commerce_domain',
            'booking_domain',
            'locks_domain',
            'crm_domain',
            'preconfig_domain',
            'portal_domain',
            'onboarding_domain',
            'optimization_domain',
            'monetization_domain',
            'operations_domain',
            'automation_domain',
            'automation_domain_ext',
            'notification_domain',
            'payment_domain'
          ])
    loop

        execute format(
            'revoke all on function %I.%I(%s) from public, authenticated',
            r.nspname,
            r.proname,
            r.args
        );

    end loop;

end;
$block$;


-- -----------------------------------------------------
-- 002: H1, H2, H4, H5, M1: revoke direct authenticated execute
-- on standalone RPCs
-- Idempotent: only functions that exist at apply time
-- -----------------------------------------------------

do $block$
declare
    r record;


begin
    for r in
        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = any (array[
            'commerce_change_subscription_plan',
            'commerce_create_subscription',
            'automation_dispatch_event',
            'automation_start_run',
            'automation_cancel_run',
            'automation_enqueue_notification',
            'integrations_start_oauth',
            'insert_event'
          ])
    loop
        execute format(
            'revoke all on function %I.%I(%s) from public, authenticated',
            r.nspname, r.proname, r.args
        );


        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            r.nspname, r.proname, r.args
        );


    end loop;


end;


$block$;


-- =====================================================
-- 006: PRIVILEGE BOUNDARY
--
-- Prevent direct application writes.
--
-- SELECT is exposed through RLS.
-- INSERT/UPDATE/DELETE remain trusted server operations.
-- =====================================================

revoke insert, update, delete
on public.device_telemetry_raw
from anon, authenticated;


grant select
on public.device_telemetry_raw
to authenticated;

revoke all on function public.ingest_raw_device_telemetry(
    uuid,
    uuid,
    text,
    text,
    timestamptz,
    jsonb
)
from public, anon, authenticated;


grant execute on function public.ingest_raw_device_telemetry(
    uuid,
    uuid,
    text,
    text,
    timestamptz,
    jsonb
)
to service_role;


-- =====================================================
-- 007: GRANT and Revoke access to Integration
-- =====================================================



revoke all on function public.resolve_or_reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.resolve_or_reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
to service_role;

revoke all on function public.reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
from public, anon, authenticated;

revoke all on function public.resolve_provider_device_by_hardware_id(
    uuid,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.resolve_provider_device_by_hardware_id(
    uuid,
    text,
    text
)
to service_role;

grant execute on function public.reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
to service_role;




-- =====================================================
-- 014 GRANT and Revoke access to optimization
-- =====================================================

revoke insert, update, delete on table public.insight_events from authenticated, anon;

grant select on table public.insight_events to authenticated;

grant insert, update, delete on table public.insight_events to service_role;

revoke insert on table public.optimization_recommendations from authenticated, anon;

grant insert on table public.optimization_recommendations to service_role;


-- =====================================================
-- 007 RLS HELPER ACCESS
--
-- These helpers are explicitly approved for
-- authenticated execution because they are used as
-- tenant / permission boundary helpers.
-- =====================================================

grant execute on function platform.current_tenant_id()
to authenticated;

grant execute on function platform.has_role(text)
to authenticated;

grant execute on function platform.has_permission(text)
to authenticated;

revoke all on table platform.platform_admins from authenticated, anon;

grant all on table platform.platform_admins to service_role;

grant usage on schema platform to service_role;


-- =====================================================
-- 008 EXPLICITLY DENIED INTERNAL TENANT RESOLUTION
--
-- This function is not part of the authenticated API.
-- =====================================================

revoke execute on function
    public.resolve_active_tenant(uuid,uuid)
from authenticated;


-- =====================================================
-- 009 TENANT-SAFE VIEW ACCESS
--
-- Authenticated users may read only approved
-- tenant-safe projection views.
-- =====================================================

grant select on
    public.v_devices_overview,
    public.v_properties_overview,
    public.v_bookings_overview,
    public.v_onboarding_progress,
    public.v_subscription_overview,
    public.v_tenant_events_overview,
    public.v_tenant_audit_overview
to authenticated;


-- =====================================================
-- 010 VERIFY ANONYMOUS EXECUTION
--
-- No anonymous execution is allowed on any
-- SmartHellas-owned application function.
--
-- Extension-owned functions are excluded.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where n.nspname in (
            'public',
            'platform'
        )

          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

          and has_function_privilege(
              'anon',
              p.oid,
              'EXECUTE'
          )

        order by
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid)

    loop

        raise exception
            'Grant matrix violation: anon EXECUTE detected on %.%(%)',
            r.schema_name,
            r.function_name,
            r.arguments;

    end loop;

end $$;


-- =====================================================
-- 011 VERIFY AUTHENTICATED EXECUTION
--
-- Authenticated execution is allowed only for the
-- explicitly approved API/helper surface.
--
-- Internal functions must not be directly executable
-- by authenticated users.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where n.nspname in (
            'public',
            'platform'
        )

          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

          and has_function_privilege(
              'authenticated',
              p.oid,
              'EXECUTE'
          )

          -- Explicitly approved public API surface
          and not (
              n.nspname = 'public'
              and p.proname in (
                  'auth_api',
                  'booking_api',
                  'devices_api',
                  'crm_api',
                  'commerce_api',
                  'integrations_api',
                  'locks_api',
                  'logistics_api',
                  'notification_api',
                  'onboarding_api',
                  'operations_api',
                  'optimization_api',
                  'payment_api',
                  'portal_api',
                  'preconfig_api',
                  'automation_api',
                  'monetization_api'
              )
          )

          -- Explicitly approved RLS helpers
          and not (
              n.nspname = 'platform'
              and p.proname in (
                  'current_tenant_id',
                  'has_role',
                  'has_permission'
              )
          )

        order by
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid)

    loop

        raise exception
            'Grant matrix violation: unauthorized authenticated EXECUTE detected on %.%(%)',
            r.schema_name,
            r.function_name,
            r.arguments;

    end loop;

end $$;


-- =====================================================
-- 012 VERIFY SECURITY DEFINER INTERNAL FUNCTIONS
--
-- SECURITY DEFINER functions classified as internal
-- must not be directly executable by authenticated.
--
-- Explicitly approved RLS / permission helpers are
-- excluded because they are part of the authenticated
-- security boundary.
--
-- Extension-owned functions are excluded.
-- =====================================================

do $$
declare
    r record;
begin

    for r in

        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid) as arguments

        from pg_proc p

        join pg_namespace n
            on n.oid = p.pronamespace

        where p.prosecdef = true

          and n.nspname in (
              'public',
              'platform'
          )

          -- Exclude PostgreSQL/Supabase extension functions
          and not exists (
              select 1
              from pg_depend d
              join pg_extension e
                  on e.oid = d.refobjid
              where d.classid = 'pg_proc'::regclass
                and d.objid = p.oid
                and d.deptype = 'e'
          )

          -- Exclude explicitly approved authenticated
          -- security boundary helpers
          and not (
              n.nspname = 'platform'
              and p.proname in (
                  'current_tenant_id',
                  'has_role',
                  'has_permission'
              )
          )

          -- Internal functions
          and (
              n.nspname = 'platform'
              or
              p.proname like '%\_domain'
              escape '\'
              or
              p.proname like '%\_domain_ext%'
              escape '\'
              or
              p.proname like '%\_internal'
              escape '\'
          )

          and has_function_privilege(
              'authenticated',
              p.oid,
              'EXECUTE'
          )

    loop

        raise exception
            'Security boundary violation: authenticated EXECUTE on internal SECURITY DEFINER %.%(%)',
            r.schema_name,
            r.function_name,
            r.arguments;

    end loop;

end $$;


-- =====================================================
-- 013 SECURITY AUDIT EVENT
--
-- Record successful application of the grant boundary.
-- =====================================================

insert into platform.event_log
(
    event_type,
    source,
    payload
)

values
(
    'security.grant_boundary.applied',
    'rev22_migration',
    jsonb_build_object(
        'version',
        'REV22.SECURITY.GRANT.BOUNDARY'
    )
);


-- =====================================================
-- 014 MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations
(    
    migration_name,
    version,
    rollback_available
)

values
(
    '019_grant_matrix',
    'REV22.GRANT.MATRIX',
    false
)

on conflict (version) do nothing;


-- =====================================================
-- END 019 SECURITY GRANT BOUNDARY
-- =====================================================

commit;