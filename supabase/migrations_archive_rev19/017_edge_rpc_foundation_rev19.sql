-- =====================================================
-- 017 EDGE RPC FOUNDATION (REV19)
-- Edge orchestration guards only — no business logic
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('017_edge_rpc_foundation_rev19', 'REV19.EDGE.RPC.FOUNDATION', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. PUBLIC WRAPPERS (authenticated JWT context)
-- =====================================================

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.is_platform_admin();
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated, service_role;

create or replace function public.edge_require_tenant()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if (select auth.uid()) is null then
        raise exception 'authentication required';
    end if;
    if platform.current_tenant_id() is null then
        raise exception 'no active tenant';
    end if;
end;
$$;

revoke all on function public.edge_require_tenant() from public;
grant execute on function public.edge_require_tenant() to authenticated, service_role;

create or replace function public.edge_require_manager()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    if not (
        platform.is_platform_admin()
        or platform.is_admin()
        or platform.has_role('manager')
    ) then
        raise exception 'manager, admin, or owner role required';
    end if;
end;
$$;

revoke all on function public.edge_require_manager() from public;
grant execute on function public.edge_require_manager() to authenticated, service_role;

create or replace function public.edge_require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_tenant();
    if not (platform.is_platform_admin() or platform.is_admin()) then
        raise exception 'admin or owner role required';
    end if;
end;
$$;

revoke all on function public.edge_require_admin() from public;
grant execute on function public.edge_require_admin() to authenticated, service_role;

-- =====================================================
-- END 017 EDGE RPC FOUNDATION
-- =====================================================
