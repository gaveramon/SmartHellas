-- =====================================================
-- 005 INTEGRATION ENGINE (REV19)
-- CLEAN DOMAIN LAYER — NO EXECUTION — NO RUNTIME STATE
-- =====================================================
--
-- SSOT: integration_providers catalog (code is stable identifier)
-- Domain tables use provider_code text → integration_providers(code)
-- Credentials: credentials_ref / signing_secret_ref → vault (000)
-- =====================================================

-- =====================================================
-- 1. INTEGRATION PROVIDERS (CATALOG / SSOT)
-- =====================================================

create table if not exists public.integration_providers (

    id uuid primary key default gen_random_uuid(),

    code text not null,

    name text not null,

    category integration_provider_category not null,

    description text,

    website text,

    documentation_url text,

    api_version text,

    is_system boolean not null default true,

    is_active boolean not null default true,

    supports_webhooks boolean not null default false,

    supports_oauth boolean not null default false,

    supports_polling boolean not null default false,

    supports_push boolean not null default false,

    supports_real_time boolean not null default false,

    valid_from timestamptz not null default now(),

    valid_until timestamptz,

    configuration_schema jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint uq_integration_providers_code unique (code)
);

create index if not exists idx_integration_providers_active
    on public.integration_providers (is_active);

create index if not exists idx_integration_providers_category
    on public.integration_providers (category);

comment on table public.integration_providers is
    'Integration provider catalog. code is the stable FK target for provider_code columns.';

create trigger trg_integration_providers_updated_at
before update on public.integration_providers
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. TENANT INTEGRATIONS (CONNECTION CONFIG ONLY)
-- =====================================================

create table if not exists public.tenant_integrations (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider_code text not null,

    credentials_ref text,

    config jsonb not null default '{}'::jsonb,

    is_enabled boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint uq_tenant_provider unique (tenant_id, provider_code)
);

create index if not exists idx_tenant_integrations_tenant
    on public.tenant_integrations (tenant_id);

create index if not exists idx_tenant_integrations_tenant_created
    on public.tenant_integrations (tenant_id, created_at desc);

create index if not exists idx_tenant_integrations_provider
    on public.tenant_integrations (provider_code);

comment on column public.tenant_integrations.credentials_ref is
    'Vault secret name. Never store secrets in config.';

create trigger trg_tenant_integrations_updated_at
before update on public.tenant_integrations
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. WEBHOOK DEFINITIONS (OUTBOUND ONLY)
-- =====================================================

create table if not exists public.webhook_definitions (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    provider_code text not null,

    event_type text not null,

    target_url text not null,

    signing_secret_ref text,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create index if not exists idx_webhook_definitions_tenant
    on public.webhook_definitions (tenant_id);

create index if not exists idx_webhook_definitions_tenant_created
    on public.webhook_definitions (tenant_id, created_at desc);

create index if not exists idx_webhook_definitions_provider
    on public.webhook_definitions (provider_code);

create index if not exists idx_webhook_definitions_tenant_provider
    on public.webhook_definitions (tenant_id, provider_code);

comment on table public.webhook_definitions is
    'Outbound webhook subscription targets. Inbound ingest lives in platform.external_webhooks (000).';

create trigger trg_webhook_definitions_updated_at
before update on public.webhook_definitions
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. INTEGRATION CAPABILITIES (PROVIDER FEATURES)
-- =====================================================

create table if not exists public.integration_capabilities (

    id uuid primary key default gen_random_uuid(),

    provider_code text not null,

    capability_code text not null,

    description text,

    is_supported boolean not null default true,

    created_at timestamptz not null default now(),

    constraint uq_provider_capability
        unique (provider_code, capability_code)
);

create index if not exists idx_capabilities_provider
    on public.integration_capabilities (provider_code);

-- =====================================================
-- 5. DEVICE INTEGRATION MAPPING (NO STATE, ONLY EXTERNAL IDS)
-- =====================================================

create table if not exists public.device_integration_map (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    device_id uuid not null references public.devices(id) on delete cascade,

    provider_code text not null,

    external_id text not null,

    config jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now(),

    constraint uq_device_provider unique (device_id, provider_code)
);

create index if not exists idx_device_integration_device
    on public.device_integration_map (device_id);

create index if not exists idx_device_integration_tenant
    on public.device_integration_map (tenant_id);

create index if not exists idx_device_integration_provider
    on public.device_integration_map (provider_code);

create unique index if not exists uq_device_integration_tenant_provider_external
    on public.device_integration_map (tenant_id, provider_code, external_id);

comment on table public.device_integration_map is
    'Maps domain devices to provider external IDs. No credentials or runtime state.';

-- =====================================================
-- 6. CONSISTENCY FUNCTION (MINIMAL VALIDATION ONLY)
-- =====================================================

create or replace function public.enforce_device_integration_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
begin

    if new.external_id is null or btrim(new.external_id) = '' then
        raise exception 'external_id required';
    end if;

    select d.tenant_id
    into new.tenant_id
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    return new;

end;
$$;

create trigger trg_device_integration_consistency
before insert or update on public.device_integration_map
for each row execute function public.enforce_device_integration_consistency();

-- =====================================================
-- 7. INTEGRATION PROVIDERS SEED (CATALOG SSOT)
-- =====================================================

insert into public.integration_providers (
    code,
    name,
    category,
    valid_from,
    supports_webhooks,
    supports_oauth
)
values
    ('aqara', 'Aqara', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('ttlock', 'TTLock', 'lock', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('shelly', 'Shelly', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('beds24', 'Beds24', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('stripe', 'Stripe', 'payment', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('vivawallet', 'Viva Wallet', 'payment', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('zoho', 'Zoho', 'crm', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('home_assistant', 'Home Assistant', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('generic', 'Generic', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('airbnb', 'Airbnb', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('booking', 'Booking.com', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('expedia', 'Expedia', 'ota', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('pricelabs', 'PriceLabs', 'pricing', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('hostaway', 'Hostaway', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('guesty', 'Guesty', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('smoobu', 'Smoobu', 'pms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('mailgun', 'Mailgun', 'email', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('postmark', 'Postmark', 'email', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('smtp', 'SMTP', 'email', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('twilio', 'Twilio', 'sms', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('whatsapp', 'WhatsApp', 'messaging', '2026-01-01 00:00:00+00'::timestamptz, true, true),
    ('firebase', 'Firebase', 'notification', '2026-01-01 00:00:00+00'::timestamptz, true, false),
    ('openai', 'OpenAI', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('openrouter', 'OpenRouter', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false),
    ('anthropic', 'Anthropic', 'ai', '2026-01-01 00:00:00+00'::timestamptz, false, false)
on conflict (code)
do update set
    name = excluded.name,
    category = excluded.category,
    supports_webhooks = excluded.supports_webhooks,
    supports_oauth = excluded.supports_oauth,
    valid_from = excluded.valid_from,
    updated_at = now();

insert into public.integration_capabilities (
    provider_code,
    capability_code,
    is_supported
)
values
    ('aqara', 'send_command', true),
    ('aqara', 'receive_event', true),
    ('ttlock', 'send_command', true),
    ('ttlock', 'create_user', true),
    ('shelly', 'receive_event', true),
    ('beds24', 'sync_state', true),
    ('stripe', 'receive_event', true),
    ('zoho', 'send_command', true),
    ('home_assistant', 'sync_state', true),
    ('generic', 'send_command', true)
on conflict (provider_code, capability_code)
do nothing;

-- =====================================================
-- 8. FOREIGN KEYS (PROVIDER + TENANT SSOT)
-- =====================================================

do $$
begin
    alter table public.tenant_integrations
        add constraint fk_tenant_integrations_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.webhook_definitions
        add constraint fk_webhook_definitions_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.tenant_integrations
        add constraint fk_tenant_integrations_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.webhook_definitions
        add constraint fk_webhook_definitions_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.integration_capabilities
        add constraint fk_integration_capabilities_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.device_integration_map
        add constraint fk_device_integration_map_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.device_integration_map
        add constraint fk_device_integration_map_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.service_accounts
        add constraint fk_service_accounts_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.access_credentials
        add constraint fk_access_credentials_provider_code
        foreign key (provider_code) references public.integration_providers(code);
exception when duplicate_object then null;
end $$;

-- =====================================================
-- 9. RLS
-- =====================================================

alter table public.integration_providers enable row level security;

drop policy if exists integration_providers_select on public.integration_providers;
drop policy if exists integration_providers_write on public.integration_providers;

create policy integration_providers_select on public.integration_providers
    for select to authenticated
    using (true);

create policy integration_providers_write on public.integration_providers
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

alter table public.integration_capabilities enable row level security;

drop policy if exists integration_capabilities_select on public.integration_capabilities;
drop policy if exists integration_capabilities_write on public.integration_capabilities;

create policy integration_capabilities_select on public.integration_capabilities
    for select to authenticated
    using (true);

create policy integration_capabilities_write on public.integration_capabilities
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());

alter table public.tenant_integrations enable row level security;

drop policy if exists tenant_integrations_select on public.tenant_integrations;
drop policy if exists tenant_integrations_insert on public.tenant_integrations;
drop policy if exists tenant_integrations_update on public.tenant_integrations;
drop policy if exists tenant_integrations_delete on public.tenant_integrations;

create policy tenant_integrations_select on public.tenant_integrations
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy tenant_integrations_insert on public.tenant_integrations
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy tenant_integrations_update on public.tenant_integrations
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy tenant_integrations_delete on public.tenant_integrations
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.webhook_definitions enable row level security;

drop policy if exists webhook_definitions_select on public.webhook_definitions;
drop policy if exists webhook_definitions_insert on public.webhook_definitions;
drop policy if exists webhook_definitions_update on public.webhook_definitions;
drop policy if exists webhook_definitions_delete on public.webhook_definitions;

create policy webhook_definitions_select on public.webhook_definitions
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy webhook_definitions_insert on public.webhook_definitions
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy webhook_definitions_update on public.webhook_definitions
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy webhook_definitions_delete on public.webhook_definitions
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

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
              and (platform.is_admin() or platform.has_role('manager'))
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
              and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.devices d
            where d.id = device_integration_map.device_id
              and public.has_tenant_access(d.tenant_id)
              and (platform.is_admin() or platform.has_role('manager'))
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
              and (platform.is_admin() or platform.has_role('manager'))
        )
    );

-- =====================================================
-- END 005 INTEGRATION ENGINE (REV19)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('005_integration_engine_rev19', 'REV19.INTEGRATION', false)
on conflict (version) do nothing;
