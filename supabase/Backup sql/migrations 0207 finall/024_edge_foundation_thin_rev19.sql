-- =====================================================
-- 030_edge_foundation_thin_rev19.sql
-- Thin Edge wrappers for 017 foundation business entrypoints + OAuth callback
-- Business SSOT lives in domain extension migrations 024–028
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('030_edge_foundation_thin_rev19', 'REV19.EDGE.FOUNDATION.THIN', false)
on conflict (version) do nothing;

-- -----------------------------------------------------
-- 003 devices: assign_device_to_room (Edge guard → domain)
-- -----------------------------------------------------

create or replace function public.assign_device_to_room(
    p_device_id uuid,
    p_room_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.devices_assign_device_to_room(p_device_id, p_room_id);
end;
$$;

revoke all on function public.assign_device_to_room(uuid, uuid) from public;
grant execute on function public.assign_device_to_room(uuid, uuid) to authenticated, service_role;

-- -----------------------------------------------------
-- 002 SaaS + 009 commerce: subscription plan change
-- -----------------------------------------------------

create or replace function public.change_subscription_plan(p_plan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_admin();
    return public.commerce_change_subscription_plan(p_plan_id);
end;
$$;

revoke all on function public.change_subscription_plan(uuid) from public;
grant execute on function public.change_subscription_plan(uuid) to authenticated, service_role;

-- -----------------------------------------------------
-- 008 logistics: fulfilment dispatch
-- -----------------------------------------------------

create or replace function public.dispatch_fulfilment_order(
    p_fulfilment_order_id uuid,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform public.edge_require_manager();
    return public.logistics_dispatch_fulfilment_order(p_fulfilment_order_id, p_payload);
end;
$$;

revoke all on function public.dispatch_fulfilment_order(uuid, jsonb) from public;
grant execute on function public.dispatch_fulfilment_order(uuid, jsonb) to authenticated, service_role;

-- -----------------------------------------------------
-- 015 CRM: generic soft delete (Edge guard → domain)
-- -----------------------------------------------------

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

revoke all on function public.edge_soft_delete_row(regclass, uuid) from public;
grant execute on function public.edge_soft_delete_row(regclass, uuid) to authenticated, service_role;

-- -----------------------------------------------------
-- 005 integrations: OAuth callback (service_role only)
-- -----------------------------------------------------

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
begin
    return public.integrations_complete_oauth(p_tenant_id, p_provider_code, p_credentials_ref);
end;
$$;

revoke all on function public.integrations_oauth_complete(uuid, text, text) from public;
grant execute on function public.integrations_oauth_complete(uuid, text, text) to service_role;

-- =====================================================
-- END 030 EDGE FOUNDATION THIN
-- =====================================================
