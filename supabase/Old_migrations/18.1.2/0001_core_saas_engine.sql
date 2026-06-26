-- =====================================================
-- REV18.1.1 PRODUCTION MASTER
-- DEEL 1 - CORE SAAS ENGINE
-- =====================================================

create extension if not exists pgcrypto;

-- =====================================================
-- ENUMS
-- =====================================================

create type user_role as enum (
  'super_admin',
  'admin',
  'owner',
  'manager',
  'viewer'
);

create type subscription_plan as enum (
  'startup_service',
  'managed_service'
);

create type api_token_scope as enum (
  'read',
  'write',
  'admin',
  'webhook'
);

-- =====================================================
-- UPDATED_AT TRIGGER FUNCTION
-- =====================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =====================================================
-- SOFT DELETE HELPER VIEW RULE (NOT FUNCTIONAL RLS ONLY)
-- =====================================================
-- All queries must filter deleted_at is null via RLS policies

-- =====================================================
-- ORGANIZATIONS
-- =====================================================

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text,
  timezone text not null default 'UTC',
  language text not null default 'en',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create trigger trg_organizations_updated_at
before update on organizations
for each row execute function set_updated_at();

-- =====================================================
-- USERS PROFILE (Supabase auth.users extension)
-- =====================================================

create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create trigger trg_user_profiles_updated_at
before update on user_profiles
for each row execute function set_updated_at();

-- =====================================================
-- MEMBERSHIPS (RBAC CORE)
-- =====================================================

create table memberships (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,

  role user_role not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (organization_id, user_id)
);

create index idx_memberships_org on memberships(organization_id);
create index idx_memberships_user on memberships(user_id);

create trigger trg_memberships_updated_at
before update on memberships
for each row execute function set_updated_at();

-- =====================================================
-- FEATURE FLAGS (SAAS CONTROL LAYER)
-- =====================================================

create table feature_flags (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id) on delete cascade,

  key text not null,
  enabled boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (organization_id, key)
);

create index idx_feature_flags_org on feature_flags(organization_id);

create trigger trg_feature_flags_updated_at
before update on feature_flags
for each row execute function set_updated_at();

-- =====================================================
-- ORGANIZATION SETTINGS
-- =====================================================

create table organization_settings (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  check_in_time time not null default '15:00',
  check_out_time time not null default '11:00',

  timezone text not null default 'UTC',
  language text not null default 'en',

  notification_email boolean not null default true,
  notification_sms boolean not null default false,
  notification_push boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid,

  unique (organization_id)
);

create index idx_org_settings_org on organization_settings(organization_id);

create trigger trg_org_settings_updated_at
before update on organization_settings
for each row execute function set_updated_at();

-- =====================================================
-- API TOKENS (INTEGRATION LAYER FOUNDATION)
-- =====================================================

create table api_tokens (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  name text not null,
  token_hash text not null,
  scope api_token_scope not null,

  last_used_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_api_tokens_org on api_tokens(organization_id);

create trigger trg_api_tokens_updated_at
before update on api_tokens
for each row execute function set_updated_at();

-- =====================================================
-- AUDIT LOGS (IMMUTABLE CORE)
-- =====================================================

create table audit_logs (
  id uuid primary key default gen_random_uuid(),

  actor_user_id uuid references auth.users(id),
  organization_id uuid references organizations(id),

  entity_type text not null,
  entity_id uuid not null,

  action text not null,

  old_values jsonb,
  new_values jsonb,

  ip_address inet,
  user_agent text,

  created_at timestamptz not null default now()
);

create index idx_audit_org on audit_logs(organization_id);
create index idx_audit_entity on audit_logs(entity_type, entity_id);
create index idx_audit_created on audit_logs(created_at);

-- IMMUTABILITY
create or replace function prevent_audit_update()
returns trigger as $$
begin
  raise exception 'audit_logs is immutable';
end;
$$ language plpgsql;

create trigger trg_audit_no_update
before update or delete on audit_logs
for each row execute function prevent_audit_update();

-- =====================================================
-- RLS ENABLEMENT (CORE TABLES)
-- =====================================================

alter table organizations enable row level security;
alter table user_profiles enable row level security;
alter table memberships enable row level security;
alter table feature_flags enable row level security;
alter table organization_settings enable row level security;
alter table api_tokens enable row level security;
alter table audit_logs enable row level security;

-- =====================================================
-- RLS: ORGANIZATIONS
-- =====================================================

create policy "org_select"
on organizations
for select
using (
  deleted_at is null
);

create policy "org_owner_update"
on organizations
for update
using (
  exists (
    select 1 from memberships m
    where m.organization_id = organizations.id
    and m.user_id = auth.uid()
    and m.role in ('owner','admin','super_admin')
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: MEMBERSHIPS
-- =====================================================

create policy "membership_select"
on memberships
for select
using (
  deleted_at is null
  and user_id = auth.uid()
);

-- =====================================================
-- RLS: USER PROFILES
-- =====================================================

create policy "profile_select_own"
on user_profiles
for select
using (id = auth.uid());

create policy "profile_update_own"
on user_profiles
for update
using (id = auth.uid());

-- =====================================================
-- RLS: FEATURE FLAGS
-- =====================================================

create policy "feature_flags_select"
on feature_flags
for select
using (
  deleted_at is null
  and (
    organization_id is null
    or exists (
      select 1 from memberships m
      where m.organization_id = feature_flags.organization_id
      and m.user_id = auth.uid()
      and m.deleted_at is null
    )
  )
);

-- =====================================================
-- RLS: ORGANIZATION SETTINGS
-- =====================================================

create policy "org_settings_select"
on organization_settings
for select
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = organization_settings.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: API TOKENS (STRICT)
-- =====================================================

create policy "api_tokens_service_only"
on api_tokens
for all
using (false);

-- =====================================================
-- RLS: AUDIT LOGS (READ ONLY PER ORG)
-- =====================================================

create policy "audit_select_org"
on audit_logs
for select
using (
  exists (
    select 1 from memberships m
    where m.organization_id = audit_logs.organization_id
    and m.user_id = auth.uid()
  )
);

-- =====================================================
-- ENUMS / TYPES
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