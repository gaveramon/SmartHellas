-- =====================================================
-- REV18.2 PRODUCTION
-- 002_core_saas.sql (FINAL IMPROVED)
-- CORE SAAS LAYER (TENANT + RBAC + BILLING FOUNDATION)
-- =====================================================

-- =====================================================
-- EXTENSION (email safety)
-- =====================================================

create extension if not exists citext;

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

create trigger trg_org_updated_at
before update on organizations
for each row execute function set_updated_at();

create unique index idx_org_name
on organizations(lower(name));

-- =====================================================
-- USER PROFILES
-- =====================================================

create table user_profiles (
    id uuid primary key references auth.users(id) on delete cascade,

    full_name text,
    email citext not null,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    deleted_at timestamptz,
    deleted_by uuid
);

create trigger trg_user_profiles_updated_at
before update on user_profiles
for each row execute function set_updated_at();

create unique index idx_user_profiles_email
on user_profiles(email);

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

create trigger trg_memberships_updated_at
before update on memberships
for each row execute function set_updated_at();

create index idx_memberships_org_user
on memberships(organization_id, user_id);

create index idx_memberships_role
on memberships(role);

-- =====================================================
-- FEATURE FLAGS (NO GLOBAL NULL ORG AMBIGUITY)
-- =====================================================

create table feature_flags (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,

    key text not null,
    enabled boolean not null default false,
    metadata jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    deleted_at timestamptz,
    deleted_by uuid,

    unique (organization_id, key)
);

create trigger trg_feature_flags_updated_at
before update on feature_flags
for each row execute function set_updated_at();

create index idx_feature_flags_org
on feature_flags(organization_id);

-- =====================================================
-- ORGANIZATION SETTINGS (SINGLE SOURCE OF TRUTH)
-- =====================================================

create table organization_settings (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,

    check_in_time time not null default '15:00',
    check_out_time time not null default '11:00',

    notification_email boolean not null default true,
    notification_sms boolean not null default false,
    notification_push boolean not null default false,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    deleted_at timestamptz,
    deleted_by uuid,

    unique (organization_id)
);

create trigger trg_org_settings_updated_at
before update on organization_settings
for each row execute function set_updated_at();

-- =====================================================
-- API TOKENS (SERVICE + INTEGRATIONS)
-- =====================================================

create table api_tokens (
    id uuid primary key default gen_random_uuid(),

    organization_id uuid not null references organizations(id) on delete cascade,

    name text not null,
    token_hash text not null,
    scope api_token_scope not null,

    last_used_at timestamptz,
    expires_at timestamptz,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    deleted_at timestamptz,
    deleted_by uuid,

    unique (token_hash)
);

create trigger trg_api_tokens_updated_at
before update on api_tokens
for each row execute function set_updated_at();

create index idx_api_tokens_org
on api_tokens(organization_id);

-- =====================================================
-- AUDIT LOGS
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
create index idx_audit_actor on audit_logs(actor_user_id);

-- =====================================================
-- AUDIT WRITER FUNCTION
-- =====================================================

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
-- RLS ENABLEMENT
-- =====================================================

alter table organizations enable row level security;
alter table user_profiles enable row level security;
alter table memberships enable row level security;
alter table feature_flags enable row level security;
alter table organization_settings enable row level security;
alter table api_tokens enable row level security;
alter table audit_logs enable row level security;

-- =====================================================
-- RLS: ORGANIZATIONS (FIXED SECURITY)
-- =====================================================

create policy "org_select"
on organizations
for select
using (
    deleted_at is null
    and is_org_member(id)
);

create policy "org_update"
on organizations
for update
using (is_org_member(id));

-- =====================================================
-- RLS: USER PROFILES
-- =====================================================

create policy "profile_select_own"
on user_profiles
for select
using (id = auth.uid());

create policy "profile_insert_own"
on user_profiles
for insert
with check (id = auth.uid());

create policy "profile_update_own"
on user_profiles
for update
using (id = auth.uid());

-- =====================================================
-- RLS: MEMBERSHIPS (FIXED)
-- =====================================================

create policy "membership_select"
on memberships
for select
using (
    deleted_at is null
    and is_org_member(organization_id)
);

-- =====================================================
-- RLS: FEATURE FLAGS (NO GLOBAL NULL BUG)
-- =====================================================

create policy "feature_flags_select"
on feature_flags
for select
using (
    deleted_at is null
    and is_org_member(organization_id)
);

-- =====================================================
-- RLS: ORGANIZATION SETTINGS
-- =====================================================

create policy "org_settings_select"
on organization_settings
for select
using (
    deleted_at is null
    and is_org_member(organization_id)
);

-- =====================================================
-- RLS: API TOKENS (SERVICE ONLY)
-- =====================================================

create policy "api_tokens_no_access"
on api_tokens
for all
using (false);

-- =====================================================
-- RLS: AUDIT LOGS
-- =====================================================

create policy "audit_select"
on audit_logs
for select
using (is_org_member(organization_id));

create policy "audit_insert"
on audit_logs
for insert
with check (is_org_member(organization_id));