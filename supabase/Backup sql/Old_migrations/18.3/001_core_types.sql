-- =====================================================
-- REV18.2.1 PRODUCTION PATCH
-- 001_core_types.sql
-- CORE TYPES (FIXED)
-- =====================================================

create extension if not exists pgcrypto;
create extension if not exists citext;

create type user_role as enum (
  'admin',
  'owner',
  'manager',
  'viewer'
);

create type property_role as enum (
  'owner',
  'manager',
  'operator',
  'viewer'
);

create type subscription_plan as enum (
  'startup_service',
  'managed_service'
);

create type subscription_status as enum (
  'trialing',
  'active',
  'past_due',
  'cancelled',
  'expired'
);

create type billing_status as enum (
  'pending',
  'paid',
  'failed',
  'refunded',
  'void'
);

create type integration_provider as enum (
  'aqara',
  'ttlock',
  'shelly',
  'beds24',
  'stripe',
  'zoho',
  'generic'
);

create type actor_type as enum (
  'user',
  'system',
  'ai',
  'service'
);

create type operation_status as enum (
  'pending',
  'queued',
  'running',
  'succeeded',
  'failed',
  'cancelled'
);

create type device_status as enum (
  'online',
  'offline',
  'unknown'
);

create type reservation_source as enum (
  'airbnb',
  'booking_com',
  'beds24',
  'manual'
);

create type reservation_status as enum (
  'confirmed',
  'cancelled',
  'checked_in',
  'checked_out',
  'blocked'
);

create type lock_access_status as enum (
  'pending',
  'active',
  'expired',
  'revoked',
  'failed'
);

create type sync_status as enum (
  'pending',
  'running',
  'succeeded',
  'failed',
  'retrying',
  'cancelled'
);

create type integration_health_status as enum (
  'healthy',
  'warning',
  'degraded',
  'offline'
);

create type webhook_status as enum (
  'received',
  'processed',
  'failed'
);

create type operation_action_type as enum (
  'device_command',
  'device_state_change',
  'automation_change',
  'reservation_change',
  'lock_access_change',
  'integration_sync',
  'billing_change',
  'admin_action'
);