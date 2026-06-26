-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 3 - ENTERPRISE TENANT + RBAC + RLS CORE
-- =====================================================

-- =====================================================
-- 000.03 TENANTS (CORE ENTITY)
-- =====================================================

create table if not exists platform.tenants (
    id uuid primary key default gen_random_uuid(),

    name text not null,
    type text default 'airbnb_owner',

    is_active boolean default true,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger trg_tenants_updated_at
before update on platform.tenants
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.03.01 USER ↔ TENANT MEMBERSHIP (SOURCE OF TRUTH)
-- =====================================================

create table if not exists platform.user_tenants (
    id uuid primary key default gen_random_uuid(),

    user_id uuid not null references platform.profiles(id) on delete cascade,
    tenant_id uuid not null references platform.tenants(id) on delete cascade,

    role text not null,

    is_active boolean default true,

    created_at timestamptz not null default now(),

    unique (user_id, tenant_id)
);

create index if not exists idx_user_tenants_user
on platform.user_tenants (user_id);

create index if not exists idx_user_tenants_tenant
on platform.user_tenants (tenant_id);

-- =====================================================
-- 000.03.02 TENANT CONTEXT RESOLUTION (DETERMINISTIC SAFE)
-- =====================================================

-- RULE:
-- 1. If user has only 1 tenant → auto use it
-- 2. If multiple → require explicit selection via client layer

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
as $$
    select ut.tenant_id
    from platform.user_tenants ut
    where ut.user_id = auth.uid()
      and ut.is_active = true
    order by ut.created_at asc
    limit 1
$$;

-- =====================================================
-- 000.03.03 ROLE RESOLUTION (TENANT-SCOPED)
-- =====================================================

create or replace function platform.current_role()
returns text
language sql
stable
as $$
    select ut.role
    from platform.user_tenants ut
    where ut.user_id = auth.uid()
      and ut.tenant_id = platform.current_tenant_id()
      and ut.is_active = true
    limit 1
$$;

-- =====================================================
-- 000.03.04 TENANT ACCESS CHECK
-- =====================================================

create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.user_tenants ut
        where ut.user_id = auth.uid()
          and ut.tenant_id = tid
          and ut.is_active = true
    );
$$;

-- =====================================================
-- 000.03.05 ROLE ENGINE (SAFE RBAC)
-- =====================================================

create or replace function platform.has_role(required_role text)
returns boolean
language sql
stable
as $$
    select exists (
        select 1
        from platform.user_tenants ut
        where ut.user_id = auth.uid()
          and ut.tenant_id = platform.current_tenant_id()
          and ut.role = required_role
          and ut.is_active = true
    );
$$;

-- =====================================================
-- 000.03.06 ROLE HELPERS (HIERARCHY SAFE)
-- =====================================================

create or replace function platform.is_owner()
returns boolean
language sql
stable
as $$
    select platform.has_role('owner');
$$;

create or replace function platform.is_admin()
returns boolean
language sql
stable
as $$
    select platform.has_role('owner')
        or platform.has_role('admin');
$$;

create or replace function platform.is_support()
returns boolean
language sql
stable
as $$
    select platform.has_role('support');
$$;

-- =====================================================
-- 000.03.07 PERMISSION LAYER (LIGHTWEIGHT ABSTRACTION)
-- =====================================================

-- NOTE:
-- This is NOT full ABAC.
-- It is a scalable hook for future device / onboarding / automation permissions.

create or replace function platform.has_permission(permission text)
returns boolean
language sql
stable
as $$
    select case
        when platform.is_owner() then true
        when platform.is_admin() then true
        else false
    end;
$$;

-- =====================================================
-- 000.03.08 RLS CORE PATTERNS
-- =====================================================

-- Tenant ownership match (core RLS building block)
create or replace function platform.rls_tenant_match(record_tenant_id uuid)
returns boolean
language sql
stable
as $$
    select record_tenant_id = platform.current_tenant_id()
$$;

-- Admin override pattern (for support + debugging)
create or replace function platform.rls_admin_bypass()
returns boolean
language sql
stable
as $$
    select platform.is_admin();
$$;

-- Full access safety pattern
create or replace function platform.rls_allow()
returns boolean
language sql
stable
as $$
    select platform.is_admin() or platform.rls_tenant_match(platform.current_tenant_id());
$$;

-- =====================================================
-- 000.03.09 SECURITY CONTRACT
-- =====================================================

comment on schema platform is '
REV19 TENANT + RBAC RULES:

1. tenant context is derived from user_tenants
2. single tenant users auto-resolve safely
3. multi-tenant users require explicit selection in application layer
4. roles are always tenant-scoped
5. RLS must use rls_tenant_match() or rls_allow()
6. admin bypass is controlled and explicit
7. permissions layer is extensible but not required yet
';
-- =====================================================
-- END PART 3 (FINAL ENTERPRISE)
-- =====================================================