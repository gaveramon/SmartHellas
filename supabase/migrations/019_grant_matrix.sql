-- =====================================================
-- REV22 GREENFIELD BASELINE
-- 019_GRANT_MATRIX.SQL
--
-- Enterprise Security Grant Boundary
--
-- AUTHORITY
-- ----------
-- Enterprise Auditor
-- KGS-001 Principles
-- SECURITY RULES
-- SSOT RULES
--
-- PURPOSE
-- -------
-- Single source of truth for:
--
--   - schema privileges
--   - table privileges
--   - sequence privileges
--   - function EXECUTE privileges
--   - approved API/RPC exposure
--   - service_role backend access
--   - final privilege validation
--
--
-- SECURITY MODEL
-- --------------
--
-- PORTAL
--    |
--    v
-- API / RPC
--    |
--    v
-- AUTHORIZATION
--    |
--    v
-- DOMAIN / BACKEND
--    |
--    v
-- TABLES
--
--
-- IMPORTANT
-- ---------
--
-- 018 owns:
--   - RLS
--   - FORCE RLS
--   - SECURITY DEFINER hardening
--   - search_path hardening
--   - policy removal
--
-- 019 owns:
--   - GRANT
--   - REVOKE
--   - EXECUTE privileges
--   - schema privileges
--   - table privileges
--   - sequence privileges
--   - final privilege validation
--
-- The platform.security_table_registry is the authority
-- for registered table security classification.
--
-- 019 deliberately contains NO RLS policy creation.
-- =====================================================


begin;


-- =====================================================
-- 1. GLOBAL SCHEMA SECURITY RESET
--
-- No implicit PUBLIC schema access.
-- Explicit application roles receive only the access
-- required by the approved API/RPC boundary.
-- =====================================================

revoke all
on schema public
from public;

revoke all
on schema platform
from public;


-- =====================================================
-- 2. EXPLICIT SCHEMA USAGE
--
-- authenticated needs public schema USAGE to invoke
-- approved public API/RPC functions.
--
-- service_role needs access to both application and
-- platform schemas.
-- =====================================================

grant usage
on schema public
to authenticated;

grant usage
on schema public
to service_role;

grant usage
on schema platform
to service_role;


-- =====================================================
-- 3. GLOBAL FUNCTION EXECUTE RESET
--
-- Remove implicit PUBLIC execution from every function
-- in public and platform.
--
-- 018 has already hardened SECURITY DEFINER functions.
-- This section only controls privileges.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where n.nspname in ('public', 'platform')
          and p.prokind = 'f'
    loop

        execute format(
            'revoke all on function %I.%I(%s) from public',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end;
$$;


-- =====================================================
-- 4. REGISTERED TABLE PRIVILEGE RESET
--
-- Every active table in security_table_registry receives
-- an explicit deny baseline for anon/authenticated.
--
-- service_role receives full table access because it is
-- the trusted backend execution role.
--
-- The registry is the ONLY table list used here.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            table_schema,
            table_name
        from platform.security_table_registry
        where is_active = true
    loop

        -- Portal roles receive no direct table access.
        execute format(
            'revoke all on table %I.%I from anon, authenticated',
            r.table_schema,
            r.table_name
        );

        -- Trusted backend access.
        execute format(
            'grant all on table %I.%I to service_role',
            r.table_schema,
            r.table_name
        );

    end loop;

end;
$$;


-- =====================================================
-- 5. REGISTERED TABLE SEQUENCE PRIVILEGES
--
-- Identity/serial-backed tables may require sequence
-- privileges for trusted backend inserts.
--
-- Only sequences owned by a registered table are granted.
-- No blanket sequence grant is used.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select distinct
            n.nspname as sequence_schema,
            s.relname as sequence_name
        from pg_class s
        join pg_namespace n
          on n.oid = s.relnamespace
        join pg_depend d
          on d.refobjid = s.oid
        join pg_class t
          on t.oid = d.objid
        join pg_namespace tn
          on tn.oid = t.relnamespace
        join platform.security_table_registry sr
          on sr.table_schema = tn.nspname
         and sr.table_name = t.relname
        where s.relkind = 'S'
          and d.classid = 'pg_class'::regclass
          and d.refclassid = 'pg_class'::regclass
          and sr.is_active = true
    loop

        execute format(
            'revoke all on sequence %I.%I from public, anon, authenticated',
            r.sequence_schema,
            r.sequence_name
        );

        execute format(
            'grant all on sequence %I.%I to service_role',
            r.sequence_schema,
            r.sequence_name
        );

    end loop;

end;
$$;


-- =====================================================
-- 6. APPROVED API / RPC SURFACE
--
-- These are the ONLY public application functions that
-- authenticated portal users receive EXECUTE on.
--
-- Table access is never granted as a replacement for
-- missing API/RPC contracts.
-- =====================================================


grant execute on function public.auth_api(text, jsonb)
to authenticated;

grant execute on function public.booking_api(text, jsonb)
to authenticated;

grant execute on function public.devices_api(text, jsonb)
to authenticated;

grant execute on function public.crm_api(text, jsonb)
to authenticated;

grant execute on function public.commerce_api(text, jsonb)
to authenticated;

grant execute on function public.integrations_api(text, jsonb)
to authenticated;

grant execute on function public.locks_api(text, jsonb)
to authenticated;

grant execute on function public.logistics_api(text, jsonb)
to authenticated;

grant execute on function public.notification_api(text, jsonb)
to authenticated;

grant execute on function public.onboarding_api(text, jsonb)
to authenticated;

grant execute on function public.operations_api(text, jsonb)
to authenticated;

grant execute on function public.optimization_api(text, jsonb)
to authenticated;

grant execute on function public.payment_api(text, jsonb)
to authenticated;

grant execute on function public.portal_api(text, jsonb)
to authenticated;

grant execute on function public.preconfig_api(text, jsonb)
to authenticated;

grant execute on function public.automation_api(text, jsonb)
to authenticated;

grant execute on function public.monetization_api(text, jsonb)
to authenticated;


-- =====================================================
-- 7. RLS / TENANT HELPER EXECUTION
--
-- These are intentionally limited helper functions.
-- They are not business API contracts.
--
-- Their implementation and SECURITY DEFINER hardening
-- are owned by 018.
-- =====================================================

grant execute on function platform.current_tenant_id()
to authenticated;

grant execute on function platform.has_role(text)
to authenticated;

grant execute on function platform.has_permission(text)
to authenticated;


-- =====================================================
-- 8. TENANT AUTHORITY FUNCTION
--
-- Tenant authority must not be exposed as a general
-- authenticated RPC.
--
-- It is used internally by trusted functions/RLS.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = 'resolve_active_tenant'
    loop

        execute format(
            'revoke execute on function %I.%I(%s) from anon, authenticated',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end;
$$;


-- =====================================================
-- 9. PLATFORM FUNCTIONS
--
-- Platform functions are trusted backend infrastructure.
--
-- They are not a portal API surface.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where n.nspname = 'platform'
          and p.prokind = 'f'
    loop

        execute format(
            'revoke execute on function %I.%I(%s) from anon, authenticated',
            r.schema_name,
            r.function_name,
            r.arguments
        );

        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end;
$$;


-- =====================================================
-- 10. DOMAIN INTERNAL FUNCTIONS
--
-- Internal domain functions are not part of the portal
-- API surface.
--
-- They are executable only by trusted backend code.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where n.nspname = 'public'
          and (
              p.proname like '%\_domain' escape '\'
              or p.proname like '%\_domain_ext%' escape '\'
          )
    loop

        execute format(
            'revoke execute on function %I.%I(%s) from anon, authenticated',
            r.schema_name,
            r.function_name,
            r.arguments
        );

        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end;
$$;


-- =====================================================
-- 11. SECURITY REGISTRY ITSELF
--
-- The registry is platform security metadata.
--
-- It is not a portal-readable table.
-- service_role may read/manage it.
--
-- No authenticated privilege is granted.
-- =====================================================

revoke all
on table platform.security_table_registry
from public, anon, authenticated;

grant select, insert, update, delete
on table platform.security_table_registry
to service_role;


-- =====================================================
-- 12. FINAL REGISTERED-TABLE PRIVILEGE VALIDATION
--
-- Every active registry table must:
--
--   - deny SELECT to authenticated
--   - deny INSERT to authenticated
--   - deny UPDATE to authenticated
--   - deny DELETE to authenticated
--   - grant service_role full table access
-- =====================================================

do $$
declare
    r record;
    v_acl text;
begin

    for r in
        select
            table_schema,
            table_name
        from platform.security_table_registry
        where is_active = true
    loop

        -- authenticated must have no direct privileges.
        if has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'SELECT'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'INSERT'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'UPDATE'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'DELETE'
        ) then

            raise exception
                '019 grant boundary failed: authenticated has direct privilege on %.%',
                r.table_schema,
                r.table_name;

        end if;


        -- anon must have no direct privileges.
        if has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'SELECT'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'INSERT'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'UPDATE'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'DELETE'
        ) then

            raise exception
                '019 grant boundary failed: anon has direct privilege on %.%',
                r.table_schema,
                r.table_name;

        end if;


        -- service_role must have full table access.
        if not has_table_privilege(
            'service_role',
            format('%I.%I', r.table_schema, r.table_name),
            'SELECT'
        )
        or not has_table_privilege(
            'service_role',
            format('%I.%I', r.table_schema, r.table_name),
            'INSERT'
        )
        or not has_table_privilege(
            'service_role',
            format('%I.%I', r.table_schema, r.table_name),
            'UPDATE'
        )
        or not has_table_privilege(
            'service_role',
            format('%I.%I', r.table_schema, r.table_name),
            'DELETE'
        ) then

            raise exception
                '019 grant boundary failed: service_role does not have full table access on %.%',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 13. APPROVED API EXECUTE VALIDATION
--
-- Every approved API function must exist and must be
-- executable by authenticated.
--
-- Missing API contracts cause migration failure.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select *
        from (
            values
                ('public', 'auth_api', 'text,jsonb'),
                ('public', 'booking_api', 'text,jsonb'),
                ('public', 'devices_api', 'text,jsonb'),
                ('public', 'crm_api', 'text,jsonb'),
                ('public', 'commerce_api', 'text,jsonb'),
                ('public', 'integrations_api', 'text,jsonb'),
                ('public', 'locks_api', 'text,jsonb'),
                ('public', 'logistics_api', 'text,jsonb'),
                ('public', 'notification_api', 'text,jsonb'),
                ('public', 'onboarding_api', 'text,jsonb'),
                ('public', 'operations_api', 'text,jsonb'),
                ('public', 'optimization_api', 'text,jsonb'),
                ('public', 'payment_api', 'text,jsonb'),
                ('public', 'portal_api', 'text,jsonb'),
                ('public', 'preconfig_api', 'text,jsonb'),
                ('public', 'automation_api', 'text,jsonb'),
                ('public', 'monetization_api', 'text,jsonb')
        ) as api(
            schema_name,
            function_name,
            arguments
        )
    loop

        if to_regprocedure(
            format(
                '%I.%I(%s)',
                r.schema_name,
                r.function_name,
                r.arguments
            )
        ) is null then

            raise exception
                '019 grant boundary failed: approved API function %.%(%s) does not exist',
                r.schema_name,
                r.function_name,
                r.arguments;

        end if;


        if not has_function_privilege(
            'authenticated',
            to_regprocedure(
                format(
                    '%I.%I(%s)',
                    r.schema_name,
                    r.function_name,
                    r.arguments
                )
            ),
            'EXECUTE'
        ) then

            raise exception
                '019 grant boundary failed: authenticated lacks EXECUTE on %.%(%s)',
                r.schema_name,
                r.function_name,
                r.arguments;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 14. NO UNAPPROVED AUTHENTICATED FUNCTION SURFACE
--
-- Every public function executable by authenticated must
-- belong to the explicitly approved API surface or to the
-- explicitly approved tenant/permission helper surface.
--
-- This prevents accidental exposure when a new function
-- is created with PUBLIC/default EXECUTE and later granted
-- through another migration.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where n.nspname in ('public', 'platform')
          and has_function_privilege(
              'authenticated',
              p.oid,
              'EXECUTE'
          )
          and not (
              (
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
              or
              (
                  n.nspname = 'platform'
                  and p.proname in (
                      'current_tenant_id',
                      'has_role',
                      'has_permission'
                  )
              )
          )
    loop

        raise exception
            '019 grant boundary failed: unapproved authenticated EXECUTE privilege on %.%(%s)',
            r.schema_name,
            r.function_name,
            r.arguments;

    end loop;

end;
$$;


-- =====================================================
-- 15. NO DIRECT AUTHENTICATED TABLE PRIVILEGES
--
-- Defense-in-depth validation.
--
-- This scans all tables in public and platform, not just
-- registered tables.
--
-- A newly introduced table therefore cannot silently become
-- a direct authenticated portal surface.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as table_schema,
            c.relname as table_name
        from pg_class c
        join pg_namespace n
          on n.oid = c.relnamespace
        where n.nspname in ('public', 'platform')
          and c.relkind in ('r', 'p')
    loop

        if has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'SELECT'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'INSERT'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'UPDATE'
        )
        or has_table_privilege(
            'authenticated',
            format('%I.%I', r.table_schema, r.table_name),
            'DELETE'
        ) then

            raise exception
                '019 grant boundary failed: authenticated has direct table privilege on %.%',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 16. NO DIRECT ANON TABLE PRIVILEGES
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            n.nspname as table_schema,
            c.relname as table_name
        from pg_class c
        join pg_namespace n
          on n.oid = c.relnamespace
        where n.nspname in ('public', 'platform')
          and c.relkind in ('r', 'p')
    loop

        if has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'SELECT'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'INSERT'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'UPDATE'
        )
        or has_table_privilege(
            'anon',
            format('%I.%I', r.table_schema, r.table_name),
            'DELETE'
        ) then

            raise exception
                '019 grant boundary failed: anon has direct table privilege on %.%',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 17. SERVICE_ROLE SCHEMA VALIDATION
-- =====================================================

do $$
begin

    if not has_schema_privilege(
        'service_role',
        'public',
        'USAGE'
    ) then

        raise exception
            '019 grant boundary failed: service_role lacks USAGE on public schema';

    end if;


    if not has_schema_privilege(
        'service_role',
        'platform',
        'USAGE'
    ) then

        raise exception
            '019 grant boundary failed: service_role lacks USAGE on platform schema';

    end if;

end;
$$;


-- =====================================================
-- 18. SECURITY REGISTRY VALIDATION
--
-- Every active registry entry must have a valid security
-- classification consistent with the 000 registry contract.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            table_schema,
            table_name,
            security_class,
            portal_access,
            direct_authenticated_access
        from platform.security_table_registry
        where is_active = true
    loop

        if r.security_class not in (
            'business',
            'backend_only'
        ) then

            raise exception
                '019 grant boundary failed: invalid security_class for %.%',
                r.table_schema,
                r.table_name;

        end if;


        if r.security_class = 'business'
           and r.portal_access <> 'rpc' then

            raise exception
                '019 grant boundary failed: business table %.% does not use RPC portal access',
                r.table_schema,
                r.table_name;

        end if;


        if r.security_class = 'backend_only'
           and r.portal_access <> 'none' then

            raise exception
                '019 grant boundary failed: backend-only table %.% has portal access',
                r.table_schema,
                r.table_name;

        end if;


        if r.direct_authenticated_access is distinct from false then

            raise exception
                '019 grant boundary failed: direct authenticated access enabled for %.%',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 19. SECURITY AUDIT EVENT
-- =====================================================

insert into platform.event_log (
    event_type,
    source,
    payload
)
values (
    'security.grant_boundary.applied',
    'rev22_migration',
    jsonb_build_object(
        'version',
        'REV22.GRANT.MATRIX',
        'model',
        'registry_driven',
        'portal_access',
        'api_rpc_only',
        'direct_authenticated_table_access',
        false,
        'service_role_backend_access',
        true
    )
);


-- =====================================================
-- 20. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)
values (
    '019_grant_matrix',
    'REV22.GRANT.MATRIX',
    false
)
on conflict (version) do nothing;


-- =====================================================
-- END 019 GRANT MATRIX
-- =====================================================

commit;