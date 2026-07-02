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
-- 053_rev21_tenant_context.sql
-- REV21: domain tenant context (delegates to authority SSOT)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('053_rev21_tenant_context', 'REV21.TENANT.CONTEXT', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- platform.current_tenant_id: pure resolver wrapper (non-authoritative)
-- -----------------------------------------------------

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select public.resolve_active_tenant((select auth.uid()));
$$;

comment on function platform.current_tenant_id() is
    'Non-authoritative domain context reader. Delegates to resolve_active_tenant(auth.uid()) only.';

revoke all on function platform.current_tenant_id() from public;
grant execute on function platform.current_tenant_id() to authenticated, service_role;

alter function platform.current_tenant_id() set search_path = '';

-- =====================================================
-- END 053 REV21 TENANT CONTEXT
-- =====================================================
