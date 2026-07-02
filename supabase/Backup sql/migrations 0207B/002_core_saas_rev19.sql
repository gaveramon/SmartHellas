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

create index if not exists idx_memberships_user_tenant_active
on tenant_memberships (user_id, tenant_id)
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

    provider_code text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_service_accounts_tenant
on service_accounts (tenant_id);

create index if not exists idx_service_accounts_tenant_created
on service_accounts (tenant_id, created_at desc);

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
    select nullif(
        nullif(
            coalesce(
                current_setting('request.jwt.claims', true),
                current_setting('request.jwt.claim', true)
            ),
            ''
        )::jsonb -> 'app_metadata' ->> 'tenant_id',
        ''
    )::uuid;
$$;

comment on function platform.current_tenant_id() is
    'Active tenant from JWT app_metadata.tenant_id only. No membership fallback — multi-tenant users must set tenant explicitly on switch.';

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
    select (select platform.current_tenant_id()) is not null
       and tid = (select platform.current_tenant_id())
       and exists (
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
        or (
            (select platform.current_tenant_id()) is not null
            and p_public_tenant_id = (select platform.current_tenant_id())
            and exists (
                select 1
                from public.tenant_memberships tm
                where tm.tenant_id = p_public_tenant_id
                  and tm.user_id = (select auth.uid())
                  and tm.is_active = true
            )
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
alter table public.tenants force row level security;

drop policy if exists tenants_select on public.tenants;
drop policy if exists tenants_insert on public.tenants;
drop policy if exists tenants_update on public.tenants;

create policy tenants_select on public.tenants
    for select to authenticated
    using (public.has_tenant_access(id) or platform.is_platform_admin());

create policy tenants_insert on public.tenants
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            (select auth.uid()) is not null
            and not exists (
                select 1
                from public.tenant_memberships tm
                where tm.user_id = (select auth.uid())
                  and tm.role = 'owner'
                  and tm.is_active
            )
        )
    );

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
alter table public.tenant_memberships force row level security;

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
alter table public.subscriptions force row level security;

drop policy if exists subscriptions_select on public.subscriptions;
drop policy if exists subscriptions_insert on public.subscriptions;
drop policy if exists subscriptions_update on public.subscriptions;

create policy subscriptions_select on public.subscriptions
    for select to authenticated
    using (public.has_tenant_access(tenant_id) or platform.is_platform_admin());

create policy subscriptions_insert on public.subscriptions
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (public.has_tenant_access(tenant_id) and platform.is_admin())
    );

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
alter table public.service_accounts force row level security;

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

-- -----------------------------------------------------
-- Domain SSOT (extensions delegate to *_domain_ext)
-- -----------------------------------------------------

create or replace function public.auth_domain(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_uid uuid;
    v_row record;
    v_result jsonb;
    v_role text;
    v_tenant_status text;
    v_existing record;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_uid := (select auth.uid());

    case p_op
    when 'get_auth_context' then
        if v_uid is null then raise exception 'authentication required'; end if;
        v_tid := platform.current_tenant_id();
        v_role := null;
        v_tenant_status := null;
        if v_tid is not null then
            select tm.role::text, t.status::text
            into v_role, v_tenant_status
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.tenant_id = v_tid and tm.user_id = v_uid and tm.is_active = true;
        end if;
        v_result := jsonb_build_object(
            'user_id', v_uid,
            'email', (select p.email from platform.profiles p where p.id = v_uid),
            'tenant_id', v_tid,
            'role', v_role,
            'tenant_status', v_tenant_status,
            'is_platform_admin', platform.is_platform_admin()
        );

    when 'list_user_tenants' then
        if v_uid is null then raise exception 'authentication required'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.tenant_id, t.name as tenant_name, tm.role, tm.is_active, t.status as tenant_status, tm.created_at
            from public.tenant_memberships tm
            join public.tenants t on t.id = tm.tenant_id
            where tm.user_id = v_uid and tm.is_active = true
        ) t;

    when 'get_current_tenant' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select tn.id, tn.name, tn.status, tn.created_at, tn.updated_at
            from public.tenants tn where tn.id = v_tid
        ) t;
        if v_result is null then raise exception 'Tenant not found'; end if;

    when 'create_tenant' then
        if v_uid is null then raise exception 'authentication required'; end if;
        insert into public.tenants (name) values (p_payload->>'name')
        returning id, name, status, created_at, updated_at into v_row;
        perform platform.log_audit('tenant.created', 'tenant', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'created_by', v_uid));
        v_result := to_jsonb(v_row);

    when 'update_tenant' then
        v_tid := platform.current_tenant_id();
        update public.tenants tn set
            name = case when p_payload ? 'name' then p_payload->>'name' else tn.name end,
            status = case when p_payload ? 'status'
                then (p_payload->>'status')::public.tenant_status else tn.status end
        where tn.id = v_tid
        returning tn.id, tn.name, tn.status, tn.created_at, tn.updated_at into v_row;
        if not found then raise exception 'Tenant not found'; end if;
        perform platform.log_audit('tenant.updated', 'tenant', v_tid, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_memberships' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at,
                   p.email, p.full_name, tm.created_at
            from public.tenant_memberships tm
            left join platform.profiles p on p.id = tm.user_id
            where tm.tenant_id = v_tid
        ) t;

    when 'update_membership' then
        v_tid := platform.current_tenant_id();
        select tm.id, tm.user_id, tm.tenant_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id = v_uid then
            if p_payload ? 'role' then raise exception 'Cannot change your own role via this endpoint'; end if;
        else
        end if;
        update public.tenant_memberships tm set
            role = case when p_payload ? 'role' then (p_payload->>'role')::public.user_role else tm.role end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else tm.is_active end,
            revoked_at = case
                when p_payload ? 'is_active' and not (p_payload->>'is_active')::boolean then now()
                when p_payload ? 'is_active' and (p_payload->>'is_active')::boolean then null
                else tm.revoked_at
            end
        where tm.id = (p_payload->>'membership_id')::uuid
        returning tm.id, tm.user_id, tm.tenant_id, tm.role, tm.is_active, tm.revoked_at, tm.created_at into v_row;
        perform platform.log_audit('membership.updated', 'tenant_membership', v_row.id, p_payload);
        select jsonb_build_object(
            'id', v_row.id,
            'user_id', v_row.user_id,
            'tenant_id', v_row.tenant_id,
            'role', v_row.role,
            'is_active', v_row.is_active,
            'revoked_at', v_row.revoked_at,
            'email', p.email,
            'full_name', p.full_name,
            'created_at', v_row.created_at
        ) into v_result
        from platform.profiles p where p.id = v_row.user_id;

    when 'revoke_membership' then
        v_tid := platform.current_tenant_id();
        select tm.id, tm.user_id into v_existing
        from public.tenant_memberships tm
        where tm.id = (p_payload->>'membership_id')::uuid and tm.tenant_id = v_tid;
        if not found then raise exception 'Membership not found'; end if;
        if v_existing.user_id <> v_uid then perform public.edge_require_admin(); end if;
        delete from public.tenant_memberships tm where tm.id = (p_payload->>'membership_id')::uuid;
        perform platform.log_audit('membership.revoked', 'tenant_membership', (p_payload->>'membership_id')::uuid,
            jsonb_build_object('tenant_id', v_tid, 'revoked_by', v_uid));
        v_result := jsonb_build_object('revoked', true, 'membership_id', p_payload->>'membership_id');

    when 'get_subscription' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at
            from public.subscriptions s where s.tenant_id = v_tid
        ) t;

    when 'update_subscription' then
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.subscriptions s where s.tenant_id = v_tid) then
            raise exception 'Subscription not found for tenant';
        end if;
        update public.subscriptions s set
            tier = case when p_payload ? 'tier' then (p_payload->>'tier')::public.subscription_tier else s.tier end,
            status = case when p_payload ? 'status' then (p_payload->>'status')::public.subscription_status else s.status end,
            current_period_start = case when p_payload ? 'current_period_start'
                then (p_payload->>'current_period_start')::timestamptz else s.current_period_start end,
            current_period_end = case when p_payload ? 'current_period_end'
                then (p_payload->>'current_period_end')::timestamptz else s.current_period_end end
        where s.tenant_id = v_tid
        returning s.id, s.tenant_id, s.tier, s.status, s.current_period_start, s.current_period_end, s.created_at, s.updated_at into v_row;
        perform platform.log_audit('subscription.updated', 'subscription', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'list_service_accounts' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at
            from public.service_accounts sa where sa.tenant_id = v_tid
        ) t;

    when 'create_service_account' then
        v_tid := platform.current_tenant_id();
        insert into public.service_accounts (tenant_id, name, provider_code, is_active)
        values (
            v_tid, p_payload->>'name', p_payload->>'provider_code',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, name, provider_code, is_active, created_at into v_row;
        perform platform.log_audit('service_account.created', 'service_account', v_row.id,
            jsonb_build_object('name', p_payload->>'name', 'provider_code', p_payload->>'provider_code'));
        v_result := to_jsonb(v_row);

    when 'update_service_account' then
        v_tid := platform.current_tenant_id();
        update public.service_accounts sa set
            name = case when p_payload ? 'name' then p_payload->>'name' else sa.name end,
            provider_code = case when p_payload ? 'provider_code' then p_payload->>'provider_code' else sa.provider_code end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else sa.is_active end
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid
        returning sa.id, sa.tenant_id, sa.name, sa.provider_code, sa.is_active, sa.created_at into v_row;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.updated', 'service_account', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_service_account' then
        v_tid := platform.current_tenant_id();
        delete from public.service_accounts sa
        where sa.id = (p_payload->>'service_account_id')::uuid and sa.tenant_id = v_tid;
        if not found then raise exception 'Service account not found'; end if;
        perform platform.log_audit('service_account.deleted', 'service_account', (p_payload->>'service_account_id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'service_account_id', p_payload->>'service_account_id');

    else
        return public.auth_domain_ext(p_op, p_payload);
    end case;

    return v_result;
end;
$$;


create or replace function public.auth_domain_ext(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    raise exception 'unknown auth_domain operation: %', p_op;
end;
$$;

revoke all on function public.auth_domain(text, jsonb) from public;
grant execute on function public.auth_domain(text, jsonb) to authenticated, service_role;

revoke all on function public.auth_domain_ext(text, jsonb) from public;
grant execute on function public.auth_domain_ext(text, jsonb) to authenticated, service_role;


-- END 002 CORE SAAS (CLEAN DOMAIN ONLY)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('002_core_saas_rev19', 'REV19.CORE.SAAS', false)
on conflict (version) do nothing;
