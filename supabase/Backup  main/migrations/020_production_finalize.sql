-- =====================================================
-- REV22 GREENFIELD BASELINE
-- 020_PRODUCTION_FINALIZE.SQL
--
-- Purpose:
-- Production readiness verification gate
--
-- Rules:
-- - NO schema mutation
-- - NO permission mutation
-- - NO RLS mutation
-- - NO function replacement
--
-- Depends on:
--
-- 000_supabase_platform.sql
-- 001_core_types.sql
-- 002_core_saas.sql
-- 003_property_device_engine.sql
-- 004_booking_lock_engine.sql
-- 005_integration_engine.sql
-- 006_operations_engine.sql
-- 007_preconfig_engine.sql
-- 008_logistics_engine.sql
-- 009_commerce_engine.sql
-- 010_service_portal_engine.sql
-- 011_onboarding_engine.sql
-- 012_optimization_engine.sql
-- 013_customer_proposal_monetization.sql
-- 014_platform_bootstrap.sql
-- 015_crm_engine.sql
-- 016_automation_engine.sql
-- 017_edge_rpc_foundation.sql
-- 018_security_hardening.sql
-- 019_grant_matrix.sql
--
-- Auditor mapping:
--
-- KGS-001 Principles
-- KGS-002 Object Catalog
-- KGS-003 Workflow Catalog
-- KGS-004 Ownership Catalog
-- KGS-005 Business Rules
--
-- =====================================================


begin;



-- =====================================================
-- 2. VERIFY REQUIRED MODULE MIGRATIONS
-- KGS-002 MODULE CATALOG VALIDATION
-- =====================================================


do $$
declare
    missing_count int;
begin

select count(*)
into missing_count
from
(
values
('000_supabase_platform'),
('001_core_types'),
('002_core_saas'),
('003_property_device_engine'),
('004_booking_lock_engine'),
('005_integration_engine'),
('006_operations_engine'),
('007_preconfig_engine'),
('008_logistics_engine'),
('009_commerce_engine'),
('010_service_portal_engine'),
('011_onboarding_engine'),
('012_optimization_engine'),
('013_customer_proposal_monetization'),
('014_platform_bootstrap'),
('015_crm_engine'),
('016_automation_engine'),
('017_edge_rpc_foundation'),
('018_security_hardening'),
('019_grant_matrix')
)
required(version)

where not exists
(
select 1
from platform.schema_migrations m
where m.version = required.version
);


if missing_count > 0 then

raise exception
'Production finalize failed: missing migrations detected';

end if;

end $$;



-- =====================================================
-- 3. VERIFY TENANT AUTHORITY MODEL
-- KGS-001 SINGLE SOURCE OF TRUTH
-- =====================================================


do $$

declare
v_missing int;

begin


select count(*)
into v_missing

from pg_proc p
join pg_namespace n
on n.oid=p.pronamespace

where n.nspname='public'
and p.proname='resolve_active_tenant';


if v_missing = 0 then

raise exception
'Tenant resolver missing. SSOT violation.';

end if;


end $$;



-- =====================================================
-- 4. VERIFY SECURITY DEFINER HARDENING
-- SECURITY EXECUTION BOUNDARY
--
-- Reference:
-- 018_security_hardening.sql
--
-- Rule:
-- SECURITY DEFINER functions must have empty search_path
-- =====================================================


do $$

declare
v_count int;

begin


select count(*)
into v_count

from pg_proc p
join pg_namespace n
on n.oid=p.pronamespace

where p.prosecdef=true

and
(
p.proconfig is null
or
not exists
(
select 1
from unnest(p.proconfig) cfg
where cfg like 'search_path=%'
)
);


if v_count > 0 then

raise exception
'Security finalize failed: SECURITY DEFINER functions without hardened search_path detected';

end if;


end $$;



-- =====================================================
-- 5. VERIFY RLS ENABLEMENT
-- ROW-LEVEL SECURITY BOUNDARY
--
-- Reference:
-- 017_edge_rpc_foundation.sql
-- 018_security_hardening.sql
-- =====================================================


do $$

declare
v_count int;

begin


select count(*)
into v_count

from pg_tables

where schemaname='public'
and rowsecurity=false;


if v_count > 0 then

raise exception
'RLS validation failed: public tables without RLS detected';

end if;


end $$;



-- =====================================================
-- 6. VERIFY GRANT MATRIX
-- PERMISSION BOUNDARY
--
-- Reference:
-- 019_grant_matrix.sql
--
-- No anonymous execution allowed
-- =====================================================


do $$

declare
v_count int;

begin


select count(*)
into v_count

from information_schema.routine_privileges

where grantee='anon'
and privilege_type='EXECUTE';


if v_count > 0 then

raise exception
'Grant matrix violation: anon EXECUTE privileges detected';

end if;


end $$;



-- =====================================================
-- 7. VERIFY DOMAIN API SURFACE
-- KGS-002 MODULE INTERFACE VALIDATION
-- =====================================================


do $$

declare
v_count int;

begin


select count(*)
into v_count

from pg_proc p
join pg_namespace n
on n.oid=p.pronamespace

where n.nspname='public'
and p.proname like '%_domain';


if v_count < 10 then

raise exception
'Domain interface validation failed';

end if;


end $$;



-- =====================================================
-- 8. VERIFY REQUIRED PORTAL VIEWS
-- PORTAL REPORTING SSOT
-- =====================================================


do $$

declare
v_count int;

begin


select count(*)
into v_count

from pg_views

where schemaname='public'
and viewname in
(
'v_devices_overview',
'v_properties_overview',
'v_bookings_overview',
'v_subscription_overview',
'v_onboarding_progress'
);


if v_count < 5 then

raise exception
'Portal SSOT views missing';

end if;


end $$;



-- =====================================================
-- 9. VERIFY OPERATIONAL SCHEDULING
-- CRON INFRASTRUCTURE
--
-- Reference:
-- 014_platform_bootstrap.sql
-- =====================================================


select platform.ensure_pg_cron_jobs();



-- =====================================================
-- 10. REGISTER FINAL PRODUCTION AUDIT EVENT
-- HUMAN APPROVAL CHECKPOINT
-- =====================================================


insert into platform.audit_log
(
event_type,
event_name,
metadata
)

values
(
'ARCHITECTURE_VALIDATION',
'PRODUCTION_FINALIZE_COMPLETED',
jsonb_build_object
(
'revision','REV22',
'migration','020',
'status','PASSED',
'human_approval_required',true
)
);



-- =====================================================
-- 11. REGISTER MIGRATION
-- FINAL MIGRATION STATE
-- =====================================================


insert into platform.schema_migrations( migration_name, version, rollback_available)
values( '020_production_finalize', '020.PRODUCTION.FINALIZE', false)
on conflict(version) do nothing;

commit;