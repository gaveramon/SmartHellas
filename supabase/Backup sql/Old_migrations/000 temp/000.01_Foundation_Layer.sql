-- =====================================================
-- REV19 SUPABASE PLATFORM LAYER
-- PART 1 - FINAL PRODUCTION FOUNDATION
-- =====================================================

-- =====================================================
-- 000.00 PLATFORM SCHEMA
-- =====================================================

create schema if not exists platform;

comment on schema platform is 'REV19 Platform Layer - infrastructure only (no business logic allowed)';

-- =====================================================
-- 000.01 REQUIRED EXTENSIONS (SUPABASE SAFE)
-- =====================================================

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;
create extension if not exists btree_gin;
create extension if not exists btree_gist;
create extension if not exists pg_stat_statements;

-- Supabase ecosystem extensions
create extension if not exists pg_net;
create extension if not exists pg_cron;
create extension if not exists vault;

-- UUID compatibility (safe for Supabase environments)
create extension if not exists "uuid-ossp";

-- =====================================================
-- 000.02 PLATFORM VERSIONING (APPEND ONLY)
-- =====================================================

create table if not exists platform.schema_version (
    id uuid primary key default gen_random_uuid(),
    version text not null unique,
    applied_at timestamptz not null default now(),
    description text
);

-- IMPORTANT: append-only migration history
insert into platform.schema_version (version, description)
values ('REV19.PART1.FINAL', 'Platform foundation layer final production version')
on conflict (version) do nothing;

-- =====================================================
-- 000.03 UPDATED_AT FUNCTION (SINGLE SOURCE OF TRUTH)
-- =====================================================

create or replace function platform.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    if to_jsonb(new) ? 'updated_at' then
        new.updated_at = now();
    end if;
    return new;
end;
$$;

-- =====================================================
-- 000.04 GLOBAL CONSTANTS (SYSTEM ONLY)
-- =====================================================

create table if not exists platform.constants (
    key text primary key,
    value jsonb not null,
    description text,
    is_sensitive boolean default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger trg_constants_updated_at
before update on platform.constants
for each row execute function platform.set_updated_at();

insert into platform.constants (key, value, description)
values
('platform_name', '"REV19_SAAS"', 'Platform identifier'),
('max_tenants_baseline', '10000', 'Target scale baseline'),
('default_timezone', '"UTC"', 'System timezone contract')
on conflict (key) do nothing;

-- =====================================================
-- 000.05 TENANT SETTINGS (MULTI-TENANT CORE BASE)
-- =====================================================

create table if not exists platform.tenant_settings (
    tenant_id uuid not null,
    key text not null,
    value jsonb not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (tenant_id, key)
);

create index if not exists idx_tenant_settings_tenant_id
on platform.tenant_settings (tenant_id);

create trigger trg_tenant_settings_updated_at
before update on platform.tenant_settings
for each row execute function platform.set_updated_at();

-- =====================================================
-- 000.06 PLATFORM CONTRACT (ARCHITECTURE ENFORCEMENT BASE)
-- =====================================================

create table if not exists platform.table_contracts (
    table_name text primary key,
    requires_tenant_id boolean default true,
    requires_created_at boolean default true,
    requires_updated_at boolean default true,
    requires_rls boolean default true,
    required_indexes jsonb default '[]'::jsonb,
    description text,
    created_at timestamptz not null default now()
);

-- Example contract baseline (used by 001–013 validation later)
insert into platform.table_contracts (
    table_name,
    requires_tenant_id,
    requires_created_at,
    requires_updated_at,
    requires_rls,
    description
)
values
('default_contract', true, true, true, true, 'Default SaaS table contract baseline')
on conflict (table_name) do nothing;

-- =====================================================
-- 000.07 PLATFORM GUARANTEES (HARD RULES)
-- =====================================================

comment on schema platform is '
REV19 RULES:
- No business logic allowed
- No domain entities allowed
- Only infrastructure and platform services
- All domain tables MUST follow table_contracts rules
- All timestamp logic MUST use platform.set_updated_at
';

-- =====================================================
-- END PART 1 - FINAL
-- =====================================================