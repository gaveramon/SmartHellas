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
-- security_class:
--   business = business/domain ownership
--   backend  = backend/platform ownership
--
-- portal_access:
--   rpc  = portal access only through approved API/RPC
--   none = no portal contract
--
-- platform_admin_access:
--   true  = platform-admin access may exist through explicit
--           platform-admin API/RPC contracts
--   false = no platform-admin contract
--
-- direct_authenticated_access:
--   MUST remain false for all governed tables.
--
-- The security_table_registry is the single maintenance
-- point for the table security boundary.
-- =====================================================


begin;


-- =====================================================
-- 1. SECURITY AUTHORITY FREEZE
-- =====================================================

comment on schema public is
'Business schema. Tenant authority MUST resolve through public.resolve_active_tenant(auth.uid()). Portal access to registered tables is API/RPC-only.';

comment on schema platform is
'Platform infrastructure and security control plane. No business-domain ownership unless explicitly classified in the security registry.';


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
-- security_class:
--   business / backend
--
-- portal_access:
--   rpc / none
--
-- Portal access is ALWAYS API/RPC mediated.
-- No authenticated role receives direct table access.
-- =====================================================

insert into platform.security_table_registry (
    table_schema,
    table_name,
    security_class,
    portal_access,
    platform_admin_access,
    direct_authenticated_access,
    rls_required,
    force_rls_required,
    is_active,
    description
)
values

    -- =================================================
    -- 000 PLATFORM / IDENTITY
    -- =================================================

    (
        'platform',
        'profiles',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global user identity profile. Tenant portal access through approved API/RPC contracts; platform-admin access through explicit platform-admin RPC contracts; no direct authenticated table access.'
    ),

    (
        'platform',
        'platform_admins',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Platform operator registry. Backend/security controlled; platform-admin status is resolved through controlled security functions; no portal or direct authenticated table access.'
    ),

    -- =================================================
    -- 000 PLATFORM / AUDIT + COMPLIANCE
    -- =================================================

    (
        'platform',
        'audit_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Immutable platform audit log. Platform-admin visibility only through explicit security/audit RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'constants',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Global platform constants. System-controlled; no portal or platform-admin table access.'
    ),

    (
        'platform',
        'soft_delete_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Recovery and soft-delete audit data. Platform-admin visibility only through explicit administrative RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'error_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform error and diagnostic log. Platform-admin visibility only through explicit administrative RPC; direct table access remains backend/service-role only.'
    ),

    -- =================================================
    -- 000 PLATFORM / EVENT + EXECUTION
    -- =================================================

    (
        'platform',
        'internal_events',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Internal platform event stream. Worker/backend processing only; no platform-admin table access.'
    ),

    (
        'platform',
        'event_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Internal high-volume event stream. Platform-admin visibility only through explicit observability RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'event_outbox',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Internal consistency outbox. Worker/backend processing only; no platform-admin table access.'
    ),

    (
        'platform',
        'execution_supervisor',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform execution health supervisor. Platform-admin visibility only through explicit operations/observability RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'operation_contexts',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Transient workflow execution context inbox. Worker/backend processing only; no platform-admin table access.'
    ),

    (
        'platform',
        'operation_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Internal command and operation execution log. Platform-admin visibility only through explicit operations RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'dead_letter_archive',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Final failure archive for platform processing. Platform-admin visibility only through explicit operations/observability RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'retry_tasks',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Generic worker retry queue. Platform-admin visibility or controlled retry actions only through explicit operations RPC; direct table access remains backend/service-role only.'
    ),

    -- =================================================
    -- 000 PLATFORM / DEVICE EXECUTION
    -- =================================================

    (
        'platform',
        'device_commands',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Device command execution queue. Platform-admin may inspect or manage commands only through explicit operations/device-admin RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'device_commands_dlq',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Failed device command dead-letter queue. Platform-admin visibility or controlled recovery only through explicit operations RPC; direct table access remains backend/service-role only.'
    ),

    -- =================================================
    -- 000 PLATFORM / INTEGRATION + WEBHOOK
    -- =================================================

    (
        'platform',
        'external_webhooks',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'External webhook ingestion boundary. Platform-admin may inspect operational state only through explicit integration/operations RPC; backend processing remains service-role controlled.'
    ),

    (
        'platform',
        'webhook_provider_tenant_map',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'External provider account to tenant resolution map. Platform-admin access only through explicit integration administration RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'integration_queue',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Durable integration delivery queue. Platform-admin visibility or controlled operational actions only through explicit integration/operations RPC.'
    ),

    -- =================================================
    -- 000 PLATFORM / LOGISTICS EXECUTION
    -- =================================================

    (
        'platform',
        'shipment_dispatch_queue',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned shipment dispatch execution queue. Platform-admin operational visibility or controlled actions only through explicit logistics administration RPC.'
    ),

    (
        'platform',
        'shipment_tracking_events',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned shipment tracking event storage. Platform-admin visibility only through explicit logistics/operations RPC; direct table access remains backend/service-role only.'
    ),

    -- =================================================
    -- 000 PLATFORM / PAYMENT EXECUTION
    -- =================================================

    (
        'platform',
        'payment_intents',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned payment execution state. Portal may access tenant-scoped payment information only through approved payment API/RPC contracts; direct authenticated table access is prohibited.'
    ),

    (
        'platform',
        'payment_events',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned immutable payment lifecycle events. Portal may read tenant-scoped history only through approved payment API/RPC contracts; direct authenticated table access is prohibited.'
    ),

    (
        'platform',
        'payment_provider_refs',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Provider reference mapping for payment execution. Platform-admin visibility only through explicit payment administration RPC; direct table access remains backend/service-role only.'
    ),

    -- =================================================
    -- 000 PLATFORM / SCHEDULING + NODES
    -- =================================================

    (
        'platform',
        'scheduled_jobs',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform scheduled-job control registry. Platform-admin management only through explicit scheduling/operations RPC; direct table access remains backend/service-role only.'
    ),

    (
        'platform',
        'job_executions',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Scheduled job execution history. Platform-admin visibility only through explicit scheduling/observability RPC.'
    ),

    (
        'platform',
        'system_nodes',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Canonical platform node registry. Platform-admin visibility/management only through explicit platform operations RPC.'
    ),

    (
        'platform',
        'node_heartbeats',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform node liveness history. Platform-admin visibility only through explicit observability RPC.'
    ),

    -- =================================================
    -- 000 PLATFORM / OBSERVABILITY
    -- =================================================

    (
        'platform',
        'query_performance_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Query performance observability data. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'queue_processor_logs',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Queue processor observability data. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'event_lag_monitor',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Queue and event lag monitoring data. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'system_metrics',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Raw platform system metrics. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'system_metrics_aggregated',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Aggregated platform system metrics. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'performance_snapshots',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform performance snapshots. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'index_usage_stats',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Database index usage telemetry. Platform-admin visibility only through explicit observability RPC.'
    ),

    (
        'platform',
        'slow_query_flags',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Slow-query anomaly registry. Platform-admin visibility only through explicit observability RPC.'
    ),

    -- =================================================
    -- 000 PLATFORM / SCHEMA + ARCHITECTURE CONTROL
    -- =================================================

    (
        'platform',
        'table_contracts',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform table contract registry. Platform-admin visibility only through explicit architecture/security administration RPC.'
    ),

    (
        'platform',
        'utility_function_registry',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Platform utility function dependency registry. Platform-admin visibility only through explicit architecture/security administration RPC.'
    ),

    (
        'platform',
        'schema_change_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Structured schema evolution log. Platform-admin visibility only through explicit architecture administration RPC.'
    ),

    (
        'platform',
        'schema_migrations',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Applied migration registry. Platform-admin visibility only through explicit architecture administration RPC.'
    ),

    (
        'platform',
        'migration_execution_log',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Migration execution audit log. Platform-admin visibility only through explicit architecture administration RPC.'
    ),

    (
        'platform',
        'realtime_streams',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Declarative realtime stream configuration. Platform-admin management only through explicit platform administration RPC.'
    ),

    -- =================================================
    -- 002 CORE SAAS
    -- =================================================

    (
        'public',
        'tenants',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant master data. Tenant portal access through approved API/RPC contracts; platform-admin access through explicit platform tenant administration RPC.'
    ),

    (
        'public',
        'tenant_memberships',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant membership and role data. Tenant portal access through approved API/RPC contracts; platform-admin access through explicit platform user/tenant administration RPC.'
    ),

    (
        'public',
        'subscriptions',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Subscription data and commercial plan binding. Tenant portal access through approved subscription/commerce API/RPC contracts; platform-admin access through explicit administration RPC.'
    ),

    (
        'public',
        'service_accounts',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Internal service-account data. Backend/service-role only; no portal or platform-admin table access.'
    ),

    -- =================================================
    -- 003 CRM ENGINE
    -- =================================================
    
    (
        'public',
        'crm_pipelines',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM sales pipeline definitions. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_pipeline_stages',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM pipeline stage definitions. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_campaigns',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM marketing campaign definitions. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_tags',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM tag definitions. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_companies',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM company records and customer-company relationships. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_contacts',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM contact SSOT including contact details and consent state. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_leads',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM prospect and lead records including conversion state. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_contact_company',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM contact-to-company relationship records. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_company_tenants',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM company-to-customer-tenant relationship records. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_contact_tenants',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM contact-to-customer-tenant relationship records. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_opportunities',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM sales opportunity records including pipeline, stage, revenue and ownership. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_tasks',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM follow-up task records. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_interactions',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM append-oriented interaction history. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_notes',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM entity notes and note version state. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_tag_assignments',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM tag-to-entity assignments. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_lists',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM contact list definitions and optional dynamic filter configuration. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_list_members',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM list membership records. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_custom_fields',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM custom field definitions. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
    
    (
        'public',
        'crm_custom_field_values',
        'business',
        'api',
        true,
        true,
        true,
        true,
        'CRM custom field values attached to CRM entities. Portal access exclusively through approved CRM API/RPC contracts; direct table access denied.'
    ),
  
    -- =================================================
    -- 004 PROPERTY / DEVICE ENGINE
    -- =================================================

    (
        'public',
        'properties',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Property and Device Engine business table. Tenant portal access exclusively through approved devices API/RPC contracts; platform-admin access through explicit platform/property administration RPC.'
    ),

    (
        'public',
        'rooms',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Property and Device Engine business table. Tenant portal access exclusively through approved devices API/RPC contracts; platform-admin access through explicit platform/property administration RPC.'
    ),

    (
        'public',
        'device_categories',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Device taxonomy business table. Tenant portal read access through approved devices API/RPC contracts; platform-admin catalog administration through explicit platform/device administration RPC.'
    ),

    (
        'public',
        'devices',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'SmartHellas device registry SSOT. Tenant portal access exclusively through approved devices API/RPC contracts; platform-admin access through explicit platform/device administration RPC.'
    ),

    (
        'public',
        'device_assignments',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Device-to-room assignment business table. Tenant portal access exclusively through approved devices API/RPC contracts; platform-admin access through explicit platform/device administration RPC.'
    ),

    (
        'public',
        'device_configurations',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Static device provisioning configuration. Tenant portal access exclusively through approved devices API/RPC contracts; platform-admin access through explicit platform/device administration RPC.'
    ),

    -- =================================================
    -- 005 BOOKING / LOCK ENGINE
    -- =================================================

    (
        'public',
        'bookings',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Booking SSOT. Tenant portal access exclusively through approved booking domain API/RPC operations; platform-admin access through explicit platform booking administration RPC.'
    ),

    (
        'public',
        'property_access_schedules',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Guest access-window template per property. Tenant portal access exclusively through booking domain RPC operations; platform-admin access through explicit platform booking administration RPC.'
    ),

    (
        'public',
        'booking_access',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Resolved guest access window per booking. Tenant portal access exclusively through approved booking domain RPC operations; platform-admin access through explicit platform booking administration RPC.'
    ),

    (
        'public',
        'access_policies',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Non-guest access grants. Tenant portal access exclusively through approved booking domain RPC operations; platform-admin access through explicit platform access administration RPC.'
    ),

    (
        'public',
        'access_rules',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Property-level access exceptions. Tenant portal access exclusively through approved booking domain RPC operations; platform-admin access through explicit platform access administration RPC.'
    ),

    (
        'public',
        'lock_devices',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Property-to-lock device mapping. Tenant portal access exclusively through approved locks domain RPC operations; platform-admin access through explicit platform/device administration RPC.'
    ),

    (
        'public',
        'access_credentials',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Issued credential metadata. Tenant portal may read through approved locks domain RPC operations; credential issuance/revocation remains controlled. Platform-admin access is through explicit administrative RPC and must never expose plaintext credentials.'
    ),

    -- =================================================
    -- 006 INTEGRATION ENGINE
    -- =================================================

    (
        'public',
        'integration_providers',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Integration provider catalog. Tenant portal access only through approved API/RPC contracts; platform-admin catalog administration through explicit integration administration RPC.'
    ),

    (
        'public',
        'integration_capabilities',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Provider capability catalog. Tenant portal access only through approved API/RPC contracts; platform-admin access through explicit integration administration RPC.'
    ),

    (
        'public',
        'integration_oauth_configs',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'OAuth configuration metadata. Backend-controlled; platform-admin access only through explicitly scoped integration administration RPC and never through direct table access.'
    ),

    (
        'public',
        'integration_oauth_states',
        'backend',
        'none',
        false,
        false,
        true,
        true,
        true,
        'Transient OAuth transaction state. Backend/service-role and security-definer lifecycle only; no platform-admin table access.'
    ),

    (
        'public',
        'tenant_integrations',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant integration configuration. Tenant portal access only through approved API/RPC contracts; platform-admin access through explicit integration administration RPC.'
    ),

    (
        'public',
        'webhook_definitions',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant webhook configuration. Tenant portal access only through approved API/RPC contracts; platform-admin access through explicit integration administration RPC.'
    ),

    (
        'public',
        'device_integration_map',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Provider-to-device identity mapping. Tenant portal access only through approved API/RPC contracts; platform-admin access through explicit integration/device administration RPC.'
    ),

    -- =================================================
    -- 007 DEVICE TELEMETRY RAW
    -- =================================================

    (
        'public',
        'device_telemetry_raw',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Immutable raw device telemetry. Backend/service-role ingestion and processing only; platform-admin visibility through explicit telemetry/observability RPC without direct table access.'
    ),

    -- =================================================
    -- 008 DEVICE TELEMETRY PROCESSING
    -- =================================================
    --
    -- No additional 008 telemetry-processing tables were
    -- present in the supplied registry input. Do not invent
    -- table names here; they must be added from migration
    -- 008 once its authoritative table list is available.
    -- =================================================

    -- =================================================
    -- 009 OPERATIONS ENGINE
    -- =================================================

    (
        'public',
        'operation_templates',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'System and tenant operation templates. Portal access exclusively through operations API/RPC contracts. System templates are globally readable; tenant templates are tenant-scoped. Platform admins may inspect system and tenant templates through approved domain API.'
    ),

    (
        'public',
        'operation_workflows',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant workflow definitions. Portal access exclusively through operations API/RPC contracts. Tenant-scoped; platform-admin access only through approved domain/API operations.'
    ),

    (
        'public',
        'workflow_steps',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Workflow step definitions belonging to tenant workflows. No direct authenticated access; portal access exclusively through operations API/RPC contracts. Platform-admin access through approved domain/API operations.'
    ),

    (
        'public',
        'workflow_triggers',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Workflow trigger definitions associated with tenant workflows and optionally properties. No direct authenticated access; portal access exclusively through operations API/RPC contracts. Platform-admin access through approved domain/API operations.'
    ),

    (
        'public',
        'notification_templates',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'System and tenant notification message templates. Portal access exclusively through notification domain RPC contracts. System templates are globally readable; tenant templates are tenant-scoped. Platform-admin access through approved domain/API operations.'
    ),

    (
        'public',
        'notification_preferences',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant and user notification preferences. Portal access exclusively through notification domain RPC contracts. Tenant-scoped and user-scoped where applicable. Platform-admin access remains API/RPC mediated.'
    ),

    (
        'public',
        'notification_queue',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned pending notification delivery records. Portal may inspect or cancel records only through approved notification domain RPC contracts; actual delivery processing remains backend/service-role responsibility.'
    ),

    (
        'public',
        'notification_history',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned historical notification delivery records including recipient, message metadata and delivery errors. Portal reads only through approved notification domain RPC contracts; backend workers retain operational ownership.'
    ),

    (
        'public',
        'support_tickets',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant support case master records. Portal access exclusively through approved support/operations API/RPC contracts. Tenant users may access their tenant data; platform admin/support access is domain API mediated.'
    ),

    (
        'public',
        'support_messages',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Messages belonging to support tickets. Portal access exclusively through approved support/operations API/RPC contracts. Tenant scope is enforced through ticket and tenant consistency controls.'
    ),

    -- =================================================
    -- 010 PRECONFIG ENGINE
    -- =================================================

    (
        'public',
        'device_bundles',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global versioned hardware bundle catalog. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin catalog administration through explicit platform preconfig RPC.'
    ),

    (
        'public',
        'bundle_devices',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Hardware components belonging to device bundles. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin administration through explicit platform preconfig RPC.'
    ),

    (
        'public',
        'onboarding_blueprints',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global onboarding and installation blueprint catalog. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin administration through explicit platform preconfig RPC.'
    ),

    (
        'public',
        'onboarding_blueprint_steps',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Ordered steps belonging to global onboarding blueprints. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin administration through explicit platform preconfig RPC.'
    ),

    (
        'public',
        'preconfig_templates',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global preconfiguration template catalog. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin administration through explicit platform preconfig RPC.'
    ),

    (
        'public',
        'preconfig_device_map',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Device-to-room installation mapping within preconfiguration templates. Tenant portal access exclusively through preconfig API/RPC contracts; platform-admin administration through explicit platform preconfig RPC.'
    ),

    -- =================================================
    -- 011 LOGISTICS — BUSINESS
    -- =================================================

    (
        'public',
        'shipping_carriers',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global shipping carrier catalog. Portal reads through approved logistics API/RPC contracts; mutations require platform-admin authorization; no direct authenticated table access.'
    ),

    (
        'public',
        'shipping_label_templates',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global carrier-specific shipping label definitions. Portal reads through approved logistics API/RPC contracts; mutations require platform-admin authorization; no direct authenticated table access.'
    ),

    (
        'public',
        'logistics_templates',
        'business',
        'rpc',
        false,
        false,
        true,
        true,
        true,
        'Tenant-scoped logistics delivery templates with optional system templates. Portal access exclusively through approved logistics API/RPC contracts; tenant mutations require manager authorization.'
    ),

    (
        'public',
        'warehouses',
        'business',
        'rpc',
        false,
        false,
        true,
        true,
        true,
        'Tenant-scoped fulfilment origin locations with optional system warehouses. Portal access exclusively through approved logistics API/RPC contracts; tenant mutations require manager authorization.'
    ),

    (
        'public',
        'shipping_rules',
        'business',
        'rpc',
        false,
        false,
        true,
        true,
        true,
        'Tenant-scoped shipping routing and pricing rules with optional system rules. Portal access exclusively through approved logistics API/RPC contracts; tenant mutations require manager authorization.'
    ),

    (
        'public',
        'package_definitions',
        'business',
        'rpc',
        false,
        false,
        true,
        true,
        true,
        'Shipment package definitions linking logistics templates to device bundles. Tenant scope is inherited through the parent logistics template. Portal access exclusively through approved logistics API/RPC contracts.'
    ),

    (
        'public',
        'fulfilment_orders',
        'business',
        'rpc',
        false,
        false,
        true,
        true,
        true,
        'Tenant-scoped shipment intent. Portal reads and mutations exclusively through approved logistics API/RPC contracts; tenant mutations require manager authorization; dispatch execution and tracking remain in the platform layer.'
    ),

    -- =================================================
    -- 012 COMMERCE ENGINE
    -- =================================================

    (
        'public',
        'product_plans',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Commercial subscription plan catalog. Portal reads active plans and platform admins manage plans exclusively through commerce API/RPC contracts.'
    ),

    (
        'public',
        'plan_pricing',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Commercial pricing attached to product plans. Portal reads pricing through commerce API/RPC contracts; platform admins manage pricing through RPC only.'
    ),

    (
        'public',
        'feature_entitlements',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Plan feature entitlement definitions. Portal reads effective entitlements through commerce API/RPC contracts; platform admins manage definitions through RPC only.'
    ),

    (
        'public',
        'upsell_rules',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped and platform-wide subscription upsell rule definitions. Portal access exclusively through commerce API/RPC contracts; tenant managers and platform admins are authorized by RPC.'
    ),

    (
        'platform',
        'payment_intents',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned payment intent execution state. Portal may access tenant-scoped payment information only through approved payment API/RPC contracts; direct authenticated table access is prohibited.'
    ),

    (
        'platform',
        'payment_events',
        'backend',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Backend-owned immutable payment lifecycle/event history. Portal may read tenant-scoped history only through approved payment API/RPC contracts; direct authenticated access is prohibited.'
    ),

    -- =================================================
    -- 013 SERVICE & PORTAL ENGINE
    -- =================================================

    (
        'public',
        'tenant_portal_settings',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped portal UI configuration SSOT. Portal access only through portal domain API/RPC contracts. Platform admins may access for tenant administration.'
    ),

    (
        'public',
        'dashboard_configs',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped dashboard layout configuration. Portal access only through portal domain API/RPC contracts. Platform admins may access for tenant administration.'
    ),

    (
        'public',
        'portal_user_preferences',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Per-user portal UI preferences scoped to tenant and authenticated user. Portal access only through portal domain API/RPC contracts. Platform admins may access for support and administration.'
    ),

    (
        'public',
        'portal_feature_flags',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped UI-only feature visibility flags using ui_* keys. Plan entitlement truth remains in feature_entitlements. Portal access only through portal domain API/RPC contracts.'
    ),

    -- =================================================
    -- 014 ONBOARDING ENGINE
    -- =================================================

    (
        'public',
        'onboarding_sessions',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped onboarding sessions per property. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_step_state',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped onboarding wizard step progress. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_room_mapping',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped room mapping input created during onboarding. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_device_mapping',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped device placement and QR pairing outcome state. No execution. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_checklist',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped onboarding checklist and business validation state. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_notes',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped onboarding notes and support context. Portal access only through onboarding domain RPC.'
    ),

    (
        'public',
        'onboarding_lifecycle',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped property onboarding lifecycle state. State changes through controlled onboarding lifecycle RPC.'
    ),

    (
        'public',
        'onboarding_lifecycle_transitions',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Immutable tenant-scoped onboarding lifecycle transition history. Portal read access only through approved RPC.'
    ),

    -- =================================================
    -- 015 OPTIMIZATION ENGINE
    -- =================================================

    (
        'public',
        'optimization_rules',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped optimization rules. Portal access only via optimization API/RPC contracts; no direct authenticated table access.'
    ),

    (
        'public',
        'insight_events',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped non-actionable insight events. Portal read-only via optimization API/RPC contracts; creation and mutation are backend/service-role responsibilities.'
    ),

    (
        'public',
        'optimization_recommendations',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped advisory recommendations. Portal access only via optimization API/RPC contracts; creation is backend/service-role controlled while approved portal mutations are RPC-mediated.'
    ),

    (
        'public',
        'device_usage_scores',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped device usage analytics. Backend-generated analytical snapshots; portal read-only via optimization API/RPC contracts.'
    ),

    (
        'public',
        'energy_profiles',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped property energy analytics. Backend-generated analytical snapshots; portal read-only via optimization API/RPC contracts.'
    ),

    -- =================================================
    -- 016 CUSTOMER PROPOSAL & MONETIZATION
    -- =================================================

    (
        'public',
        'customer_proposals',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped commercial customer proposals. Portal access only through approved monetization API/RPC operations.'
    ),

    (
        'public',
        'proposal_items',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped proposal line items. Portal access only through approved monetization API/RPC operations; tenant consistency enforced against customer_proposals.'
    ),

    (
        'public',
        'monetization_packages',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Global commercial package catalog. Readable by portal through RPC; creation, update and deletion restricted to platform administrators.'
    ),

    (
        'public',
        'upsell_campaigns',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant/global commercial upsell campaigns. Portal access only through approved monetization API/RPC operations; management restricted to managers/platform administrators.'
    ),

    (
        'public',
        'conversion_events',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Append-only commercial funnel events. Portal may read tenant-scoped events through RPC; event insertion and mutation are backend/platform controlled.'
    ),

    (
        'public',
        'conversion_scores',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped analytical conversion scoring data. Portal may read through RPC; calculation and mutation are backend controlled.'
    ),

    (
        'public',
        'service_activation_state',
        'backend',
        'none',
        true,
        false,
        true,
        true,
        true,
        'Worker-maintained service activation projection derived from subscriptions and feature entitlements. Not app-writable truth; service-role/workers only.'
    ),

    -- =================================================
    -- 017 AUTOMATION ENGINE
    -- =================================================

    (
        'public',
        'automation_runs',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped automation runtime executions. Portal access exclusively through approved automation API/RPC contracts; no direct authenticated table access.'
    ),

    (
        'public',
        'automation_run_steps',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped automation workflow step execution state. Portal access exclusively through approved automation API/RPC contracts; no direct authenticated table access.'
    ),

    (
        'public',
        'automation_event_subscriptions',
        'business',
        'rpc',
        true,
        false,
        true,
        true,
        true,
        'Tenant-scoped bindings between workflow triggers and automation runtime. Portal reads and modifies subscriptions exclusively through approved automation API/RPC contracts.'
    )

on conflict (table_schema, table_name)
do update set
    security_class = excluded.security_class,
    portal_access = excluded.portal_access,
    platform_admin_access = excluded.platform_admin_access,
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

do $$
declare
    r record;
    v_duplicate_count integer;
begin

    -- Every active registry entry must resolve to a real table.
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


    -- There must be exactly one active registry row per table.
    for r in
        select
            table_schema,
            table_name,
            count(*) as row_count
        from platform.security_table_registry
        where is_active = true
        group by
            table_schema,
            table_name
        having count(*) > 1
    loop

        raise exception
            '018 security hardening failed: duplicate active registry entries for %.% (% rows)',
            r.table_schema,
            r.table_name,
            r.row_count;

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
            platform_admin_access,
            direct_authenticated_access,
            rls_required,
            force_rls_required
        from platform.security_table_registry
        where is_active = true
    loop

        -- -------------------------------------------------
        -- security_class
        -- -------------------------------------------------

        if r.security_class not in ('business', 'backend') then

            raise exception
                '018 security hardening failed: %.% has invalid security_class=%; expected business or backend',
                r.table_schema,
                r.table_name,
                r.security_class;

        end if;


        -- -------------------------------------------------
        -- portal_access
        -- -------------------------------------------------

        if r.portal_access not in ('rpc', 'none') then

            raise exception
                '018 security hardening failed: %.% has invalid portal_access=%; expected rpc or none',
                r.table_schema,
                r.table_name,
                r.portal_access;

        end if;


        -- -------------------------------------------------
        -- direct authenticated access
        -- -------------------------------------------------

        if r.direct_authenticated_access is distinct from false then

            raise exception
                '018 security hardening failed: %.% permits direct authenticated access',
                r.table_schema,
                r.table_name;

        end if;


        -- -------------------------------------------------
        -- portal contract semantics
        -- -------------------------------------------------

        if r.security_class = 'backend'
           and r.portal_access = 'rpc'
           and r.platform_admin_access is null then

            raise exception
                '018 security hardening failed: backend-owned portal-exposed table %.% must explicitly define platform_admin_access',
                r.table_schema,
                r.table_name;

        end if;


        -- -------------------------------------------------
        -- RLS requirements
        -- -------------------------------------------------

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

        if (
            select force_rls_required
            from platform.security_table_registry
            where table_schema = r.table_schema
              and table_name = r.table_name
              and is_active = true
        ) = true then

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
-- Direct authenticated/anon table policies are removed.
--
-- Portal access is NOT implemented through direct-table
-- policies. Approved portal reads/writes are implemented
-- through API/RPC contracts.
--
-- RLS therefore acts as a defense-in-depth direct-table
-- boundary.
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
-- All discovered SECURITY DEFINER functions receive:
--
--     search_path = ''
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
          and c.relname = r.table_name
          and c.relkind in ('r', 'p');


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
'Central security classification for governed tables. security_class identifies business versus backend ownership. portal_access defines whether controlled portal access exists through approved API/RPC contracts. Direct authenticated table access is prohibited. 018 enforces RLS/FORCE RLS and removes legacy direct-table policies. 019 owns all privileges and grants/revokes.';


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