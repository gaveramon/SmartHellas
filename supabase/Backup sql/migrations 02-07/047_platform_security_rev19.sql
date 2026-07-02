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
-- Revoke direct *_domain execute from authenticated (API layer required)
-- -----------------------------------------------------

revoke all on function public.auth_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.auth_domain_ext(text, jsonb) to service_role;

revoke all on function public.auth_domain_ext_031(text, jsonb) from public, authenticated;
grant execute on function public.auth_domain_ext_031(text, jsonb) to service_role;

revoke all on function public.commerce_domain(text, jsonb) from public, authenticated;
grant execute on function public.commerce_domain(text, jsonb) to service_role;

revoke all on function public.booking_domain(text, jsonb) from public, authenticated;
grant execute on function public.booking_domain(text, jsonb) to service_role;

revoke all on function public.locks_domain(text, jsonb) from public, authenticated;
grant execute on function public.locks_domain(text, jsonb) to service_role;

revoke all on function public.crm_domain(text, jsonb) from public, authenticated;
grant execute on function public.crm_domain(text, jsonb) to service_role;

revoke all on function public.preconfig_domain(text, jsonb) from public, authenticated;
grant execute on function public.preconfig_domain(text, jsonb) to service_role;

revoke all on function public.portal_domain(text, jsonb) from public, authenticated;
grant execute on function public.portal_domain(text, jsonb) to service_role;

revoke all on function public.onboarding_domain(text, jsonb) from public, authenticated;
grant execute on function public.onboarding_domain(text, jsonb) to service_role;

revoke all on function public.optimization_domain(text, jsonb) from public, authenticated;
grant execute on function public.optimization_domain(text, jsonb) to service_role;

revoke all on function public.monetization_domain(text, jsonb) from public, authenticated;
grant execute on function public.monetization_domain(text, jsonb) to service_role;

revoke all on function public.operations_domain(text, jsonb) from public, authenticated;
grant execute on function public.operations_domain(text, jsonb) to service_role;

revoke all on function public.automation_domain(text, jsonb) from public, authenticated;
grant execute on function public.automation_domain(text, jsonb) to service_role;

revoke all on function public.automation_domain_ext(text, jsonb) from public, authenticated;
grant execute on function public.automation_domain_ext(text, jsonb) to service_role;

revoke all on function public.notification_domain(text, jsonb) from public, authenticated;
grant execute on function public.notification_domain(text, jsonb) to service_role;

revoke all on function public.payment_domain(text, jsonb) from public, authenticated;
grant execute on function public.payment_domain(text, jsonb) to service_role;
