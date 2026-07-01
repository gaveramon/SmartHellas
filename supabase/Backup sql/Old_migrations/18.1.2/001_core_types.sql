-- =====================================================
-- REV18.2 PRODUCTION
-- 001_core_types.sql
-- CORE TYPES + GLOBAL FUNCTIONS
-- =====================================================

create extension if not exists pgcrypto;

-- =====================================================
-- USER ROLES
-- =====================================================

create type user_role as enum (
    'admin',
    'owner',
    'manager',
    'viewer'
);

-- =====================================================
-- SUBSCRIPTION PLANS
-- =====================================================

create type subscription_plan as enum (
    'startup_service',
    'managed_service'
);

-- =====================================================
-- API TOKEN SCOPES
-- =====================================================

create type api_token_scope as enum (
    'read',
    'write',
    'admin',
    'webhook'
);

-- =====================================================
-- INTEGRATION PROVIDERS
-- =====================================================

create type integration_provider as enum (
    'aqara',
    'ttlock',
    'shelly',
    'beds24',
    'stripe',
    'zoho',
    'generic'
);

-- =====================================================
-- UPDATED_AT TRIGGER FUNCTION
-- =====================================================

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- =====================================================
-- IMMUTABLE TABLE PROTECTION
-- =====================================================

create or replace function prevent_audit_update()
returns trigger
language plpgsql
as $$
begin
    raise exception 'audit_logs is immutable';
end;
$$;

-- =====================================================
-- ORGANIZATION MEMBERSHIP HELPER
-- =====================================================
-- Used by RLS policies throughout the platform

create or replace function is_org_member(
    p_org_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from memberships m
        where m.organization_id = p_org_id
        and m.user_id = auth.uid()
        and m.deleted_at is null
    );
$$;

-- =====================================================
-- ORGANIZATION ROLE HELPER
-- =====================================================
-- Used for admin/owner checks

create or replace function has_org_role(
    p_org_id uuid,
    p_roles user_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from memberships m
        where m.organization_id = p_org_id
        and m.user_id = auth.uid()
        and m.deleted_at is null
        and m.role = any(p_roles)
    );
$$;

-- =====================================================
-- AUDIT LOG HELPER
-- =====================================================
-- Centralized audit logging function
-- Used by edge functions and triggers

create or replace function create_audit_log(
    p_actor_user_id uuid,
    p_organization_id uuid,
    p_entity_type text,
    p_entity_id uuid,
    p_action text,
    p_old_values jsonb default null,
    p_new_values jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into audit_logs (
        actor_user_id,
        organization_id,
        entity_type,
        entity_id,
        action,
        old_values,
        new_values
    )
    values (
        p_actor_user_id,
        p_organization_id,
        p_entity_type,
        p_entity_id,
        p_action,
        p_old_values,
        p_new_values
    );

end;
$$;

-- =====================================================
-- SOFT DELETE HELPER
-- =====================================================
-- Standard helper for future expansion

create or replace function is_not_deleted(
    p_deleted_at timestamptz
)
returns boolean
language sql
immutable
as $$
    select p_deleted_at is null;
$$;

-- =====================================================
-- COMMENTS
-- =====================================================

comment on function set_updated_at is
'Automatically updates updated_at timestamp on row changes';

comment on function prevent_audit_update is
'Prevents updates or deletes on immutable audit tables';

comment on function is_org_member is
'Checks whether current authenticated user belongs to organization';

comment on function has_org_role is
'Checks whether current authenticated user has one of the supplied roles';

comment on function create_audit_log is
'Centralized audit log writer';

comment on function is_not_deleted is
'Helper for soft delete filtering';