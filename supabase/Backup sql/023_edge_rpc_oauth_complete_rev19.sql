-- =====================================================
-- 023 EDGE RPC OAUTH COMPLETE (REV19)
-- Service-role SSOT for OAuth callback DB writes (no user JWT tenant context)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('023_edge_rpc_oauth_complete_rev19', 'REV19.EDGE.RPC.OAUTH', false)
on conflict (version) do nothing;

create or replace function public.integrations_oauth_complete(
    p_tenant_id uuid,
    p_provider_code text,
    p_credentials_ref text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.tenant_integrations;
begin
    if p_tenant_id is null or p_provider_code is null or p_credentials_ref is null then
        raise exception 'tenant_id, provider_code, and credentials_ref are required';
    end if;

    if not exists (
        select 1 from public.integration_providers ip where ip.code = p_provider_code
    ) then
        raise exception 'Integration provider not found';
    end if;

    insert into public.tenant_integrations (
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled
    )
    values (
        p_tenant_id,
        p_provider_code,
        p_credentials_ref,
        '{}'::jsonb,
        true
    )
    on conflict (tenant_id, provider_code) do update
        set credentials_ref = excluded.credentials_ref,
            is_enabled = true,
            updated_at = now()
    returning
        id,
        tenant_id,
        provider_code,
        credentials_ref,
        config,
        is_enabled,
        created_at,
        updated_at
    into v_row;

    perform platform.log_audit(
        'integration.oauth_completed',
        'tenant_integration',
        v_row.id,
        jsonb_build_object('provider_code', p_provider_code)
    );

    return to_jsonb(v_row);
end;
$$;

revoke all on function public.integrations_oauth_complete(uuid, text, text) from public;
grant execute on function public.integrations_oauth_complete(uuid, text, text) to service_role;
