-- =====================================================
-- 001 CORE TYPES (CLEANED + 000 SEPARATION ALIGNED)
-- BUSINESS DOMAIN ONLY
-- =====================================================

-- =====================================================
-- 1. TENANT + USER DOMAIN TYPES
-- =====================================================

create type tenant_status as enum (
    'active',
    'suspended',
    'deleted'
);

create type user_role as enum (
    'owner',
    'admin',
    'manager',
    'support',
    'guest'
);

-- =====================================================
-- 2. PROPERTY DOMAIN TYPES
-- =====================================================

create type property_type as enum (
    'apartment',
    'house',
    'villa',
    'studio',
    'hotel_room'
);

create type room_type as enum (
    'bedroom',
    'living_room',
    'bathroom',
    'kitchen',
    'hallway',
    'outdoor',
    'office'
);

-- =====================================================
-- 3. DEVICE DOMAIN TYPES (SMART HOME CORE)
-- =====================================================

create type device_category as enum (
    'sensor',
    'climate',
    'lock',
    'camera',
    'lighting',
    'energy',
    'ir_controller',
    'smart_plug',
    'gateway'
);

create type device_protocol as enum (
    'zigbee',
    'wifi',
    'bluetooth',
    'thread',
    'infrared',
    'z_wave'
);

create type device_status as enum (
    'unpaired',
    'paired',
    'active',
    'inactive',
    'error'
);

-- =====================================================
-- 4. BOOKING DOMAIN TYPES
-- =====================================================

create type booking_status as enum (
    'pending',
    'confirmed',
    'checked_in',
    'checked_out',
    'cancelled'
);

create type access_type as enum (
    'manual',
    'smart_lock',
    'temporary_code',
    'app_access'
);

-- =====================================================
-- 5. ONBOARDING DOMAIN TYPES (BUSINESS FLOW ONLY)
-- =====================================================

create type onboarding_status as enum (
    'not_started',
    'in_progress',
    'waiting_user',
    'completed'
);

create type onboarding_step_type as enum (
    'wifi_setup',
    'device_installation',
    'room_mapping',
    'integration_link',
    'testing'
);

-- =====================================================
-- 6. AUTOMATION DOMAIN TYPES
-- =====================================================

create type automation_trigger_type as enum (
    'booking_event',
    'time_based',
    'device_event',
    'manual'
);

create type automation_action_type as enum (
    'send_message',
    'unlock_door',
    'set_temperature',
    'toggle_device',
    'generate_access_code'
);

-- =====================================================
-- 7. INTEGRATION DOMAIN TYPES
-- =====================================================

create type integration_provider as enum (
    'aqara',
    'ttlock',
    'google_home',
    'home_assistant',
    'stripe',
    'vivawallet'
);

create type integration_status as enum (
    'connected',
    'disconnected',
    'error',
    'pending'
);

-- =====================================================
-- 8. COMMERCE DOMAIN TYPES
-- =====================================================

create type subscription_tier as enum (
    'basic',
    'pro',
    'enterprise'
);

create type payment_status as enum (
    'pending',
    'paid',
    'failed',
    'refunded'
);

-- =====================================================
-- END 001 CORE TYPES (CLEAN DOMAIN LAYER ONLY)
-- =====================================================