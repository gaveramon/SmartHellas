-- REV22 greenfield baseline: 018_security_hardening.sql
-- Consolidated from migrations_archive_rev19 (000-053)

begin;


-- =====================================================
-- 1. SECURITY AUTHORITY & TENANT RESOLUTION GOVERNANCE
-- =====================================================

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
-- 2. RLS COMPATIBILITY SHIMS
-- =====================================================

-- =====================================================
-- REV21: single authority gate + RLS compatibility shims
-- =====================================================

comment on function platform.has_tenant_access(uuid) is
    'RLS shim only. tid = resolve_active_tenant(auth.uid()). Not an authority surface.';



comment on function public.has_tenant_access(uuid) is
    'RLS shim only. p_public_tenant_id = resolve_active_tenant(auth.uid()). Not an authority surface.';


alter function platform.has_tenant_access(uuid) set search_path = '';


alter function public.has_tenant_access(uuid) set search_path = '';



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


-- =====================================================
-- 3. SECURITY DEFINER HARDENING
-- =====================================================

do $$
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
        where
            p.prokind = 'f'
            and
            (
                n.nspname = 'platform'
                or
                (n.nspname = 'public' and p.prosecdef)
            )
    loop

        execute format(
            'alter function %I.%I(%s) set search_path = ''''',
            r.nspname,
            r.proname,
            r.args
        );

    end loop;

end;
$$ language plpgsql;


-- =====================================================
-- 4. SECURITY HARDENING VALIDATION
-- =====================================================

do $$
declare
    v_count integer;
begin

    select count(*)
    into v_count
    from pg_proc p
    join pg_namespace n
        on n.oid = p.pronamespace
    where
        p.prosecdef = true
        and n.nspname in ('public','platform')
        and
        (
            p.proconfig is null
            or not exists
            (
                select 1
                from unnest(p.proconfig) cfg
                where cfg like 'search_path=%'
            )
        );

    if v_count > 0 then
        raise exception
        '018 security hardening failed: SECURITY DEFINER functions without hardened search_path detected';
    end if;

end;
$$ language plpgsql;


-- =====================================================
-- 5. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values (''018_security_hardening', 'REV22.SECURITY.HARDENING', false)
on conflict (version) do nothing;


-- =====================================================
-- END 018 SECURITY HARDENING
-- =====================================================

commit;