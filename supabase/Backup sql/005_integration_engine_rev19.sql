-- =====================================================
-- 005 INTEGRATION ENGINE (CLEAN DEFINITION LAYER)
-- NO EXECUTION / NO LOGS / NO RUNTIME STATE / NO API CALLS
-- =====================================================
--
-- SSOT HIERARCHY
-- integration_providers     — catalog (display names, seeded from enum)
-- integration_capabilities  — what each provider supports
-- tenant_integrations       — tenant-level connection config (one per provider)
-- device_integration_map    — device external IDs only (005)
-- webhook_definitions       — outbound subscription targets (NOT inbound ingest)
--
-- CREDENTIALS: use credentials_ref / signing_secret_ref → vault (000). Never secrets in jsonb.
-- EXECUTION: platform.integration_queue, external_webhooks, pg_net (000 only).
-- OVERLAP: 004.lock_devices = lock role; 002.service_accounts = machine identity label.
-- =====================================================

-- =====================================================
-- 1. INTEGRATION PROVIDERS (CATALOG REGISTRY)
-- =====================================================

create table if not exists integration_providers (
    id uuid primary key default gen_random_uuid(),

    name integration_provider not null,

    display_name text,

    is_active boolean default true,

    created_at timestamptz default now(),

    unique (name)
);

-- =====================================================
-- 2. TENANT INTEGRATIONS (CONNECTION CONFIG ONLY)
-- =====================================================

create table if not exists tenant_integrations (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider integration_provider not null,

    credentials_ref text,

    config jsonb not null default '{}'::jsonb,

    is_enabled boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (tenant_id, provider)
);

create index if not exists idx_tenant_integrations_tenant
on tenant_integrations (tenant_id);

create index if not exists idx_tenant_integrations_tenant_created
on tenant_integrations (tenant_id, created_at desc);

comment on table public.tenant_integrations is
    'Tenant-level provider connection. One row per tenant per provider.';

comment on column public.tenant_integrations.credentials_ref is
    'Vault secret name for API keys, OAuth tokens, webhook secrets. Never store secrets in config.';

comment on column public.tenant_integrations.config is
    'Non-secret settings only: base URL, account IDs, feature flags, environment.';

create trigger trg_tenant_integrations_updated_at
before update on tenant_integrations
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. OUTBOUND WEBHOOK DEFINITIONS (SUBSCRIPTION TARGETS ONLY)
-- Inbound webhook ingest lives in platform.external_webhooks (000).
-- =====================================================

create table if not exists webhook_definitions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider integration_provider not null,

    event_type text not null,

    target_url text not null,

    signing_secret_ref text,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_webhook_definitions_tenant
on webhook_definitions (tenant_id);

create index if not exists idx_webhook_definitions_provider
on webhook_definitions (provider);

create index if not exists idx_webhook_definitions_tenant_provider
on webhook_definitions (tenant_id, provider);

comment on table public.webhook_definitions is
    'Outbound webhook subscription targets. Delivery executed via platform.integration_queue (000).';

comment on column public.webhook_definitions.signing_secret_ref is
    'Vault ref for HMAC/signing secret used when dispatching to target_url.';

create trigger trg_webhook_definitions_updated_at
before update on webhook_definitions
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. INTEGRATION CAPABILITIES (WHAT EACH PROVIDER CAN DO)
-- =====================================================

create table if not exists integration_capabilities (
    id uuid primary key default gen_random_uuid(),

    provider integration_provider not null,

    capability text not null,

    is_supported boolean default true,

    unique (provider, capability)
);

create index if not exists idx_integration_capabilities_provider
on integration_capabilities (provider);

-- =====================================================
-- 5. DEVICE INTEGRATION MAPPING (EXTERNAL ID ONLY)
-- Provider credentials live in tenant_integrations; lock role in 004.lock_devices.
-- =====================================================

create table if not exists device_integration_map (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    provider integration_provider not null,

    external_id text not null,

    config jsonb default '{}'::jsonb,

    created_at timestamptz default now(),

    unique (device_id, provider)
);

create index if not exists idx_device_integration_device
on device_integration_map (device_id);

create index if not exists idx_device_integration_provider
on device_integration_map (provider, external_id);

comment on table public.device_integration_map is
    'Maps domain devices to provider external IDs. No credentials or runtime state.';

comment on column public.device_integration_map.config is
    'Non-secret device mapping metadata only (endpoint paths, entity IDs).';

-- =====================================================
-- 5B. DEVICE INTEGRATION TENANT CONSISTENCY
-- =====================================================

create or replace function public.enforce_device_integration_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if not exists (
        select 1
        from public.devices d
        where d.id = new.device_id
    ) then
        raise exception 'device not found';
    end if;

    if new.external_id is null or btrim(new.external_id) = '' then
        raise exception 'external_id is required for device integration mapping';
    end if;

    return new;
end;
$$;

create trigger trg_device_integration_consistency
before insert or update on public.device_integration_map
for each row execute function public.enforce_device_integration_consistency();

-- =====================================================
-- 6. PROVIDER CATALOG SEED (DEFINITION DATA ONLY)
-- =====================================================

insert into integration_providers (name, display_name)
select v.name, v.display_name
from (
    values
        ('aqara'::integration_provider, 'Aqara'),
        ('ttlock'::integration_provider, 'TTLock'),
        ('shelly'::integration_provider, 'Shelly'),
        ('beds24'::integration_provider, 'Beds24'),
        ('stripe'::integration_provider, 'Stripe'),
        ('vivawallet'::integration_provider, 'VivaWallet'),
        ('zoho'::integration_provider, 'Zoho'),
        ('home_assistant'::integration_provider, 'Home Assistant'),
        ('generic'::integration_provider, 'Generic')
) as v(name, display_name)
where not exists (
    select 1
    from integration_providers ip
    where ip.name = v.name
);

insert into integration_capabilities (provider, capability)
select v.provider, v.capability
from (
    values
        ('aqara'::integration_provider, 'send_command'),
        ('aqara', 'receive_event'),
        ('aqara', 'sync_state'),
        ('ttlock', 'send_command'),
        ('ttlock', 'receive_event'),
        ('ttlock', 'create_user'),
        ('shelly', 'send_command'),
        ('shelly', 'receive_event'),
        ('beds24', 'receive_event'),
        ('beds24', 'sync_state'),
        ('stripe', 'receive_event'),
        ('stripe', 'sync_state'),
        ('vivawallet', 'receive_event'),
        ('vivawallet', 'sync_state'),
        ('zoho', 'send_command'),
        ('zoho', 'receive_event'),
        ('home_assistant', 'send_command'),
        ('home_assistant', 'receive_event'),
        ('home_assistant', 'sync_state'),
        ('generic', 'send_command'),
        ('generic', 'receive_event')
) as v(provider, capability)
where not exists (
    select 1
    from integration_capabilities ic
    where ic.provider = v.provider
      and ic.capability = v.capability
);

-- =====================================================
-- 7. TENANT FKs (DEFERRED — TENANTS EXIST FROM 002)
-- =====================================================

do $$
begin
    alter table public.tenant_integrations
        add constraint fk_tenant_integrations_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.webhook_definitions
        add constraint fk_webhook_definitions_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 8. CHILD-TABLE RLS (device_integration_map — NO tenant_id)
-- tenant_integrations + webhook_definitions → 014 bootstrap
-- =====================================================

alter table public.device_integration_map enable row level security;

drop policy if exists device_integration_map_select on public.device_integration_map;
drop policy if exists device_integration_map_insert on public.device_integration_map;
drop policy if exists device_integration_map_update on public.device_integration_map;
drop policy if exists device_integration_map_delete on public.device_integration_map;

create policy device_integration_map_select on public.device_integration_map
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_integration_map_insert on public.device_integration_map
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_integration_map_update on public.device_integration_map
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

create policy device_integration_map_delete on public.device_integration_map
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
        )
    );

-- =====================================================
-- END 005 INTEGRATION ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
