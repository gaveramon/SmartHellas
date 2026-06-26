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
-- 3. GLOBAL LIFECYCLE STATES (CRITICAL FIX)
-- =====================================================

create type lifecycle_status as enum (
    'draft',
    'pending',
    'active',
    'paused',
    'completed',
    'failed',
    'cancelled',
    'archived'
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

-- legacy alias compatibility (IMPORTANT for migration safety)
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
    'hotel',
    'airbnb_unit'
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
    'camera',
    'lock',
    'thermostat',
    'ir_controller',
    'gateway',
    'other'
);

create type device_protocol as enum (
    'zigbee',
    'zwave',
    'wifi',
    'bluetooth',
    'rf_433',
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

-- =====================================================
-- 10. INTEGRATION PROVIDERS
-- =====================================================

create type integration_provider as enum (
    'stripe',
    'vivawallet',
    'aqara',
    'ttlock',
    'home_assistant',
    'google_home',
    'mqtt',
    'custom_api'
);

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

-- =====================================================
-- 12. OPTIMIZATION TYPES
-- =====================================================

create type optimization_category as enum (
    'energy',
    'security',
    'cost',
    'performance',
    'user_experience'
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

-- =====================================================
-- END 001 CORE TYPES (SSOT COMPLETE)
-- =====================================================