-- =====================================================
-- REV18.2.1 PRODUCTION PATCH
-- 002_core_saas.sql
-- CORE SAAS LAYER FIXED
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

create unique index idx_organizations_name_active
on organizations (lower(name))
where deleted_at is null;

create trigger trg_organizations_updated_at
before update on organizations
for each row execute function set_updated_at();

create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email citext not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid
);

create unique index idx_user_profiles_email_active
on user_profiles (email)
where deleted_at is null;

create trigger trg_user_profiles_updated_at
before update on user_profiles
for each row execute function set_updated_at();

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

create index idx_memberships_organization_id on memberships (organization_id);
create index idx_memberships_user_id on memberships (user_id);
create index idx_memberships_role on memberships (role);

create trigger trg_memberships_updated_at
before update on memberships
for each row execute function set_updated_at();

create or replace function is_org_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from memberships m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.deleted_at is null
  );
$$;

create or replace function has_org_role(p_organization_id uuid, p_roles user_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from memberships m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
      and m.deleted_at is null
      and m.role = any(p_roles)
  );
$$;

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  plan subscription_plan not null,
  status subscription_status not null default 'trialing',
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  external_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (organization_id, external_subscription_id)
);

create index idx_subscriptions_organization_id on subscriptions (organization_id);

create trigger trg_subscriptions_updated_at
before update on subscriptions
for each row execute function set_updated_at();

create table billing_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  provider integration_provider not null default 'stripe',
  external_customer_id text not null,
  billing_email citext,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid,
  unique (provider, external_customer_id)
);

create trigger trg_billing_accounts_updated_at
before update on billing_accounts
for each row execute function set_updated_at();

create table billing_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  billing_account_id uuid,
  subscription_id uuid,
  provider integration_provider not null default 'stripe',
  external_event_id text not null,
  status billing_status not null default 'pending',
  amount numeric,
  currency text not null default 'EUR',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, external_event_id),
  foreign key (billing_account_id, organization_id)
    references billing_accounts(id, organization_id) on delete set null,
  foreign key (subscription_id, organization_id)
    references subscriptions(id, organization_id) on delete set null
);

alter table organizations enable row level security;
alter table user_profiles enable row level security;
alter table memberships enable row level security;
alter table subscriptions enable row level security;
alter table billing_accounts enable row level security;
alter table billing_events enable row level security;