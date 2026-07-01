-- =====================================================
-- 001 CORE TYPES (SINGLE SOURCE OF TRUTH)
-- SYSTEM-WIDE CONSISTENT TYPE LAYER
-- NO BUSINESS LOGIC / NO TABLES / NO STATE
-- =====================================================

-- =====================================================
-- 1. TENANCY & PLATFORM CORE
-- =====================================================

create type tenant_status as enum (
    'active',
    'suspended',
    'deleted'
);

-- =====================================================
-- 2. USER & ACCESS ROLES
-- =====================================================

create type user_role as enum (
    'owner',
    'admin',
    'manager',
    'support',
    'viewer'
);

-- =====================================================
-- 4. SUBSCRIPTION / COMMERCE STATES
-- =====================================================

create type subscription_status as enum (
    'trial',
    'pending',
    'active',
    'past_due',
    'suspended',
    'cancelled'
);

create type subscription_tier as enum (
    'basic',
    'pro',
    'enterprise'
);

-- payment transaction lifecycle (commerce invoices / charges)
create type payment_status as enum (
    'pending',
    'authorized',
    'paid',
    'failed',
    'refunded',
    'cancelled'
);

-- =====================================================
-- 5. PROPERTY & STRUCTURE TYPES
-- =====================================================

create type property_type as enum (
    'apartment',
    'house',
    'villa',
    'hotel'
);

create type room_type as enum (
    'living_room',
    'bedroom',
    'bathroom',
    'kitchen',
    'hallway',
    'outdoor',
    'office',
    'storage'
);

-- =====================================================
-- 6. DEVICE MODEL TYPES
-- =====================================================

create type device_category as enum (
    'sensor',
    'switch',
    'lock',
    'thermostat',
    'ir_controller',
    'gateway',
    'other'
);

create type device_protocol as enum (
    'zigbee',
    'wifi',
    'bluetooth',
    'infrared',
    'ethernet'
);

-- =====================================================
-- 7. ACCESS CONTROL TYPES
-- =====================================================

create type access_type as enum (
    'guest',
    'owner',
    'temporary',
    'emergency',
    'scheduled'
);

-- =====================================================
-- 7B. BOOKING DOMAIN TYPES
-- =====================================================

create type booking_status as enum (
    'pending',
    'confirmed',
    'checked_in',
    'checked_out',
    'cancelled'
);

create type access_rule_type as enum (
    'check_in_window',
    'checkout_window',
    'override',
    'emergency_access'
);

create type access_credential_status as enum (
    'pending',
    'active',
    'revoked',
    'expired',
    'failed'
);

-- =====================================================
-- 8. ONBOARDING TYPES
-- =====================================================

create type onboarding_status as enum (
    'not_started',
    'in_progress',
    'waiting_user',
    'completed',
    'blocked'
);

create type onboarding_step_type as enum (
    'wifi_setup',
    'device_assignment',
    'room_mapping',
    'integration_link',
    'testing',
    'finalization'
);

create type onboarding_step_status as enum (
    'pending',
    'in_progress',
    'completed',
    'skipped',
    'blocked'
);

-- =====================================================
-- 9. AUTOMATION & WORKFLOW TYPES
-- =====================================================

create type automation_trigger_type as enum (
    'booking_created',
    'booking_started',
    'booking_ended',
    'device_added',
    'manual_trigger',
    'schedule_based'
);

create type automation_action_type as enum (
    'send_notification',
    'update_device',
    'generate_code',
    'update_booking',
    'run_optimization',
    'trigger_webhook'
);

create type operation_context_type as enum (
    'booking_event',
    'device_event',
    'manual_trigger'
);

-- =====================================================
-- 10. INTEGRATION PROVIDERS
-- =====================================================

-- NOT USED, See 005_integration_engine_rev19.sql


-- =====================================================
-- 11. SUPPORT / SERVICE STATES
-- =====================================================

create type support_ticket_status as enum (
    'open',
    'in_progress',
    'waiting_customer',
    'resolved',
    'closed'
);

create type priority_level as enum (
    'low',
    'normal',
    'high',
    'urgent'
);

create type support_sender_type as enum (
    'user',
    'support',
    'system'
);

-- =====================================================
-- 12. OPTIMIZATION TYPES
-- =====================================================

create type optimization_category as enum (
    'energy',
    'security',
    'cost',
    'efficiency',
    'performance',
    'user_experience'
);

create type optimization_recommendation_type as enum (
    'reduce_energy',
    'improve_security',
    'optimize_devices',
    'reduce_cost',
    'improve_efficiency',
    'improve_performance',
    'improve_user_experience'
);

create type recommendation_severity as enum (
    'low',
    'medium',
    'high'
);

create type recommendation_status as enum (
    'open',
    'acknowledged',
    'dismissed',
    'converted_to_proposal'
);

create type device_usage_score_category as enum (
    'efficiency',
    'usage',
    'energy',
    'reliability'
);

create type optimization_insight_type as enum (
    'anomaly_detected',
    'optimization_opportunity',
    'usage_pattern'
);

-- =====================================================
-- 13. MONETIZATION TYPES
-- =====================================================

create type upsell_trigger as enum (
    'onboarding_completed',
    'device_added',
    'booking_created',
    'usage_threshold',
    'manual_review'
);

create type service_type as enum (
    'managed_service',
    'auto_door_code',
    'energy_optimization',
    'security_monitoring'
);

create type proposal_status as enum (
    'draft',
    'presented',
    'accepted',
    'rejected'
);

create type proposal_item_type as enum (
    'device_package',
    'subscription',
    'service'
);

create type package_type as enum (
    'hardware',
    'service',
    'hybrid'
);

create type service_activation_status as enum (
    'inactive',
    'pending',
    'active',
    'suspended'
);

create type conversion_event_type as enum (
    'view_proposal',
    'add_item',
    'remove_item',
    'checkout_start',
    'checkout_complete',
    'upsell_clicked',
    'proposal_accepted',
    'proposal_rejected'
);

create type fulfilment_status as enum (
    'draft',
    'ready_to_ship',
    'dispatched',
    'delivered',
    'cancelled'
);

-- =====================================================
-- ENUM EXPANSION RULES (REV19 SSOT)
-- =====================================================
-- 1. never remove or rename labels after baseline deploy
-- 2. append only: alter type ... add value if not exists 'label';
-- 3. enum values are domain-local — never compare across enum types
-- 4. platform execution states remain text in 000 (by architecture)
-- 5. use domain-specific status enums; no global lifecycle enum

-- =====================================================
-- END 001 CORE TYPES (SSOT COMPLETE)
-- =====================================================