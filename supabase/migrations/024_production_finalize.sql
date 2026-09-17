-- =====================================================
-- REV1 GREENFIELD BASELINE
-- 024_PRODUCTION_FINALIZE.SQL
-- =====================================================
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
-- 003_crm_engine.sql
-- 004_property_device_engine.sql
-- 005_booking_lock_engine.sql
-- 006_integration_engine.sql
-- 007_device_telemetry_raw.sql
-- 008_device_telemetry_processing.sql
-- 009_operations_engine.sql
-- 010_preconfig_engine.sql
-- 011_logistics_engine.sql
-- 012_commerce_engine.sql
-- 013_service_portal_engine.sql
-- 014_onboarding_engine.sql
-- 015_optimization_engine.sql
-- 016_customer_proposal_monetization.sql
-- 017_automation_engine.sql
-- 018_edge_rpc_foundation.sql
-- 019_security_classification.sql
-- 020_security_hardening.sql
-- 021_grant_matrix_actors.sql
-- 022_grant_matrix.sql
-- 023_platform_bootstrap.sql
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
('003_crm_engine'),
('004_property_device_engine'),
('005_booking_lock_engine'),
('006_integration_engine'),
('007_device_telemetry_raw'),
('008_device_telemetry_processing'),
('009_operations_engine'),
('010_preconfig_engine'),
('011_logistics_engine'),
('012_commerce_engine'),
('013_service_portal_engine'),
('014_onboarding_engine'),
('015_optimization_engine'),
('016_customer_proposal_monetization'),
('017_automation_engine'),
('018_edge_rpc_foundation'),
('019_security_classification'),
('020_security_hardening'),
('021_grant_matrix_actors'),
('022_grant_matrix'),
('023_platform_bootstrap')
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
-- 018b_security_hardening.sql
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
-- 018_edge_rpc_foundation.sql
-- 019_security_classification.sql
-- 020_security_hardening.sql
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
-- 022_grant_matrix.sql
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
-- 023_platform_bootstrap.sql
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
'migration','024',
'status','PASSED',
'human_approval_required',true
)
);



-- =====================================================
-- 11. REGISTER MIGRATION
-- FINAL MIGRATION STATE
-- =====================================================


insert into platform.schema_migrations( migration_name, version, rollback_available)
values( '024_production_finalize', 'REV1.PRODUCTION.FINALIZE', false)
on conflict(version) do nothing;

commit;