-- =====================================================
-- 047_platform_security_rev19.sql
-- 000 Platform + 004 Booking — grant hardening + credential RLS
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('047_platform_security_rev19', 'REV19.SECURITY.PLATFORM', false)
on conflict (version) do nothing;


-- -----------------------------------------------------
-- 009 Commerce: restrict payment status transitions
-- -----------------------------------------------------

revoke all on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) from public, authenticated;
grant execute on function public.payment_transition_status(uuid, public.payment_status, text, text, text, jsonb) to service_role;


-- -----------------------------------------------------
-- 004 Booking: restrict credential metadata to admin/manager
-- -----------------------------------------------------

drop policy if exists access_credentials_select on public.access_credentials;

create policy access_credentials_select on public.access_credentials
    for select to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );


-- -----------------------------------------------------
-- 015 CRM: whitelist soft-delete targets
-- -----------------------------------------------------

create or replace function public.crm_soft_delete_row(
    p_table regclass,
    p_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_count int;
    v_tid uuid;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    if p_table::text not in (
        'public.crm_pipelines',
        'public.crm_pipeline_stages',
        'public.crm_campaigns',
        'public.crm_tags',
        'public.crm_companies',
        'public.crm_contacts',
        'public.crm_leads',
        'public.crm_contact_company',
        'public.crm_company_tenants',
        'public.crm_contact_tenants',
        'public.crm_opportunities',
        'public.crm_tasks',
        'public.crm_interactions',
        'public.crm_notes',
        'public.crm_tag_assignments',
        'public.crm_lists',
        'public.crm_list_members',
        'public.crm_custom_fields'
    ) then
        raise exception 'table not allowed for CRM soft delete';
    end if;

    execute format(
        'update %s set deleted_at = now() where id = $1 and tenant_id = $2',
        p_table
    ) using p_id, v_tid;

    get diagnostics v_count = row_count;
    if v_count = 0 then
        raise exception 'record not found or not accessible';
    end if;

    return jsonb_build_object('deleted', true, 'id', p_id);
end;
$$;

revoke all on function public.crm_soft_delete_row(regclass, uuid) from public, authenticated;
grant execute on function public.crm_soft_delete_row(regclass, uuid) to service_role;


create or replace function public.edge_soft_delete_row(
    p_table regclass,
    p_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.crm_soft_delete_row(p_table, p_id);
end;
$$;

revoke all on function public.edge_soft_delete_row(regclass, uuid) from public, authenticated;
grant execute on function public.edge_soft_delete_row(regclass, uuid) to service_role;


-- -----------------------------------------------------
-- Ensure auth_domain_ext exists before grant lockdown
-- (router to auth_domain_ext_031; may be absent if 033 skipped)
-- -----------------------------------------------------

create or replace function public.auth_domain_ext(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_result jsonb;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'resolve_user_by_email' then
        if p_payload->>'email' is null then raise exception 'email is required'; end if;
        select to_jsonb(t) into v_result from (
            select p.id, p.email, p.full_name
            from platform.profiles p
            where lower(p.email) = lower(p_payload->>'email')
            limit 1
        ) t;
        return v_result;

    else
        return public.auth_domain_ext_031(p_op, p_payload);
    end case;
end;
$$;


-- -----------------------------------------------------
-- Revoke direct *_domain execute from authenticated (API layer required)
-- Idempotent: only functions that exist at apply time (050 re-applies full lockdown)
-- -----------------------------------------------------

do $block$
declare
    r record;
begin
    for r in
        select
            n.nspname,
            p.proname,
            pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public'
          and p.proname = any (array[
            'auth_domain_ext',
            'auth_domain_ext_031',
            'commerce_domain',
            'booking_domain',
            'locks_domain',
            'crm_domain',
            'preconfig_domain',
            'portal_domain',
            'onboarding_domain',
            'optimization_domain',
            'monetization_domain',
            'operations_domain',
            'automation_domain',
            'automation_domain_ext',
            'notification_domain',
            'payment_domain'
          ])
    loop
        execute format(
            'revoke all on function %I.%I(%s) from public, authenticated',
            r.nspname, r.proname, r.args
        );
        execute format(
            'grant execute on function %I.%I(%s) to service_role',
            r.nspname, r.proname, r.args
        );
    end loop;
end;
$block$;
