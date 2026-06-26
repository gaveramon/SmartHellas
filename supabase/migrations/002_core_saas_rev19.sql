-- =====================================================
-- 002 CORE SAAS (CLEANED + 000 SEPARATION ALIGNED)
-- TENANCY + IDENTITY + BILLING FOUNDATION ONLY
-- =====================================================

-- =====================================================
-- 1. TENANTS (CORE MULTI-TENANCY ENTITY)
-- =====================================================

create table if not exists tenants (
    id uuid primary key default gen_random_uuid(),

    name text not null,

    status tenant_status default 'active',

    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_tenants_status
on tenants (status);

-- =====================================================
-- 2. USERS (GLOBAL IDENTITY LAYER)
-- =====================================================

create table if not exists users (
    id uuid primary key default gen_random_uuid(),

    email citext unique not null,

    full_name text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_users_email
on users (email);

-- =====================================================
-- 3. TENANT MEMBERSHIPS (ACCESS CONTROL LAYER)
-- =====================================================

create table if not exists tenant_memberships (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    user_id uuid not null references users(id) on delete cascade,

    role user_role not null,

    created_at timestamptz default now(),

    unique (tenant_id, user_id)
);

create index if not exists idx_memberships_tenant
on tenant_memberships (tenant_id);

create index if not exists idx_memberships_user
on tenant_memberships (user_id);

-- =====================================================
-- 4. SERVICE ACCOUNTS (SYSTEM INTEGRATIONS)
-- =====================================================

create table if not exists service_accounts (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid references tenants(id) on delete cascade,

    name text not null,

    provider integration_provider,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_service_accounts_tenant
on service_accounts (tenant_id);

-- =====================================================
-- 5. SUBSCRIPTIONS (COMMERCIAL STATE ONLY)
-- =====================================================

create table if not exists subscriptions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    tier subscription_tier not null,

    status text not null default 'active',
    -- active | paused | cancelled

    current_period_start timestamptz,
    current_period_end timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_subscriptions_tenant
on subscriptions (tenant_id);

-- =====================================================
-- 6. USER-TO-TENANT CONTEXT VIEW (OPTIONAL OPTIMIZATION)
-- =====================================================

create view tenant_user_context as
select
    tm.user_id,
    tm.tenant_id,
    tm.role,
    t.status as tenant_status
from tenant_memberships tm
join tenants t on t.id = tm.tenant_id;

-- =====================================================
-- END 002 CORE SAAS (CLEAN DOMAIN ONLY)
-- =====================================================