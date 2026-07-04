-- REV22 greenfield baseline: 018_security_hardening.sql
-- Consolidated from migrations_archive_rev19 (000-053)

begin
    for r in
        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'platform'
           or (n.nspname = 'public' and p.prosecdef)
    loop
        execute format(
            'alter function %I.%I(%s) set search_path = ''''',
            r.nspname, r.proname, r.args
        );


-- =====================================================
-- REV21 FINAL AUTHORITY FREEZE
-- =====================================================

-- SINGLE SOURCE OF TRUTH ENFORCEMENT NOTE
-- Tenant resolution MUST ONLY occur via:
-- public.resolve_active_tenant(auth.uid())

-- DO NOT introduce:
-- - JWT-based tenant resolution
-- - membership EXISTS checks outside resolver
-- - alternative tenant gates

-- Any deviation is considered architecture drift
-- =====================================================

-- =====================================================
-- 052_rev21_tenant_access_control.sql
-- REV21: single authority gate + RLS compatibility shims
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('052_rev21_tenant_access_control', 'REV21.TENANT.ACCESS.CONTROL', false)
on conflict (version) do nothing;



comment on function platform.has_tenant_access(uuid) is
    'RLS shim only. tid = resolve_active_tenant(auth.uid()). Not an authority surface.';



comment on function public.has_tenant_access(uuid) is
    'RLS shim only. p_public_tenant_id = resolve_active_tenant(auth.uid()). Not an authority surface.';


alter function platform.has_tenant_access(uuid) set search_path = '';


alter function public.has_tenant_access(uuid) set search_path = '';


alter function public.integrations_api(text, jsonb) set search_path = '';


-- =====================================================
-- END 052 REV21 TENANT ACCESS CONTROL
-- =====================================================



-- -----------------------------------------------------
-- has_tenant_access: RLS compatibility shim (not an authority surface)
-- Pure delegate: tid = resolve_active_tenant(auth.uid())
-- -----------------------------------------------------

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
    select p_public_tenant_id = public.resolve_active_tenant((select auth.uid()));
$$;


