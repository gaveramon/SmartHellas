-- =====================================================
-- REV21 FINAL AUTHORITY FREEZE
-- =====================================================

-- SINGLE SOURCE OF TRUTH ENFORCEMENT NOTE
-- Tenant resolution MUST ONLY occur via:
-- public.resolve_active_tenant(auth.uid())

-- DO NOT introduce:
-- - JWT-based tenant resolution
-- - membership EXISTS checks outside resolver
-- - alternative tenant gates

-- Any deviation is considered architecture drift
-- =====================================================

-- =====================================================
-- 051_rev21_tenant_authority_core.sql
-- REV21: canonical tenant resolution SSOT
-- Extracted from 050_rev20_baseline_consolidation.sql
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('051_rev21_tenant_authority_core', 'REV21.TENANT.AUTHORITY.CORE', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- Internal membership resolution (ONLY table access point)
-- -----------------------------------------------------

create or replace function platform._rev21_resolve_membership(
    p_user_id uuid,
    p_verify_tenant_id uuid default null
)
returns table(tenant_id uuid, role text, tenant_status text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
    if p_user_id is null then
        return;
    end if;

    if (select auth.uid()) is not null
       and p_user_id <> (select auth.uid())
       and not platform.is_platform_admin() then
        raise exception 'unauthorized';
    end if;

    if p_verify_tenant_id is not null then
        return query
        select tm.tenant_id, tm.role::text, t.status::text
        from public.tenant_memberships tm
        join public.tenants t on t.id = tm.tenant_id
        where tm.user_id = p_user_id
          and tm.tenant_id = p_verify_tenant_id
          and tm.is_active = true
          and t.status not in ('suspended', 'deleted')
        limit 1;
        return;
    end if;

    return query
    select tm.tenant_id, tm.role::text, t.status::text
    from public.tenant_memberships tm
    join public.tenants t on t.id = tm.tenant_id
    where tm.user_id = p_user_id
      and tm.is_active = true
      and t.status not in ('suspended', 'deleted')
    order by tm.created_at desc
    limit 1;
end;
$$;

revoke all on function platform._rev21_resolve_membership(uuid, uuid) from public, authenticated;


-- -----------------------------------------------------
-- resolve_active_tenant: sole tenant authority (membership SSOT)
-- -----------------------------------------------------

create or replace function public.resolve_active_tenant(
    p_user_id uuid,
    p_verify_tenant_id uuid default null
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select m.tenant_id
    from platform._rev21_resolve_membership(p_user_id, p_verify_tenant_id) m
    limit 1;
$$;

comment on function public.resolve_active_tenant(uuid, uuid) is
    'REV21 sole tenant authority. All membership is_active evaluation occurs here only.';

revoke all on function public.resolve_active_tenant(uuid, uuid) from public;
grant execute on function public.resolve_active_tenant(uuid, uuid) to authenticated, service_role;

alter function public.resolve_active_tenant(uuid, uuid) set search_path = '';

-- -----------------------------------------------------
-- Role context: derived from resolver internal only
-- -----------------------------------------------------

create or replace function platform.current_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
    select m.role
    from platform._rev21_resolve_membership((select auth.uid()), null) m
    limit 1;
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
        from platform._rev21_resolve_membership((select auth.uid()), null) m
        where m.role = required_role
    );
$$;

alter function platform._rev21_resolve_membership(uuid, uuid) set search_path = '';
alter function platform.current_role() set search_path = '';
alter function platform.has_role(text) set search_path = '';


-- -----------------------------------------------------
-- has_tenant_membership: REV21 shim (post-authority)
-- -----------------------------------------------------

create or replace function platform.has_tenant_membership(p_user_id uuid, p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select public.resolve_active_tenant(p_user_id, p_tenant_id) is not null;
$$;

comment on function platform.has_tenant_membership(uuid, uuid) is
    'Non-authoritative shim. Delegates to resolve_active_tenant(user_id, tenant_id).';


-- -----------------------------------------------------
-- auth_resolve_tenant_switch: no direct membership reads
-- -----------------------------------------------------

create or replace function public.auth_resolve_tenant_switch(
    p_user_id uuid,
    p_target_tid uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row record;
begin
    if p_user_id is null then
        raise exception 'authentication required';
    end if;
    if p_target_tid is null then
        raise exception 'tenant_id is required';
    end if;

    select m.tenant_id, m.role, m.tenant_status
    into v_row
    from platform._rev21_resolve_membership(p_user_id, p_target_tid) m
    limit 1;

    if v_row.tenant_id is null then
        raise exception 'No active membership for tenant';
    end if;

    if v_row.tenant_status in ('suspended', 'deleted') then
        raise exception 'Tenant is not available';
    end if;

    return jsonb_build_object(
        'tenant_id', v_row.tenant_id,
        'role', v_row.role,
        'tenant_status', v_row.tenant_status
    );
end;
$$;

-- =====================================================
-- END 051 REV21 TENANT AUTHORITY CORE
-- =====================================================

-- =====================================================
-- REV21 AUTHORITY FREEZE
-- ONLY VALID TENANT AUTHORITY:
-- resolve_active_tenant(auth.uid())
-- DO NOT INTRODUCE:
-- - JWT tenant resolution
-- - membership EXISTS outside resolver
-- - alternative tenant gates
-- =====================================================
