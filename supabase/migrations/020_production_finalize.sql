-- REV22 greenfield baseline: 020_production_finalize.sql
-- Consolidated from migrations_archive_rev19 (000-053)

-- Production finalization: verification only

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('000_supabase_platform', '000.SUPABASE.PLATFORM', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('001_core_types', '001.CORE.TYPES', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('002_core_saas', '002.CORE.SAAS', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('003_property_device_engine', '003.PROPERTY.DEVICE.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('004_booking_lock_engine', '004.BOOKING.LOCK.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('005_integration_engine', '005.INTEGRATION.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('006_operations_engine', '006.OPERATIONS.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('007_preconfig_engine', '007.PRECONFIG.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('008_logistics_engine', '008.LOGISTICS.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('009_commerce_engine', '009.COMMERCE.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('010_service_portal_engine', '010.SERVICE.PORTAL.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('011_onboarding_engine', '011.ONBOARDING.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('012_optimization_engine', '012.OPTIMIZATION.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('013_customer_proposal_monetization', '013.CUSTOMER.PROPOSAL.MONETIZATION', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('014_platform_bootstrap', '014.PLATFORM.BOOTSTRAP', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('015_crm_engine', '015.CRM.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('016_automation_engine', '016.AUTOMATION.ENGINE', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('017_edge_rpc_foundation', '017.EDGE.RPC.FOUNDATION', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('018_security_hardening', '018.SECURITY.HARDENING', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('019_grant_matrix', '019.GRANT.MATRIX', false)
on conflict (version) do nothing;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('020_production_finalize', '020.PRODUCTION.FINALIZE', false)
on conflict (version) do nothing;

select platform.ensure_pg_cron_jobs();

do $$
declare v_count int;
begin
  select count(*) into v_count from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like '%_domain';
  if v_count < 10 then raise exception 'domain function count verification failed';
  end if;
end $$;
