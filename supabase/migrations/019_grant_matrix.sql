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
-- 006 APPROVED API SURFACE
--
-- These are the only public application API contracts
-- exposed directly to authenticated users.
-- =====================================================

grant execute on function public.auth_api(text,jsonb)
to authenticated;

grant execute on function public.booking_api(text,jsonb)
to authenticated;

grant execute on function public.devices_api(text,jsonb)
to authenticated;

grant execute on function public.crm_api(text,jsonb)
to authenticated;

grant execute on function public.commerce_api(text,jsonb)
to authenticated;

grant execute on function public.integrations_api(text,jsonb)
to authenticated;

grant execute on function public.locks_api(text,jsonb)
to authenticated;

grant execute on function public.logistics_api(text,jsonb)
to authenticated;

grant execute on function public.notification_api(text,jsonb)
to authenticated;

grant execute on function public.onboarding_api(text,jsonb)
to authenticated;

grant execute on function public.operations_api(text,jsonb)
to authenticated;

grant execute on function public.optimization_api(text,jsonb)
to authenticated;

grant execute on function public.payment_api(text,jsonb)
to authenticated;

grant execute on function public.portal_api(text,jsonb)
to authenticated;

grant execute on function public.preconfig_api(text,jsonb)
to authenticated;

grant execute on function public.automation_api(text,jsonb)
to authenticated;

grant execute on function public.monetization_api(text,jsonb)
to authenticated;


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