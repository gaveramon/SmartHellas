-- =====================================================
-- 002 CORE SAAS (CLEANED + 000 SEPARATION ALIGNED)
-- TENANCY + MEMBERSHIP + BILLING FOUNDATION ONLY
-- Identity SSOT: platform.profiles (000)
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

create trigger trg_tenants_updated_at
before update on tenants
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. TENANT MEMBERSHIPS (ACCESS CONTROL LAYER)
-- user_id → platform.profiles (auth-linked identity)
-- =====================================================

create table if not exists tenant_memberships (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    user_id uuid not null references platform.profiles(id) on delete cascade,

    role user_role not null,

    is_active boolean not null default true,

    revoked_at timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (tenant_id, user_id)
);

create index if not exists idx_memberships_tenant
on tenant_memberships (tenant_id);

create index if not exists idx_memberships_user
on tenant_memberships (user_id);

create index if not exists idx_memberships_active
on tenant_memberships (tenant_id, is_active)
where is_active = true;

create trigger trg_memberships_updated_at
before update on tenant_memberships
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2B. TENANT PROVISIONING (CREATOR → OWNER)
-- =====================================================

create or replace function public.handle_new_tenant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (select auth.uid()) is not null then
        insert into public.tenant_memberships (
            tenant_id,
            user_id,
            role,
            is_active
        )
        values (
            new.id,
            (select auth.uid()),
            'owner',
            true
        );
    end if;

    return new;
end;
$$;

create trigger trg_tenant_bootstrap_owner
after insert on public.tenants
for each row execute function public.handle_new_tenant();

-- =====================================================
-- 2C. OWNER INVARIANT (AT LEAST ONE ACTIVE OWNER)
-- =====================================================

create or replace function public.enforce_tenant_owner_invariant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_owner_count int;
begin
    if tg_op = 'DELETE' then
        if old.role = 'owner' and old.is_active then
            select count(*)
            into v_owner_count
            from public.tenant_memberships tm
            where tm.tenant_id = old.tenant_id
              and tm.role = 'owner'
              and tm.is_active = true
              and tm.id <> old.id;

            if v_owner_count = 0 then
                raise exception 'cannot remove last active owner from tenant';
            end if;
        end if;

        return old;
    end if;

    if tg_op = 'UPDATE' then
        if old.role = 'owner'
           and old.is_active
           and (new.role <> 'owner' or not new.is_active) then
            select count(*)
            into v_owner_count
            from public.tenant_memberships tm
            where tm.tenant_id = old.tenant_id
              and tm.role = 'owner'
              and tm.is_active = true
              and tm.id <> old.id;

            if v_owner_count = 0 then
                raise exception 'cannot demote or deactivate last active owner';
            end if;
        end if;
    end if;

    return new;
end;
$$;

create trigger trg_memberships_owner_invariant
before update or delete on public.tenant_memberships
for each row execute function public.enforce_tenant_owner_invariant();

-- =====================================================
-- 3. SERVICE ACCOUNTS (SYSTEM INTEGRATIONS)
-- =====================================================

create table if not exists service_accounts (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    name text not null,

    provider integration_provider,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_service_accounts_tenant
on service_accounts (tenant_id);

-- =====================================================
-- 4. SUBSCRIPTIONS (COMMERCIAL STATE ONLY)
-- =====================================================

create table if not exists subscriptions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    tier subscription_tier not null,

    status subscription_status not null default 'trial',

    current_period_start timestamptz,
    current_period_end timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_subscriptions_tenant
on subscriptions (tenant_id);

create trigger trg_subscriptions_updated_at
before update on subscriptions
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5. USER-TO-TENANT CONTEXT VIEW
-- =====================================================

create or replace view tenant_user_context as
select
    tm.user_id,
    tm.tenant_id,
    tm.role,
    tm.is_active,
    t.status as tenant_status
from tenant_memberships tm
join tenants t on t.id = tm.tenant_id;

-- =====================================================
-- 6. PLATFORM AUTH BINDING (REPLACES 000 STUBS)
-- =====================================================

create or replace function platform.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(
        nullif(
            coalesce(
                current_setting('request.jwt.claims', true),
                current_setting('request.jwt.claim', true)
            ),
            ''
        )::jsonb -> 'app_metadata' ->> 'tenant_id',
        (
            select tm.tenant_id::text
            from public.tenant_memberships tm
            where tm.user_id = (select auth.uid())
              and tm.is_active = true
            order by tm.created_at asc
            limit 1
        )
    )::uuid;
$$;

create or replace function platform.current_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select tm.role::text
    from public.tenant_memberships tm
    where tm.user_id = (select auth.uid())
      and tm.tenant_id = (select platform.current_tenant_id())
      and tm.is_active = true
    limit 1;
$$;

create or replace function platform.has_tenant_access(tid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.tenant_memberships tm
        where tm.user_id = (select auth.uid())
          and tm.tenant_id = tid
          and tm.is_active = true
    );
$$;

create or replace function platform.has_role(required_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.tenant_memberships tm
        where tm.user_id = (select auth.uid())
          and tm.tenant_id = (select platform.current_tenant_id())
          and tm.role::text = required_role
          and tm.is_active = true
    );
$$;

create or replace function platform.is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.has_role('owner');
$$;

create or replace function platform.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.has_role('owner')
        or platform.has_role('admin');
$$;

create or replace function platform.is_support()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.has_role('support');
$$;

create or replace function platform.has_permission(permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when platform.is_owner() then true
        when platform.is_admin() then permission <> 'platform_admin'
        else false
    end;
$$;

create or replace function public.has_tenant_access(p_public_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select platform.is_platform_admin()
        or exists (
            select 1
            from public.tenant_memberships tm
            where tm.tenant_id = p_public_tenant_id
              and tm.user_id = (select auth.uid())
              and tm.is_active = true
        );
$$;

revoke all on function platform.current_tenant_id() from public;
revoke all on function platform.current_role() from public;
revoke all on function platform.has_tenant_access(uuid) from public;
revoke all on function platform.has_role(text) from public;
revoke all on function platform.is_owner() from public;
revoke all on function platform.is_admin() from public;
revoke all on function platform.is_support() from public;
revoke all on function platform.has_permission(text) from public;

grant execute on function platform.current_tenant_id() to authenticated, service_role;
grant execute on function platform.current_role() to authenticated, service_role;
grant execute on function platform.has_tenant_access(uuid) to authenticated, service_role;
grant execute on function platform.has_role(text) to authenticated, service_role;
grant execute on function platform.is_owner() to authenticated, service_role;
grant execute on function platform.is_admin() to authenticated, service_role;
grant execute on function platform.is_support() to authenticated, service_role;
grant execute on function platform.has_permission(text) to authenticated, service_role;

-- =====================================================
-- 7. PUBLIC DOMAIN RLS (002 TABLES)
-- =====================================================

alter table public.tenants enable row level security;

drop policy if exists tenants_select on public.tenants;
drop policy if exists tenants_insert on public.tenants;
drop policy if exists tenants_update on public.tenants;

create policy tenants_select on public.tenants
    for select to authenticated
    using (public.has_tenant_access(id) or platform.is_platform_admin());

create policy tenants_insert on public.tenants
    for insert to authenticated
    with check ((select auth.uid()) is not null);

create policy tenants_update on public.tenants
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (public.has_tenant_access(id) and platform.is_admin())
    )
    with check (
        platform.is_platform_admin()
        or (public.has_tenant_access(id) and platform.is_admin())
    );

alter table public.tenant_memberships enable row level security;

drop policy if exists tenant_memberships_select on public.tenant_memberships;
drop policy if exists tenant_memberships_insert on public.tenant_memberships;
drop policy if exists tenant_memberships_update on public.tenant_memberships;
drop policy if exists tenant_memberships_delete on public.tenant_memberships;

create policy tenant_memberships_select on public.tenant_memberships
    for select to authenticated
    using (
        public.has_tenant_access(tenant_id)
        or platform.is_platform_admin()
    );

create policy tenant_memberships_insert on public.tenant_memberships
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and platform.is_admin()
        )
    );

create policy tenant_memberships_update on public.tenant_memberships
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and platform.is_admin()
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and platform.is_admin()
        )
    );

create policy tenant_memberships_delete on public.tenant_memberships
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and platform.is_admin()
        )
        or user_id = (select auth.uid())
    );

alter table public.subscriptions enable row level security;

drop policy if exists subscriptions_select on public.subscriptions;
drop policy if exists subscriptions_update on public.subscriptions;

create policy subscriptions_select on public.subscriptions
    for select to authenticated
    using (public.has_tenant_access(tenant_id) or platform.is_platform_admin());

create policy subscriptions_update on public.subscriptions
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    )
    with check (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    );

alter table public.service_accounts enable row level security;

drop policy if exists service_accounts_select on public.service_accounts;
drop policy if exists service_accounts_insert on public.service_accounts;
drop policy if exists service_accounts_update on public.service_accounts;
drop policy if exists service_accounts_delete on public.service_accounts;

create policy service_accounts_select on public.service_accounts
    for select to authenticated
    using (public.has_tenant_access(tenant_id) or platform.is_platform_admin());

create policy service_accounts_insert on public.service_accounts
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    );

create policy service_accounts_update on public.service_accounts
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    )
    with check (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    );

create policy service_accounts_delete on public.service_accounts
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    );

-- =====================================================
-- END 002 CORE SAAS (CLEAN DOMAIN ONLY)
-- =====================================================
