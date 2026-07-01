-- =====================================================
-- 028 PLATFORM VIEWS EXTENSIONS (000)
-- Appsmith-safe read contracts for tenant event stream
-- Does NOT modify prior migrations
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('028_platform_views_extensions_rev19', 'REV19.PLATFORM.VIEWS.EXT', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. TENANT EVENT STREAM VIEW (read-only)
-- Underlying platform.event_log RLS applies via security_invoker
-- =====================================================

drop view if exists public.v_tenant_events;
drop view if exists public.v_tenant_audit;

create or replace view public.v_tenant_events_overview
with (security_invoker = true)
as
select
    e.id,
    e.tenant_id,
    e.user_id,
    e.event_type,
    e.source,
    e.severity,
    e.device_id,
    e.correlation_id,
    e.payload,
    e.created_at
from platform.event_log e
where e.tenant_id is not null;

create or replace view public.v_tenant_audit_overview
with (security_invoker = true)
as
select
    a.id,
    a.tenant_id,
    a.user_id,
    a.action,
    a.entity_type,
    a.entity_id,
    a.metadata,
    a.created_at
from platform.audit_log a
where a.tenant_id is not null;

grant select on public.v_tenant_events_overview to authenticated;
grant select on public.v_tenant_audit_overview to authenticated;

-- =====================================================
-- END 028 PLATFORM VIEWS EXTENSIONS
-- =====================================================
