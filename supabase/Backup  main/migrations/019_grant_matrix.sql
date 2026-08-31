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
-- =====================================================


begin;



-- =====================================================
-- 002 GLOBAL SECURITY RESET
--
-- Establish the baseline:
-- No uncontrolled schema or function execution surface
-- =====================================================


revoke all on schema public from public;
revoke all on schema platform from public;



-- Remove public function execution

do $$
declare
 r record;

begin

for r in

select
 n.nspname,
 p.proname,
 pg_get_function_identity_arguments(p.oid) args

from pg_proc p
f
join pg_namespace n
on n.oid=p.pronamespace

where n.nspname in ('public','platform')

loop

execute format(
'revoke all on function %I.%I(%s) from public',
r.nspname,
r.proname,
r.args
);

end loop;

end $$;



-- =====================================================
-- 003 SECURITY DEFINER HARDENING
--
-- Harden SECURITY DEFINER functions against
-- search_path manipulation
-- =====================================================


do $$
declare
r record;

begin

for r in

select
n.nspname,
p.proname,
pg_get_function_identity_arguments(p.oid) args

from pg_proc p

join pg_namespace n
on n.oid=p.pronamespace

where p.prosecdef=true

loop


execute format(
'alter function %I.%I(%s)
set search_path = ''''',
r.nspname,
r.proname,
r.args
);


end loop;

end $$;



-- =====================================================
-- 004 PLATFORM INTERNAL FUNCTIONS
--
-- Platform-internal functions are executable only
-- by service_role
-- =====================================================


do $$
declare
 r record;

begin

for r in

select
n.nspname,
p.proname,
pg_get_function_identity_arguments(p.oid) args

from pg_proc p

join pg_namespace n
on n.oid=p.pronamespace

where n.nspname='platform'

loop

execute format(
'grant execute on function %I.%I(%s) to service_role',
r.nspname,
r.proname,
r.args
);

end loop;

end $$;



-- =====================================================
-- 005 DOMAIN INTERNAL FUNCTIONS
--
-- Domain-internal functions are never exposed
-- to authenticated users
-- =====================================================


do $$
declare
 r record;

begin

for r in

select
n.nspname,
p.proname,
pg_get_function_identity_arguments(p.oid) args

from pg_proc p

join pg_namespace n
on n.oid=p.pronamespace

where n.nspname='public'
and
(
p.proname like '%\_domain'
escape '\'
or
p.proname like '%\_domain_ext%'
escape '\'
)

loop


execute format(
'revoke all on function %I.%I(%s) from authenticated',
r.nspname,
r.proname,
r.args
);


execute format(
'grant execute on function %I.%I(%s) to service_role',
r.nspname,
r.proname,
r.args
);


end loop;

end $$;



-- =====================================================
-- 006 APPROVED API SURFACE
--
-- Only explicitly approved public API contracts
-- are executable by authenticated users
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
-- Authenticated users receive only the helper
-- functions required for tenant and permission checks
-- =====================================================


grant execute on function platform.current_tenant_id()
to authenticated;


grant execute on function platform.has_role(text)
to authenticated;


grant execute on function platform.has_permission(text)
to authenticated;



revoke execute on function public.resolve_active_tenant(uuid,uuid)
from authenticated;



-- =====================================================
-- 008 TENANT-SAFE VIEW ACCESS
--
-- Authenticated users may read only approved
-- tenant-safe projection views
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
-- 009 SECURITY BOUNDARY VALIDATION
--
-- Verify that internal SECURITY DEFINER functions
-- have not accidentally been exposed to authenticated
-- users
-- =====================================================


do $$

declare
violations integer;

begin


select count(*)

into violations

from pg_proc p

join pg_namespace n
on n.oid=p.pronamespace

where

n.nspname='public'

and

p.prosecdef=true

and

p.proacl::text like '%authenticated%'

and

(
p.proname like '%domain%'
or
p.proname like '%internal%'
);



if violations > 0 then

raise exception
'SECURITY VIOLATION: authenticated access detected on internal SECURITY DEFINER functions';

end if;



end $$;



-- =====================================================
-- 010 SECURITY AUDIT EVENT
--
-- Record successful application of the
-- grant boundary
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
-- 011 MIGRATION REGISTRATION
--
-- Register the completed security grant boundary
-- in the platform migration ledger
-- =====================================================


insert into platform.schema_migrations (migration_name, version, rollback_available)
values( '019_grant_matrix', 'REV22.GRANT.MATRIX', false)
on conflict (version) do nothing;



-- =====================================================
-- END 019 GRANT MATRIX
-- =====================================================


commit;