-- =====================================================
-- REV22 greenfield baseline: 018_security_hardening.sql
-- =====================================================
-- SECURITY HARDENING
--
-- SECURITY MODEL
-- =====================================================
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
-- 018 OWNS
-- ---------
-- - security table registry population
-- - RLS
-- - FORCE RLS
-- - removal of legacy direct-table policies
-- - SECURITY DEFINER hardening
-- - search_path hardening
-- - dependency validation
-- - dynamic SQL validation
-- - tenant-authority validation
-- - security validation
--
--
-- 019 OWNS
-- --------
-- - GRANT
-- - REVOKE
-- - EXECUTE privileges
-- - schema privileges
-- - table privileges
-- - sequence privileges
-- - final privilege validation
-- - Grant Matrix
--
--
-- IMPORTANT
-- ---------
-- 018 deliberately contains NO GRANT / REVOKE statements.
--
-- The security_table_registry is the single maintenance
-- point for the table security boundary.
-- =====================================================


begin;


-- =====================================================
-- 1. SECURITY AUTHORITY FREEZE
-- =====================================================

comment on schema public is
'Business schema. Tenant authority MUST resolve through public.resolve_active_tenant(auth.uid()). Portal access to registered business tables is API/RPC-only.';

comment on schema platform is
'Platform infrastructure and security control plane. No business-domain ownership.';


-- =====================================================
-- 2. RLS COMPATIBILITY SHIMS
-- =====================================================

comment on function platform.has_tenant_access(uuid) is
'RLS compatibility shim only. Tenant authority resolves through public.resolve_active_tenant(auth.uid()). Not an API authorization surface.';

comment on function public.has_tenant_access(uuid) is
'RLS compatibility shim only. Tenant authority resolves through public.resolve_active_tenant(auth.uid()). Not an API authorization surface.';


alter function platform.has_tenant_access(uuid)
set search_path = '';


alter function public.has_tenant_access(uuid)
set search_path = '';


create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select tid = public.resolve_active_tenant((select auth.uid()));
$$;


create or replace function public.has_tenant_access(p_public_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_public_tenant_id =
           public.resolve_active_tenant((select auth.uid()));
$$;


-- =====================================================
-- 3. REGISTER TABLE SECURITY CLASSIFICATIONS
-- =====================================================
--
-- THIS IS THE ONLY MANUAL TABLE LIST IN 018.
--
-- When a new governed table is introduced:
--
--   1. create the table in its domain migration
--   2. add ONE registry row here
--
-- The enforcement and validation loops below do not need
-- to be changed.
-- =====================================================

insert into platform.security_table_registry (
    table_schema,
    table_name,
    security_class,
    portal_access,
    direct_authenticated_access,
    rls_required,
    force_rls_required,
    is_active,
    description
)
values

    -- -------------------------------------------------
    -- 002 CORE SAAS
    -- -------------------------------------------------

    (
        'public',
        'tenants',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Tenant master data. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'tenant_memberships',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Tenant membership and role data. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'subscriptions',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Subscription data. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'service_accounts',
        'backend_only',
        'none',
        false,
        true,
        true,
        true,
        'Internal service-account data. Backend/service-role only.'
    ),

    -- -------------------------------------------------
    -- 007 INTEGRATION ENGINE
    -- -------------------------------------------------

    (
        'public',
        'integration_providers',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Integration provider catalog. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'integration_capabilities',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Provider capability catalog. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'integration_oauth_configs',
        'backend_only',
        'none',
        false,
        true,
        true,
        true,
        'OAuth configuration metadata. Backend-controlled; never a direct portal table surface.'
    ),

    (
        'public',
        'integration_oauth_states',
        'backend_only',
        'none',
        false,
        true,
        true,
        true,
        'Transient OAuth transaction state. Backend/service-role and security-definer lifecycle only.'
    ),

    (
        'public',
        'tenant_integrations',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Tenant integration configuration. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'webhook_definitions',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Tenant webhook configuration. Portal access only through approved API/RPC contracts.'
    ),

    (
        'public',
        'device_integration_map',
        'business',
        'rpc',
        false,
        true,
        true,
        true,
        'Provider-to-device identity mapping. Portal access only through approved API/RPC contracts.'
    ),

    -- -------------------------------------------------
    -- 006 DEVICE TELEMETRY
    -- -------------------------------------------------

    (
        'public',
        'device_telemetry_raw',
        'backend_only',
        'none',
        false,
        true,
        true,
        true,
        'Immutable raw device telemetry. Backend/service-role ingestion and processing only.'
    )

on conflict (table_schema, table_name)
do update set
    security_class = excluded.security_class,
    portal_access = excluded.portal_access,
    direct_authenticated_access =
        excluded.direct_authenticated_access,
    rls_required = excluded.rls_required,
    force_rls_required = excluded.force_rls_required,
    is_active = excluded.is_active,
    description = excluded.description,
    updated_at = now();


-- =====================================================
-- 4. REGISTRY INTEGRITY VALIDATION
-- =====================================================
--
-- Every active registry entry MUST resolve to a real table.
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

        if to_regclass(
            format('%I.%I', r.table_schema, r.table_name)
        ) is null then

            raise exception
                '018 security hardening failed: registered table %.% does not exist',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 5. REGISTRY SEMANTIC VALIDATION
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
            direct_authenticated_access,
            rls_required,
            force_rls_required
        from platform.security_table_registry
        where is_active = true
    loop

        if r.direct_authenticated_access is distinct from false then

            raise exception
                '018 security hardening failed: %.% permits direct authenticated access',
                r.table_schema,
                r.table_name;

        end if;


        if r.security_class = 'backend_only'
           and r.portal_access <> 'none' then

            raise exception
                '018 security hardening failed: backend-only table %.% cannot have portal_access=%',
                r.table_schema,
                r.table_name,
                r.portal_access;

        end if;


        if r.security_class = 'business'
           and r.portal_access <> 'rpc' then

            raise exception
                '018 security hardening failed: business table %.% must use portal_access=rpc',
                r.table_schema,
                r.table_name;

        end if;


        if r.rls_required is distinct from true then

            raise exception
                '018 security hardening failed: registered table %.% must require RLS',
                r.table_schema,
                r.table_name;

        end if;


        if r.force_rls_required is distinct from true then

            raise exception
                '018 security hardening failed: registered table %.% must require FORCE RLS',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 6. ENABLE RLS + FORCE RLS
-- =====================================================
--
-- No table names are hardcoded here.
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
          and rls_required = true
    loop

        execute format(
            'alter table %I.%I enable row level security',
            r.table_schema,
            r.table_name
        );

        if r.force_rls_required = true then

            execute format(
                'alter table %I.%I force row level security',
                r.table_schema,
                r.table_name
            );

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 7. REMOVE ALL LEGACY RLS POLICIES
-- =====================================================
--
-- This deliberately removes ALL existing policies from
-- registered tables.
--
-- Portal access is NOT implemented through direct-table
-- policies. Approved portal reads/writes are implemented
-- through API/RPC contracts.
--
-- RLS remains defense-in-depth.
-- =====================================================

do $$
declare
    r record;
    p record;
begin

    for r in
        select
            table_schema,
            table_name
        from platform.security_table_registry
        where is_active = true
    loop

        for p in
            select
                policyname
            from pg_policies
            where schemaname = r.table_schema
              and tablename = r.table_name
        loop

            execute format(
                'drop policy if exists %I on %I.%I',
                p.policyname,
                r.table_schema,
                r.table_name
            );

        end loop;

    end loop;

end;
$$;


-- =====================================================
-- 8. POST-POLICY SECURITY VALIDATION
-- =====================================================
--
-- Registered tables must not expose any anon or
-- authenticated RLS policy.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            p.schemaname,
            p.tablename,
            p.policyname,
            p.roles
        from pg_policies p
        join platform.security_table_registry s
          on s.table_schema = p.schemaname
         and s.table_name = p.tablename
        where s.is_active = true
          and (
              'anon' = any (p.roles)
              or 'authenticated' = any (p.roles)
          )
    loop

        raise exception
            '018 security hardening failed: direct anon/authenticated policy remains on %.%: %',
            r.schemaname,
            r.tablename,
            r.policyname;

    end loop;

end;
$$;


-- =====================================================
-- 9. RLS / FORCE RLS VALIDATION
-- =====================================================

do $$
declare
    r record;
    v_relrowsecurity boolean;
    v_relforcerowsecurity boolean;
begin

    for r in
        select
            s.table_schema,
            s.table_name,
            s.rls_required,
            s.force_rls_required
        from platform.security_table_registry s
        where s.is_active = true
    loop

        select
            c.relrowsecurity,
            c.relforcerowsecurity
        into
            v_relrowsecurity,
            v_relforcerowsecurity
        from pg_class c
        join pg_namespace n
          on n.oid = c.relnamespace
        where n.nspname = r.table_schema
          and c.relname = r.table_name
          and c.relkind in ('r', 'p');


        if not found then

            raise exception
                '018 security hardening failed: table %.% not found in pg_class',
                r.table_schema,
                r.table_name;

        end if;


        if r.rls_required
           and v_relrowsecurity is distinct from true then

            raise exception
                '018 security hardening failed: RLS not enabled on %.%',
                r.table_schema,
                r.table_name;

        end if;


        if r.force_rls_required
           and v_relforcerowsecurity is distinct from true then

            raise exception
                '018 security hardening failed: FORCE RLS not enabled on %.%',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 10. SECURITY DEFINER HARDENING
-- =====================================================
--
-- Automatically discovers all SECURITY DEFINER functions
-- in public and platform.
--
-- No manual function list is required.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            p.oid,
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where p.prokind = 'f'
          and p.prosecdef = true
          and n.nspname in ('public', 'platform')
        order by
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid)
    loop

        execute format(
            'alter function %I.%I(%s) set search_path = ''''',
            r.schema_name,
            r.function_name,
            r.arguments
        );

    end loop;

end;
$$;


-- =====================================================
-- 11. SECURITY DEFINER RELATION DEPENDENCY VALIDATION
-- =====================================================
--
-- SECURITY DEFINER functions may only resolve static
-- relation dependencies inside explicitly approved schemas.
--
-- Approved:
--   pg_catalog
--   information_schema
--   public
--   platform
-- =====================================================

do $$
declare
    r record;
    d record;

    v_allowed_schemas text[] := array[
        'pg_catalog',
        'information_schema',
        'public',
        'platform'
    ];

begin

    for r in
        select
            p.oid,
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where p.prokind = 'f'
          and p.prosecdef = true
          and n.nspname in ('public', 'platform')
    loop

        for d in
            select distinct
                dep_ns.nspname as dependency_schema,
                dep_cls.relname as dependency_name,
                dep_cls.relkind as dependency_kind
            from pg_depend dep
            join pg_class dep_cls
              on dep_cls.oid = dep.refobjid
            join pg_namespace dep_ns
              on dep_ns.oid = dep_cls.relnamespace
            where dep.classid = 'pg_proc'::regclass
              and dep.objid = r.oid
              and dep.refclassid = 'pg_class'::regclass
              and dep.deptype <> 'p'
        loop

            if not (
                d.dependency_schema = any(v_allowed_schemas)
            ) then

                raise exception
                    '018 security hardening failed: SECURITY DEFINER %.%(%s) depends on non-approved relation %.%',
                    r.schema_name,
                    r.function_name,
                    r.arguments,
                    d.dependency_schema,
                    d.dependency_name;

            end if;

        end loop;


        for d in
            select distinct
                dep_ns.nspname as dependency_schema,
                dep_proc.proname as dependency_name,
                pg_get_function_identity_arguments(
                    dep_proc.oid
                ) as dependency_arguments
            from pg_depend dep
            join pg_proc dep_proc
              on dep_proc.oid = dep.refobjid
            join pg_namespace dep_ns
              on dep_ns.oid = dep_proc.pronamespace
            where dep.classid = 'pg_proc'::regclass
              and dep.objid = r.oid
              and dep.refclassid = 'pg_proc'::regclass
              and dep.deptype <> 'p'
        loop

            if not (
                d.dependency_schema = any(v_allowed_schemas)
            ) then

                raise exception
                    '018 security hardening failed: SECURITY DEFINER %.%(%s) depends on non-approved function %.%(%)',
                    r.schema_name,
                    r.function_name,
                    r.arguments,
                    d.dependency_schema,
                    d.dependency_name,
                    d.dependency_arguments;

            end if;

        end loop;

    end loop;

end;
$$;


-- =====================================================
-- 12. DYNAMIC SQL VALIDATION
-- =====================================================
--
-- Static pg_depend validation cannot prove the security
-- of dynamically constructed identifiers.
--
-- Therefore SECURITY DEFINER functions containing
-- EXECUTE require explicit security review.
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            p.oid,
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments,
            pg_get_functiondef(p.oid) as definition
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where p.prokind = 'f'
          and p.prosecdef = true
          and n.nspname in ('public', 'platform')
    loop

        if r.definition ~* '\mEXECUTE\M' then

            raise exception
                '018 security hardening failed: SECURITY DEFINER %.%(%s) contains dynamic SQL and requires explicit security review',
                r.schema_name,
                r.function_name,
                r.arguments;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 13. FINAL SECURITY DEFINER SEARCH_PATH VALIDATION
-- =====================================================

do $$
declare
    r record;
begin

    for r in
        select
            p.oid,
            n.nspname as schema_name,
            p.proname as function_name,
            pg_get_function_identity_arguments(p.oid)
                as arguments,
            p.proconfig
        from pg_proc p
        join pg_namespace n
          on n.oid = p.pronamespace
        where p.prokind = 'f'
          and p.prosecdef = true
          and n.nspname in ('public', 'platform')
    loop

        if not exists (
            select 1
            from unnest(
                coalesce(
                    r.proconfig,
                    array[]::text[]
                )
            ) cfg
            where cfg = 'search_path='
        ) then

            raise exception
                '018 security hardening failed: SECURITY DEFINER %.%(%s) does not have search_path = ''''',
                r.schema_name,
                r.function_name,
                r.arguments;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 14. TENANT AUTHORITY VALIDATION
-- =====================================================

do $$
declare
    v_function_count integer;
begin

    select count(*)
    into v_function_count
    from pg_proc p
    join pg_namespace n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'resolve_active_tenant'
      and pg_get_function_identity_arguments(p.oid)
            = 'uuid';

    if v_function_count = 0 then

        raise exception
            '018 security hardening failed: public.resolve_active_tenant(uuid) not found';

    end if;

end;
$$;


-- =====================================================
-- 15. REGISTRY / SECURITY CONSISTENCY VALIDATION
-- =====================================================
--
-- Every active registered table must:
--   - exist
--   - have RLS
--   - have FORCE RLS
--   - have no anon/authenticated policy
--   - deny direct authenticated access by contract
-- =====================================================

do $$
declare
    r record;
    v_policy_count integer;
    v_rls boolean;
    v_force_rls boolean;
begin

    for r in
        select
            s.table_schema,
            s.table_name,
            s.direct_authenticated_access
        from platform.security_table_registry s
        where s.is_active = true
    loop

        select
            c.relrowsecurity,
            c.relforcerowsecurity
        into
            v_rls,
            v_force_rls
        from pg_class c
        join pg_namespace n
          on n.oid = c.relnamespace
        where n.nspname = r.table_schema
          and c.relname = r.table_name;


        if not found then

            raise exception
                '018 security hardening failed: registry table %.% disappeared',
                r.table_schema,
                r.table_name;

        end if;


        if v_rls is distinct from true then

            raise exception
                '018 security hardening failed: registry table %.% has RLS disabled',
                r.table_schema,
                r.table_name;

        end if;


        if v_force_rls is distinct from true then

            raise exception
                '018 security hardening failed: registry table %.% has FORCE RLS disabled',
                r.table_schema,
                r.table_name;

        end if;


        if r.direct_authenticated_access is distinct from false then

            raise exception
                '018 security hardening failed: registry table %.% permits direct authenticated access',
                r.table_schema,
                r.table_name;

        end if;


        select count(*)
        into v_policy_count
        from pg_policies
        where schemaname = r.table_schema
          and tablename = r.table_name
          and (
              'anon' = any(roles)
              or 'authenticated' = any(roles)
          );


        if v_policy_count > 0 then

            raise exception
                '018 security hardening failed: registry table %.% still has anon/authenticated policies',
                r.table_schema,
                r.table_name;

        end if;

    end loop;

end;
$$;


-- =====================================================
-- 16. SECURITY MODEL DOCUMENTATION
-- =====================================================

comment on table platform.security_table_registry is
'Central security classification for governed tables. Business tables are portal-accessible only through approved API/RPC contracts. Backend-only tables have no portal contract. Direct authenticated table access is prohibited. 018 enforces RLS/FORCE RLS and removes legacy direct-table policies. 019 owns privileges.';


-- =====================================================
-- 17. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)
values (
    '018_security_hardening',
    'REV22.SECURITY.HARDENING',
    false
)
on conflict (version) do nothing;


commit;