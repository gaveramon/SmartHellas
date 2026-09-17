-- =====================================================
-- REV1 GREENFIELD BASELINE
-- 021_GRANT_MATRIX.SQL
-- =====================================================
--
-- Enterprise Security Grant Boundary
--
-- AUTHORITY
-- ----------
-- Enterprise Auditor
-- KGS-001 Principles
-- SECURITY RULES
-- SSOT RULES
--
-- PURPOSE
-- -------
-- Single source of truth for:
--
--   - schema privileges
--   - table privileges
--   - sequence privileges
--   - function EXECUTE privileges
--   - approved API/RPC exposure
--   - service_role backend access
--   - final privilege validation
--
--
-- SECURITY MODEL
-- --------------
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
-- IMPORTANT
-- ---------
--
-- 018b owns:
--   - RLS
--   - FORCE RLS
--   - SECURITY DEFINER hardening
--   - search_path hardening
--   - policy removal
--
-- 021 owns:
--   - GRANT
--   - REVOKE
--   - EXECUTE privileges
--   - schema privileges
--   - table privileges
--   - sequence privileges
--   - final privilege validation
--
-- The platform.security_table_registry is the authority
-- for registered table security classification.
--
-- 021 deliberately contains NO RLS policy creation.
-- =====================================================


begin;

-- =====================================================
-- 1. SECURITY ACTORS
-- =====================================================

create table if not exists platform.security_actor (
    id uuid primary key default gen_random_uuid(),

    actor_code text not null unique,

    actor_type text not null
        check (
            actor_type in (
                'portal',
                'platform',
                'integration',
                'worker',
                'system'
            )
        ),

    auth_role text
        check (
            auth_role is null
            or auth_role in (
                'anon',
                'authenticated',
                'service_role'
            )
        ),

    privilege_profile text not null
        check (
            privilege_profile in (
                'none',
                'api_only',
                'read',
                'append',
                'write',
                'full'
            )
        ),

    description text not null,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    constraint security_actor_code_format
        check (
            actor_code ~ '^[a-z][a-z0-9_]*$'
        )
);


-- =====================================================
-- 2. SECURITY ACTORS SEED
-- =====================================================

insert into platform.security_actor (
    actor_code,
    actor_type,
    auth_role,
    privilege_profile,
    description
)
values

(
    'anonymous',
    'system',
    'anon',
    'none',
    'Unauthenticated public request context. May reach explicitly public HTTP boundaries but has no direct database access.'
),

(
    'portal_user',
    'portal',
    'authenticated',
    'api_only',
    'Authenticated portal user. Business access is exclusively through authorized API/RPC contracts; no direct table access.'
),

(
    'platform_admin',
    'platform',
    'authenticated',
    'api_only',
    'Authenticated platform administrator. Platform capabilities are exposed through explicitly authorized API/RPC contracts; no direct table access.'
),

(
    'aqara_webhook',
    'integration',
    'service_role',
    'append',
    'Server-side Aqara integration webhook execution context. Provider-authenticated inbound events may append data through the integration boundary.'
),

(
    'shelly_webhook',
    'integration',
    'service_role',
    'append',
    'Server-side Shelly integration webhook execution context. Provider-authenticated inbound events may append data through the integration boundary.'
),

(
    'ttlock_webhook',
    'integration',
    'service_role',
    'append',
    'Server-side TTLock integration webhook execution context. Provider-authenticated inbound events may append data through the integration boundary.'
),

(
    'integration_worker',
    'worker',
    'service_role',
    'write',
    'Server-side integration worker context for asynchronous integration processing and maintenance.'
),

(
    'telemetry_worker',
    'worker',
    'service_role',
    'append',
    'Server-side telemetry processing context for raw telemetry ingestion and downstream telemetry processing.'
),

(
    'automation_worker',
    'worker',
    'service_role',
    'write',
    'Server-side automation execution context for backend automation and scheduled processing.'
),

(
    'system',
    'system',
    'service_role',
    'full',
    'Internal server-side system context for explicitly authorized technical and maintenance operations.'
)

on conflict (actor_code) do update
set
    actor_type       = excluded.actor_type,
    auth_role        = excluded.auth_role,
    privilege_profile = excluded.privilege_profile,
    description      = excluded.description,
    is_active        = true;



-- =====================================================
-- 3. SECURITY TABLE ACTOR
-- =====================================================
--
-- Defines which security actors are associated with
-- which registered security objects.
--
-- This table does NOT define PostgreSQL privileges.
-- The privilege profile is defined centrally on
-- platform.security_actor.privilege_profile.
--
-- Examples:
--
--   portal_user      -> api_only
--   platform_admin  -> api_only
--   telemetry_worker -> append
--   integration_worker -> write
--   system          -> full
--
-- The relationship below therefore answers:
--
--   "Which actor needs this security object?"
--
-- while security_actor answers:
--
--   "What privilege profile does this actor have?"
-- =====================================================

create table if not exists platform.security_table_actor (
    id uuid primary key default gen_random_uuid(),

    security_table_id uuid not null
        references platform.security_table_registry(id)
        on delete cascade,

    actor_id uuid not null
        references platform.security_actor(id)
        on delete cascade,

    description text not null,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    constraint security_table_actor_unique
        unique (
            security_table_id,
            actor_id
        )
);


comment on table platform.security_table_actor is
'Defines which security actors are associated with a registered security object. PostgreSQL privilege scope is determined centrally by platform.security_actor.privilege_profile and is not defined per table relationship.';


comment on column platform.security_table_actor.security_table_id is
'Reference to the security classification of the protected table or security object.';


comment on column platform.security_table_actor.actor_id is
'Reference to the security actor that requires an authorized relationship with this object. The actor privilege profile is defined on platform.security_actor.';


comment on column platform.security_table_actor.description is
'Human-readable explanation of why this actor requires access to the security object.';


comment on column platform.security_table_actor.is_active is
'Allows an actor-object relationship to be retired without deleting its security history.';


-- =====================================================
-- 4. SECURITY TABLE ACTOR SEED
-- =====================================================

insert into platform.security_table_actor (
    security_table_id,
    actor_id,
    description
)
select
    r.id,
    a.id,
    x.description
from (
values

-- =================================================
-- 000 PLATFORM / IDENTITY
-- =================================================

(
    'platform',
    'profiles',
    'portal_user',
    'Portal users require tenant-scoped access to their profile through approved API/RPC contracts.'
),
(
    'platform',
    'profiles',
    'platform_admin',
    'Platform administrators require controlled administrative access to user profile data through explicit platform RPC contracts.'
),
(
    'platform',
    'platform_admins',
    'platform_admin',
    'Platform administrator registry is required for controlled platform administration and authorization.'
),
(
    'platform',
    'platform_admins',
    'system',
    'Backend security functions require access to resolve and validate platform administrator status.'
),

-- =================================================
-- 000 PLATFORM / AUDIT + COMPLIANCE
-- =================================================

(
    'platform',
    'audit_log',
    'platform_admin',
    'Platform administrators require controlled audit visibility through explicit audit RPC contracts.'
),
(
    'platform',
    'audit_log',
    'system',
    'Backend services require access to append immutable platform audit records.'
),
(
    'platform',
    'constants',
    'system',
    'Platform services require access to system constants.'
),
(
    'platform',
    'soft_delete_log',
    'platform_admin',
    'Platform administrators require controlled visibility for recovery and deletion auditing.'
),
(
    'platform',
    'soft_delete_log',
    'system',
    'Backend services require access to maintain soft-delete audit records.'
),
(
    'platform',
    'error_log',
    'platform_admin',
    'Platform administrators require controlled diagnostic visibility through observability RPC.'
),
(
    'platform',
    'error_log',
    'system',
    'Backend services require access to record platform errors and diagnostics.'
),

-- =================================================
-- 000 PLATFORM / EVENT + EXECUTION
-- =================================================

(
    'platform',
    'internal_events',
    'system',
    'Internal platform workers require access to process internal platform events.'
),
(
    'platform',
    'event_log',
    'platform_admin',
    'Platform administrators require controlled observability access to platform event history.'
),
(
    'platform',
    'event_log',
    'system',
    'Backend services require access to write and process platform events.'
),
(
    'platform',
    'event_outbox',
    'system',
    'Backend workers require access to maintain the transactional event outbox.'
),
(
    'platform',
    'execution_supervisor',
    'platform_admin',
    'Platform administrators require controlled execution-health visibility.'
),
(
    'platform',
    'execution_supervisor',
    'system',
    'Platform services require access to maintain execution supervision state.'
),
(
    'platform',
    'operation_contexts',
    'system',
    'Backend workers require access to transient operation execution contexts.'
),
(
    'platform',
    'operation_log',
    'platform_admin',
    'Platform administrators require controlled operational execution visibility.'
),
(
    'platform',
    'operation_log',
    'system',
    'Backend services require access to record operation execution history.'
),
(
    'platform',
    'dead_letter_archive',
    'platform_admin',
    'Platform administrators require controlled visibility and recovery access for permanently failed platform work.'
),
(
    'platform',
    'dead_letter_archive',
    'system',
    'Backend workers require access to archive failed platform processing.'
),
(
    'platform',
    'retry_tasks',
    'platform_admin',
    'Platform administrators require controlled retry and operational visibility.'
),
(
    'platform',
    'retry_tasks',
    'system',
    'Backend workers require access to create and process retry tasks.'
),

-- =================================================
-- 000 PLATFORM / DEVICE EXECUTION
-- =================================================

(
    'platform',
    'device_commands',
    'platform_admin',
    'Platform administrators require controlled operational visibility and management of device commands.'
),
(
    'platform',
    'device_commands',
    'system',
    'Backend device execution services require access to process device commands.'
),
(
    'platform',
    'device_commands_dlq',
    'platform_admin',
    'Platform administrators require controlled visibility and recovery of failed device commands.'
),
(
    'platform',
    'device_commands_dlq',
    'system',
    'Backend device execution services require access to maintain the device command dead-letter queue.'
),

-- =================================================
-- 000 PLATFORM / INTEGRATION + WEBHOOK
-- =================================================

(
    'platform',
    'external_webhooks',
    'aqara_webhook',
    'Required for authenticated Aqara webhook ingestion through the external integration boundary.'
),
(
    'platform',
    'external_webhooks',
    'shelly_webhook',
    'Required for authenticated Shelly webhook ingestion through the external integration boundary.'
),
(
    'platform',
    'external_webhooks',
    'ttlock_webhook',
    'Required for authenticated TTLock webhook ingestion through the external integration boundary.'
),
(
    'platform',
    'external_webhooks',
    'integration_worker',
    'Integration workers require access to process and maintain external webhook records.'
),
(
    'platform',
    'external_webhooks',
    'platform_admin',
    'Platform administrators require controlled operational visibility into external webhook processing.'
),

(
    'platform',
    'webhook_provider_tenant_map',
    'aqara_webhook',
    'Aqara webhook processing requires provider-to-tenant resolution.'
),
(
    'platform',
    'webhook_provider_tenant_map',
    'shelly_webhook',
    'Shelly webhook processing requires provider-to-tenant resolution.'
),
(
    'platform',
    'webhook_provider_tenant_map',
    'ttlock_webhook',
    'TTLock webhook processing requires provider-to-tenant resolution.'
),
(
    'platform',
    'webhook_provider_tenant_map',
    'integration_worker',
    'Integration workers require provider-to-tenant mapping for asynchronous processing.'
),
(
    'platform',
    'webhook_provider_tenant_map',
    'platform_admin',
    'Platform administrators require controlled integration mapping administration.'
),

(
    'platform',
    'integration_queue',
    'aqara_webhook',
    'Aqara webhook processing may enqueue normalized integration events.'
),
(
    'platform',
    'integration_queue',
    'shelly_webhook',
    'Shelly webhook processing may enqueue normalized integration events.'
),
(
    'platform',
    'integration_queue',
    'ttlock_webhook',
    'TTLock webhook processing may enqueue normalized integration events.'
),
(
    'platform',
    'integration_queue',
    'integration_worker',
    'Integration workers require access to process the durable integration queue.'
),
(
    'platform',
    'integration_queue',
    'platform_admin',
    'Platform administrators require controlled operational visibility into integration delivery.'
),

-- =================================================
-- 000 PLATFORM / LOGISTICS
-- =================================================

(
    'platform',
    'shipment_dispatch_queue',
    'system',
    'Backend logistics workers require access to process shipment dispatch jobs.'
),
(
    'platform',
    'shipment_dispatch_queue',
    'platform_admin',
    'Platform administrators require controlled logistics operational visibility.'
),
(
    'platform',
    'shipment_tracking_events',
    'system',
    'Backend logistics workers require access to process shipment tracking events.'
),
(
    'platform',
    'shipment_tracking_events',
    'platform_admin',
    'Platform administrators require controlled logistics tracking visibility.'
),

-- =================================================
-- 000 PLATFORM / PAYMENT
-- =================================================

(
    'platform',
    'payment_intents',
    'portal_user',
    'Portal users require tenant-scoped payment intent information through approved payment RPC contracts.'
),
(
    'platform',
    'payment_intents',
    'platform_admin',
    'Platform administrators require controlled payment administration.'
),
(
    'platform',
    'payment_intents',
    'system',
    'Backend payment services require access to payment execution state.'
),
(
    'platform',
    'payment_events',
    'portal_user',
    'Portal users require tenant-scoped payment history through approved payment RPC contracts.'
),
(
    'platform',
    'payment_events',
    'platform_admin',
    'Platform administrators require controlled payment event visibility.'
),
(
    'platform',
    'payment_events',
    'system',
    'Backend payment services require access to immutable payment lifecycle events.'
),
(
    'platform',
    'payment_provider_refs',
    'platform_admin',
    'Platform administrators require controlled provider-reference administration.'
),
(
    'platform',
    'payment_provider_refs',
    'system',
    'Backend payment services require provider reference mappings.'
),

-- =================================================
-- 000 PLATFORM / SCHEDULING + NODES
-- =================================================

(
    'platform',
    'scheduled_jobs',
    'platform_admin',
    'Platform administrators require controlled scheduling administration.'
),
(
    'platform',
    'scheduled_jobs',
    'system',
    'Backend scheduler requires access to scheduled job definitions.'
),
(
    'platform',
    'job_executions',
    'platform_admin',
    'Platform administrators require controlled scheduled-job observability.'
),
(
    'platform',
    'job_executions',
    'system',
    'Backend scheduler requires access to execution history.'
),
(
    'platform',
    'system_nodes',
    'platform_admin',
    'Platform administrators require controlled platform node administration.'
),
(
    'platform',
    'system_nodes',
    'system',
    'Platform services require access to the canonical node registry.'
),
(
    'platform',
    'node_heartbeats',
    'platform_admin',
    'Platform administrators require controlled node liveness visibility.'
),
(
    'platform',
    'node_heartbeats',
    'system',
    'Platform nodes require access to record heartbeat state.'
),

-- =================================================
-- 000 PLATFORM / OBSERVABILITY
-- =================================================

(
    'platform',
    'query_performance_log',
    'platform_admin',
    'Platform administrators require controlled query performance visibility.'
),
(
    'platform',
    'query_performance_log',
    'system',
    'Backend observability services require access to query performance data.'
),
(
    'platform',
    'queue_processor_logs',
    'platform_admin',
    'Platform administrators require controlled queue processor observability.'
),
(
    'platform',
    'queue_processor_logs',
    'system',
    'Backend workers require access to queue processor logs.'
),
(
    'platform',
    'event_lag_monitor',
    'platform_admin',
    'Platform administrators require controlled event-lag visibility.'
),
(
    'platform',
    'event_lag_monitor',
    'system',
    'Backend observability services require access to event-lag monitoring.'
),
(
    'platform',
    'system_metrics',
    'platform_admin',
    'Platform administrators require controlled system metrics visibility.'
),
(
    'platform',
    'system_metrics',
    'system',
    'Backend monitoring requires access to raw platform metrics.'
),
(
    'platform',
    'system_metrics_aggregated',
    'platform_admin',
    'Platform administrators require controlled aggregated metrics visibility.'
),
(
    'platform',
    'system_metrics_aggregated',
    'system',
    'Backend monitoring requires access to aggregated system metrics.'
),
(
    'platform',
    'performance_snapshots',
    'platform_admin',
    'Platform administrators require controlled performance snapshot visibility.'
),
(
    'platform',
    'performance_snapshots',
    'system',
    'Backend monitoring requires access to performance snapshots.'
),
(
    'platform',
    'index_usage_stats',
    'platform_admin',
    'Platform administrators require controlled database performance visibility.'
),
(
    'platform',
    'index_usage_stats',
    'system',
    'Backend observability requires access to index usage telemetry.'
),
(
    'platform',
    'slow_query_flags',
    'platform_admin',
    'Platform administrators require controlled slow-query anomaly visibility.'
),
(
    'platform',
    'slow_query_flags',
    'system',
    'Backend observability requires access to slow-query anomaly records.'
),

-- =================================================
-- 000 PLATFORM / ARCHITECTURE CONTROL
-- =================================================

(
    'platform',
    'table_contracts',
    'platform_admin',
    'Platform administrators require controlled visibility into table contracts.'
),
(
    'platform',
    'table_contracts',
    'system',
    'Platform security and architecture services require access to table contracts.'
),
(
    'platform',
    'utility_function_registry',
    'platform_admin',
    'Platform administrators require controlled visibility into utility function dependencies.'
),
(
    'platform',
    'utility_function_registry',
    'system',
    'Backend architecture/security services require access to the utility function registry.'
),
(
    'platform',
    'schema_change_log',
    'platform_admin',
    'Platform administrators require controlled schema evolution visibility.'
),
(
    'platform',
    'schema_change_log',
    'system',
    'Migration and architecture services require access to schema change history.'
),
(
    'platform',
    'schema_migrations',
    'platform_admin',
    'Platform administrators require controlled migration registry visibility.'
),
(
    'platform',
    'schema_migrations',
    'system',
    'Migration infrastructure requires access to the applied migration registry.'
),
(
    'platform',
    'migration_execution_log',
    'platform_admin',
    'Platform administrators require controlled migration execution visibility.'
),
(
    'platform',
    'migration_execution_log',
    'system',
    'Migration infrastructure requires access to execution audit records.'
),
(
    'platform',
    'realtime_streams',
    'platform_admin',
    'Platform administrators require controlled realtime configuration administration.'
),
(
    'platform',
    'realtime_streams',
    'system',
    'Backend platform services require access to realtime stream configuration.'
),

-- =================================================
-- 002 CORE SAAS
-- =================================================

(
    'public',
    'tenants',
    'portal_user',
    'Portal users require tenant-scoped tenant information through approved SaaS API/RPC contracts.'
),
(
    'public',
    'tenants',
    'platform_admin',
    'Platform administrators require controlled tenant administration.'
),
(
    'public',
    'tenant_memberships',
    'portal_user',
    'Portal users require tenant membership and role context through approved API/RPC contracts.'
),
(
    'public',
    'tenant_memberships',
    'platform_admin',
    'Platform administrators require controlled tenant membership administration.'
),
(
    'public',
    'subscriptions',
    'portal_user',
    'Portal users require tenant-scoped subscription information through approved commerce/RPC contracts.'
),
(
    'public',
    'subscriptions',
    'platform_admin',
    'Platform administrators require controlled subscription administration.'
),
(
    'public',
    'service_accounts',
    'system',
    'Backend services require access to internal service-account state.'
),

-- =================================================
-- 003 CRM
-- =================================================

(
    'public',
    'crm_pipelines',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_pipelines',
    'platform_admin',
    'Platform administrators require controlled CRM pipeline administration.'
),
(
    'public',
    'crm_pipeline_stages',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_pipeline_stages',
    'platform_admin',
    'Platform administrators require controlled CRM pipeline-stage administration.'
),
(
    'public',
    'crm_campaigns',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_campaigns',
    'platform_admin',
    'Platform administrators require controlled CRM campaign administration.'
),
(
    'public',
    'crm_tags',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_tags',
    'platform_admin',
    'Platform administrators require controlled CRM tag administration.'
),
(
    'public',
    'crm_companies',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_companies',
    'platform_admin',
    'Platform administrators require controlled CRM company administration.'
),
(
    'public',
    'crm_contacts',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_contacts',
    'platform_admin',
    'Platform administrators require controlled CRM contact administration.'
),
(
    'public',
    'crm_leads',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_leads',
    'platform_admin',
    'Platform administrators require controlled CRM lead administration.'
),
(
    'public',
    'crm_contact_company',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_contact_company',
    'platform_admin',
    'Platform administrators require controlled CRM relationship administration.'
),
(
    'public',
    'crm_company_tenants',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_company_tenants',
    'platform_admin',
    'Platform administrators require controlled tenant-company relationship administration.'
),
(
    'public',
    'crm_contact_tenants',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_contact_tenants',
    'platform_admin',
    'Platform administrators require controlled tenant-contact relationship administration.'
),
(
    'public',
    'crm_opportunities',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_opportunities',
    'platform_admin',
    'Platform administrators require controlled CRM opportunity administration.'
),
(
    'public',
    'crm_tasks',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_tasks',
    'platform_admin',
    'Platform administrators require controlled CRM task administration.'
),
(
    'public',
    'crm_interactions',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_interactions',
    'platform_admin',
    'Platform administrators require controlled CRM interaction visibility.'
),
(
    'public',
    'crm_notes',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_notes',
    'platform_admin',
    'Platform administrators require controlled CRM note administration.'
),
(
    'public',
    'crm_tag_assignments',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_tag_assignments',
    'platform_admin',
    'Platform administrators require controlled CRM tag-assignment administration.'
),
(
    'public',
    'crm_lists',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_lists',
    'platform_admin',
    'Platform administrators require controlled CRM list administration.'
),
(
    'public',
    'crm_list_members',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_list_members',
    'platform_admin',
    'Platform administrators require controlled CRM list membership administration.'
),
(
    'public',
    'crm_custom_fields',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_custom_fields',
    'platform_admin',
    'Platform administrators require controlled CRM custom-field administration.'
),
(
    'public',
    'crm_custom_field_values',
    'portal_user',
    'CRM portal access is mediated through approved CRM API/RPC contracts.'
),
(
    'public',
    'crm_custom_field_values',
    'platform_admin',
    'Platform administrators require controlled CRM custom-field value administration.'
),

-- =================================================
-- 004 PROPERTY / DEVICE
-- =================================================

(
    'public',
    'properties',
    'portal_user',
    'Portal property management is mediated through approved devices/property API/RPC contracts.'
),
(
    'public',
    'properties',
    'platform_admin',
    'Platform administrators require controlled property administration.'
),
(
    'public',
    'rooms',
    'portal_user',
    'Portal room management is mediated through approved devices/property API/RPC contracts.'
),
(
    'public',
    'rooms',
    'platform_admin',
    'Platform administrators require controlled room administration.'
),
(
    'public',
    'device_categories',
    'portal_user',
    'Portal users require controlled read access to the device taxonomy through RPC.'
),
(
    'public',
    'device_categories',
    'platform_admin',
    'Platform administrators require device catalog administration.'
),
(
    'public',
    'devices',
    'portal_user',
    'Portal device management is mediated through approved device API/RPC contracts.'
),
(
    'public',
    'devices',
    'platform_admin',
    'Platform administrators require controlled device administration.'
),
(
    'public',
    'device_assignments',
    'portal_user',
    'Portal device assignment management is mediated through approved API/RPC contracts.'
),
(
    'public',
    'device_assignments',
    'platform_admin',
    'Platform administrators require controlled device assignment administration.'
),
(
    'public',
    'device_configurations',
    'portal_user',
    'Portal device configuration access is mediated through approved API/RPC contracts.'
),
(
    'public',
    'device_configurations',
    'platform_admin',
    'Platform administrators require controlled device configuration administration.'
),

-- =================================================
-- 005 BOOKING / LOCK
-- =================================================

(
    'public',
    'bookings',
    'portal_user',
    'Portal booking access is mediated through approved booking API/RPC contracts.'
),
(
    'public',
    'bookings',
    'platform_admin',
    'Platform administrators require controlled booking administration.'
),
(
    'public',
    'property_access_schedules',
    'portal_user',
    'Portal access schedules are managed through approved booking/lock RPC contracts.'
),
(
    'public',
    'property_access_schedules',
    'platform_admin',
    'Platform administrators require controlled access schedule administration.'
),
(
    'public',
    'booking_access',
    'portal_user',
    'Portal users require controlled booking access-window information through booking RPC.'
),
(
    'public',
    'booking_access',
    'platform_admin',
    'Platform administrators require controlled booking access administration.'
),
(
    'public',
    'access_policies',
    'portal_user',
    'Portal access-policy management is mediated through approved access RPC contracts.'
),
(
    'public',
    'access_policies',
    'platform_admin',
    'Platform administrators require controlled access-policy administration.'
),
(
    'public',
    'access_rules',
    'portal_user',
    'Portal access-rule management is mediated through approved access RPC contracts.'
),
(
    'public',
    'access_rules',
    'platform_admin',
    'Platform administrators require controlled access-rule administration.'
),
(
    'public',
    'lock_devices',
    'portal_user',
    'Portal lock management is mediated through approved lock API/RPC contracts.'
),
(
    'public',
    'lock_devices',
    'platform_admin',
    'Platform administrators require controlled lock administration.'
),
(
    'public',
    'access_credentials',
    'portal_user',
    'Portal users require controlled credential metadata through lock RPC; plaintext credentials are never directly exposed.'
),
(
    'public',
    'access_credentials',
    'platform_admin',
    'Platform administrators require controlled credential lifecycle administration without plaintext credential exposure.'
),

-- =================================================
-- 006 INTEGRATION
-- =================================================

(
    'public',
    'integration_providers',
    'portal_user',
    'Portal users require approved integration provider information through API/RPC.'
),
(
    'public',
    'integration_providers',
    'platform_admin',
    'Platform administrators require controlled provider catalog administration.'
),
(
    'public',
    'integration_capabilities',
    'portal_user',
    'Portal users require provider capability information through API/RPC.'
),
(
    'public',
    'integration_capabilities',
    'platform_admin',
    'Platform administrators require controlled integration capability administration.'
),
(
    'public',
    'integration_oauth_configs',
    'system',
    'Backend integration services require OAuth configuration metadata.'
),
(
    'public',
    'integration_oauth_configs',
    'platform_admin',
    'Platform administrators require controlled OAuth integration administration without direct table access.'
),
(
    'public',
    'integration_oauth_states',
    'system',
    'Backend OAuth lifecycle requires transient OAuth state access.'
),
(
    'public',
    'tenant_integrations',
    'portal_user',
    'Portal users require tenant integration management through approved integration API/RPC contracts.'
),
(
    'public',
    'tenant_integrations',
    'platform_admin',
    'Platform administrators require controlled tenant integration administration.'
),
(
    'public',
    'webhook_definitions',
    'portal_user',
    'Portal users require tenant webhook configuration through approved integration API/RPC contracts.'
),
(
    'public',
    'webhook_definitions',
    'platform_admin',
    'Platform administrators require controlled webhook configuration administration.'
),
(
    'public',
    'device_integration_map',
    'portal_user',
    'Portal users require controlled device-provider mapping information through integration API/RPC contracts.'
),
(
    'public',
    'device_integration_map',
    'platform_admin',
    'Platform administrators require controlled integration/device mapping administration.'
),
(
    'public',
    'device_integration_map',
    'aqara_webhook',
    'Aqara webhook processing requires resolution of external provider identity to the canonical SmartHellas device.'
),
(
    'public',
    'device_integration_map',
    'shelly_webhook',
    'Shelly webhook processing requires resolution of external provider identity to the canonical SmartHellas device.'
),
(
    'public',
    'device_integration_map',
    'ttlock_webhook',
    'TTLock webhook processing requires resolution of external provider identity to the canonical SmartHellas device.'
),
(
    'public',
    'device_integration_map',
    'integration_worker',
    'Integration workers require provider-to-device mappings for asynchronous processing.'
),

-- =================================================
-- 007 RAW TELEMETRY
-- =================================================

(
    'public',
    'device_telemetry_raw',
    'telemetry_worker',
    'Telemetry workers require backend write access for normalized raw device telemetry ingestion and processing.'
),
(
    'public',
    'device_telemetry_raw',
    'aqara_webhook',
    'Aqara telemetry events may enter the raw telemetry pipeline through the controlled integration boundary.'
),
(
    'public',
    'device_telemetry_raw',
    'shelly_webhook',
    'Shelly telemetry events may enter the raw telemetry pipeline through the controlled integration boundary.'
),
(
    'public',
    'device_telemetry_raw',
    'ttlock_webhook',
    'TTLock events may enter the raw event pipeline through the controlled integration boundary where applicable.'
),
(
    'public',
    'device_telemetry_raw',
    'platform_admin',
    'Platform administrators require controlled telemetry observability through approved RPC contracts.'
),

-- =================================================
-- 009 OPERATIONS
-- =================================================

(
    'public',
    'operation_templates',
    'portal_user',
    'Portal users require operation template information through approved operations API/RPC contracts.'
),
(
    'public',
    'operation_templates',
    'platform_admin',
    'Platform administrators require controlled operation template administration.'
),
(
    'public',
    'operation_workflows',
    'portal_user',
    'Portal users require workflow access through approved operations API/RPC contracts.'
),
(
    'public',
    'operation_workflows',
    'platform_admin',
    'Platform administrators require controlled workflow administration.'
),
(
    'public',
    'workflow_steps',
    'portal_user',
    'Portal users require workflow-step access through approved operations API/RPC contracts.'
),
(
    'public',
    'workflow_steps',
    'platform_admin',
    'Platform administrators require controlled workflow-step administration.'
),
(
    'public',
    'workflow_triggers',
    'portal_user',
    'Portal users require workflow-trigger access through approved operations API/RPC contracts.'
),
(
    'public',
    'workflow_triggers',
    'platform_admin',
    'Platform administrators require controlled workflow-trigger administration.'
),
(
    'public',
    'notification_templates',
    'portal_user',
    'Portal users require notification-template access through approved notification RPC contracts.'
),
(
    'public',
    'notification_templates',
    'platform_admin',
    'Platform administrators require controlled notification-template administration.'
),
(
    'public',
    'notification_preferences',
    'portal_user',
    'Portal users require notification preference management through approved notification RPC contracts.'
),
(
    'public',
    'notification_preferences',
    'platform_admin',
    'Platform administrators require controlled notification preference administration.'
),
(
    'public',
    'notification_queue',
    'system',
    'Backend notification workers require access to process notification delivery records.'
),
(
    'public',
    'notification_queue',
    'portal_user',
    'Portal users may inspect or control permitted notification queue state only through approved RPC contracts.'
),
(
    'public',
    'notification_queue',
    'platform_admin',
    'Platform administrators require controlled notification operations access.'
),
(
    'public',
    'notification_history',
    'system',
    'Backend notification workers require access to maintain notification delivery history.'
),
(
    'public',
    'notification_history',
    'portal_user',
    'Portal users may read permitted tenant notification history through approved RPC contracts.'
),
(
    'public',
    'notification_history',
    'platform_admin',
    'Platform administrators require controlled notification history visibility.'
),
(
    'public',
    'support_tickets',
    'portal_user',
    'Portal users require tenant support ticket access through approved support RPC contracts.'
),
(
    'public',
    'support_tickets',
    'platform_admin',
    'Platform administrators require controlled support ticket administration.'
),
(
    'public',
    'support_messages',
    'portal_user',
    'Portal users require tenant support message access through approved support RPC contracts.'
),
(
    'public',
    'support_messages',
    'platform_admin',
    'Platform administrators require controlled support message administration.'
),

-- =================================================
-- 010 PRECONFIG
-- =================================================

(
    'public',
    'device_bundles',
    'portal_user',
    'Portal users require bundle catalog access through approved preconfiguration RPC.'
),
(
    'public',
    'device_bundles',
    'platform_admin',
    'Platform administrators require controlled bundle catalog administration.'
),
(
    'public',
    'bundle_devices',
    'portal_user',
    'Portal users require bundle component information through approved preconfiguration RPC.'
),
(
    'public',
    'bundle_devices',
    'platform_admin',
    'Platform administrators require controlled bundle component administration.'
),
(
    'public',
    'onboarding_blueprints',
    'portal_user',
    'Portal users require onboarding blueprint information through approved preconfiguration RPC.'
),
(
    'public',
    'onboarding_blueprints',
    'platform_admin',
    'Platform administrators require controlled onboarding blueprint administration.'
),
(
    'public',
    'onboarding_blueprint_steps',
    'portal_user',
    'Portal users require onboarding blueprint step information through approved preconfiguration RPC.'
),
(
    'public',
    'onboarding_blueprint_steps',
    'platform_admin',
    'Platform administrators require controlled onboarding blueprint step administration.'
),
(
    'public',
    'preconfig_templates',
    'portal_user',
    'Portal users require preconfiguration template access through approved preconfiguration RPC.'
),
(
    'public',
    'preconfig_templates',
    'platform_admin',
    'Platform administrators require controlled preconfiguration template administration.'
),
(
    'public',
    'preconfig_device_map',
    'portal_user',
    'Portal users require preconfiguration device mapping through approved preconfiguration RPC.'
),
(
    'public',
    'preconfig_device_map',
    'platform_admin',
    'Platform administrators require controlled preconfiguration device mapping administration.'
),

-- =================================================
-- 011 LOGISTICS
-- =================================================

(
    'public',
    'shipping_carriers',
    'portal_user',
    'Portal users require shipping carrier information through approved logistics RPC.'
),
(
    'public',
    'shipping_carriers',
    'platform_admin',
    'Platform administrators require controlled shipping carrier administration.'
),
(
    'public',
    'shipping_label_templates',
    'portal_user',
    'Portal users require shipping label configuration through approved logistics RPC.'
),
(
    'public',
    'shipping_label_templates',
    'platform_admin',
    'Platform administrators require controlled shipping label template administration.'
),
(
    'public',
    'logistics_templates',
    'portal_user',
    'Tenant users require logistics template access through approved logistics RPC.'
),
(
    'public',
    'warehouses',
    'portal_user',
    'Tenant users require warehouse access through approved logistics RPC.'
),
(
    'public',
    'shipping_rules',
    'portal_user',
    'Tenant users require shipping rule access through approved logistics RPC.'
),
(
    'public',
    'package_definitions',
    'portal_user',
    'Tenant users require package definition access through approved logistics RPC.'
),
(
    'public',
    'fulfilment_orders',
    'portal_user',
    'Tenant users require fulfilment order access through approved logistics RPC.'
),

-- =================================================
-- 012 COMMERCE
-- =================================================

(
    'public',
    'product_plans',
    'portal_user',
    'Portal users require active commercial plan information through approved commerce RPC.'
),
(
    'public',
    'product_plans',
    'platform_admin',
    'Platform administrators require controlled commercial plan administration.'
),
(
    'public',
    'plan_pricing',
    'portal_user',
    'Portal users require current plan pricing through approved commerce RPC.'
),
(
    'public',
    'plan_pricing',
    'platform_admin',
    'Platform administrators require controlled pricing administration.'
),
(
    'public',
    'feature_entitlements',
    'portal_user',
    'Portal users require effective feature entitlement information through approved commerce RPC.'
),
(
    'public',
    'feature_entitlements',
    'platform_admin',
    'Platform administrators require controlled feature entitlement administration.'
),
(
    'public',
    'upsell_rules',
    'portal_user',
    'Portal users require applicable upsell rules through approved commerce RPC.'
),
(
    'public',
    'upsell_rules',
    'platform_admin',
    'Platform administrators require controlled upsell rule administration.'
),

-- =================================================
-- 013 SERVICE PORTAL
-- =================================================

(
    'public',
    'tenant_portal_settings',
    'portal_user',
    'Portal users require tenant portal settings through approved portal RPC.'
),
(
    'public',
    'tenant_portal_settings',
    'platform_admin',
    'Platform administrators require controlled portal configuration administration.'
),
(
    'public',
    'dashboard_configs',
    'portal_user',
    'Portal users require dashboard configuration through approved portal RPC.'
),
(
    'public',
    'dashboard_configs',
    'platform_admin',
    'Platform administrators require controlled dashboard administration.'
),
(
    'public',
    'portal_user_preferences',
    'portal_user',
    'Portal users require their own portal preference management through approved RPC.'
),
(
    'public',
    'portal_user_preferences',
    'platform_admin',
    'Platform administrators require controlled support-level access to portal preferences.'
),
(
    'public',
    'portal_feature_flags',
    'portal_user',
    'Portal users require effective UI feature flags through approved portal RPC.'
),
(
    'public',
    'portal_feature_flags',
    'platform_admin',
    'Platform administrators require controlled tenant feature-flag administration.'
),

-- =================================================
-- 014 ONBOARDING
-- =================================================

(
    'public',
    'onboarding_sessions',
    'portal_user',
    'Portal users require onboarding session access through approved onboarding RPC.'
),
(
    'public',
    'onboarding_sessions',
    'platform_admin',
    'Platform administrators require controlled onboarding administration.'
),
(
    'public',
    'onboarding_step_state',
    'portal_user',
    'Portal users require onboarding step progress through approved onboarding RPC.'
),
(
    'public',
    'onboarding_step_state',
    'platform_admin',
    'Platform administrators require controlled onboarding progress administration.'
),
(
    'public',
    'onboarding_room_mapping',
    'portal_user',
    'Portal users require onboarding room mapping through approved onboarding RPC.'
),
(
    'public',
    'onboarding_room_mapping',
    'platform_admin',
    'Platform administrators require controlled onboarding room mapping administration.'
),
(
    'public',
    'onboarding_device_mapping',
    'portal_user',
    'Portal users require onboarding device mapping through approved onboarding RPC.'
),
(
    'public',
    'onboarding_device_mapping',
    'platform_admin',
    'Platform administrators require controlled onboarding device mapping administration.'
),
(
    'public',
    'onboarding_checklist',
    'portal_user',
    'Portal users require onboarding checklist access through approved onboarding RPC.'
),
(
    'public',
    'onboarding_checklist',
    'platform_admin',
    'Platform administrators require controlled onboarding checklist administration.'
),
(
    'public',
    'onboarding_notes',
    'portal_user',
    'Portal users require onboarding notes through approved onboarding RPC.'
),
(
    'public',
    'onboarding_notes',
    'platform_admin',
    'Platform administrators require controlled onboarding note access.'
),
(
    'public',
    'onboarding_lifecycle',
    'portal_user',
    'Portal users require onboarding lifecycle information through approved onboarding RPC.'
),
(
    'public',
    'onboarding_lifecycle',
    'platform_admin',
    'Platform administrators require controlled onboarding lifecycle administration.'
),
(
    'public',
    'onboarding_lifecycle_transitions',
    'portal_user',
    'Portal users require controlled lifecycle transition history through approved onboarding RPC.'
),
(
    'public',
    'onboarding_lifecycle_transitions',
    'platform_admin',
    'Platform administrators require controlled onboarding lifecycle audit visibility.'
),

-- =================================================
-- 015 OPTIMIZATION
-- =================================================

(
    'public',
    'optimization_rules',
    'portal_user',
    'Portal users require optimization rule management through approved optimization RPC.'
),
(
    'public',
    'optimization_rules',
    'platform_admin',
    'Platform administrators require controlled optimization rule administration.'
),
(
    'public',
    'insight_events',
    'portal_user',
    'Portal users require tenant-scoped insight visibility through approved optimization RPC.'
),
(
    'public',
    'insight_events',
    'platform_admin',
    'Platform administrators require controlled insight observability.'
),
(
    'public',
    'insight_events',
    'system',
    'Backend optimization processing generates and maintains insight events.'
),
(
    'public',
    'optimization_recommendations',
    'portal_user',
    'Portal users require recommendation access and permitted actions through optimization RPC.'
),
(
    'public',
    'optimization_recommendations',
    'platform_admin',
    'Platform administrators require controlled recommendation administration.'
),
(
    'public',
    'optimization_recommendations',
    'system',
    'Backend optimization processing generates and maintains recommendations.'
),
(
    'public',
    'device_usage_scores',
    'portal_user',
    'Portal users require device usage analytics through approved optimization RPC.'
),
(
    'public',
    'device_usage_scores',
    'platform_admin',
    'Platform administrators require controlled optimization analytics visibility.'
),
(
    'public',
    'device_usage_scores',
    'system',
    'Backend optimization processing generates device usage scores.'
),
(
    'public',
    'energy_profiles',
    'portal_user',
    'Portal users require property energy analytics through approved optimization RPC.'
),
(
    'public',
    'energy_profiles',
    'platform_admin',
    'Platform administrators require controlled energy analytics visibility.'
),
(
    'public',
    'energy_profiles',
    'system',
    'Backend optimization processing generates energy profiles.'
),

-- =================================================
-- 016 CUSTOMER PROPOSAL / MONETIZATION
-- =================================================

(
    'public',
    'customer_proposals',
    'portal_user',
    'Portal users require tenant-scoped proposal access through approved monetization RPC.'
),
(
    'public',
    'customer_proposals',
    'platform_admin',
    'Platform administrators require controlled proposal administration.'
),
(
    'public',
    'proposal_items',
    'portal_user',
    'Portal users require proposal line-item access through approved monetization RPC.'
),
(
    'public',
    'proposal_items',
    'platform_admin',
    'Platform administrators require controlled proposal item administration.'
),
(
    'public',
    'monetization_packages',
    'portal_user',
    'Portal users require commercial package information through approved monetization RPC.'
),
(
    'public',
    'monetization_packages',
    'platform_admin',
    'Platform administrators require controlled commercial package administration.'
),
(
    'public',
    'upsell_campaigns',
    'portal_user',
    'Portal users require applicable upsell campaign information through approved monetization RPC.'
),
(
    'public',
    'upsell_campaigns',
    'platform_admin',
    'Platform administrators require controlled upsell campaign administration.'
),
(
    'public',
    'conversion_events',
    'portal_user',
    'Portal users require permitted tenant-scoped conversion event visibility through monetization RPC.'
),
(
    'public',
    'conversion_events',
    'platform_admin',
    'Platform administrators require controlled conversion event visibility.'
),
(
    'public',
    'conversion_events',
    'system',
    'Backend services generate append-only conversion events.'
),
(
    'public',
    'conversion_scores',
    'portal_user',
    'Portal users require tenant-scoped conversion score visibility through monetization RPC.'
),
(
    'public',
    'conversion_scores',
    'platform_admin',
    'Platform administrators require controlled conversion analytics visibility.'
),
(
    'public',
    'conversion_scores',
    'system',
    'Backend services calculate and maintain conversion scores.'
),
(
    'public',
    'service_activation_state',
    'platform_admin',
    'Platform administrators require controlled service activation observability.'
),
(
    'public',
    'service_activation_state',
    'system',
    'Backend workers maintain the service activation projection.'
),

-- =================================================
-- 017 AUTOMATION
-- =================================================

(
    'public',
    'automation_runs',
    'portal_user',
    'Portal users require tenant-scoped automation run visibility through approved automation RPC.'
),
(
    'public',
    'automation_runs',
    'platform_admin',
    'Platform administrators require controlled automation run visibility.'
),
(
    'public',
    'automation_runs',
    'automation_worker',
    'Automation workers require access to create and maintain automation runtime executions.'
),
(
    'public',
    'automation_run_steps',
    'portal_user',
    'Portal users require tenant-scoped automation step visibility through approved automation RPC.'
),
(
    'public',
    'automation_run_steps',
    'platform_admin',
    'Platform administrators require controlled automation step visibility.'
),
(
    'public',
    'automation_run_steps',
    'automation_worker',
    'Automation workers require access to maintain automation step execution state.'
),
(
    'public',
    'automation_event_subscriptions',
    'portal_user',
    'Portal users require automation subscription management through approved automation RPC.'
),
(
    'public',
    'automation_event_subscriptions',
    'platform_admin',
    'Platform administrators require controlled automation subscription administration.'
),
(
    'public',
    'automation_event_subscriptions',
    'automation_worker',
    'Automation workers require access to resolve and process automation event subscriptions.'
)

) as x (
    table_schema,
    table_name,
    actor_code,
    description
)

join platform.security_table_registry r
    on r.table_schema = x.table_schema
   and r.table_name = x.table_name

join platform.security_actor a
    on a.actor_code = x.actor_code

where r.is_active = true
  and a.is_active = true

on conflict (security_table_id, actor_id)
do update set
    description = excluded.description,
    is_active = true;

-- =====================================================
-- 5. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (
    migration_name,
    version,
    rollback_available
)
values (
    '021_grant_matrix_actors',
    'REV1.GRANT.MATRIX.ACTORS
    false
)
on conflict (version) do nothing;


-- =====================================================
-- END 021 GRANT MATRIX
-- =====================================================