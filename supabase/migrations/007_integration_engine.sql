-- REV22 greenfield baseline: 007_integration_engine.sql
-- Consolidated from migrations_archive_rev19 (000-053)


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


-- =====================================================
-- 2. INTEGRATION CAPABILITIES (PROVIDER FEATURES)
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


-- =====================================================
-- 3. TENANT INTEGRATIONS (CONNECTION CONFIG ONLY)
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


-- =====================================================
-- 4. WEBHOOK DEFINITIONS (OUTBOUND ONLY)
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


-- =====================================================
-- 5. DEVICE INTEGRATION MAPPING (NO STATE, ONLY EXTERNAL IDS)
-- =====================================================

create table if not exists public.device_integration_map (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    device_id uuid not null references public.devices(id) on delete cascade,

    hardware_id text,
  
    provider_code text not null,

    external_id text not null,

    config jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now(),

    constraint uq_device_provider unique (device_id, provider_code)
);


-- =====================================================
-- 6. INTEGRATION OAUTH STATE (SSOT)
-- =====================================================

create table if not exists public.integration_oauth_states (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants(id),
    user_id uuid not null,
    provider_code text not null,
    state_token text not null,
    expires_at timestamptz not null,
    consumed_at timestamptz,
    created_at timestamptz not null default now(),
    constraint integration_oauth_states_state_token_key unique (state_token)
);

create index if not exists integration_oauth_states_pending_idx
    on public.integration_oauth_states (expires_at)
    where consumed_at is null;


-- =====================================================
-- 7. INTEGRATION WEBHOOK MAPPINGS
-- =====================================================

-- =====================================================
-- 7.1 WEBHOOK PAYLOAD MAPPINGS
--
-- Responsibility:
-- - Define how provider webhook payloads map to
--   integration-domain identifiers.
--
-- This is configuration / mapping metadata.
-- It is NOT device state and NOT telemetry.
--
-- 000 must never inspect these mappings.
-- 007 owns their interpretation.
-- =====================================================

create table if not exists public.integration_webhook_mappings (

    id uuid primary key default gen_random_uuid(),

    provider_code text not null
        references public.integration_providers(code),

    event_type text not null,

    mapping_code text not null,

    payload_path text[] not null,

    value_type text not null default 'text',

    is_required boolean not null default true,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint uq_integration_webhook_mapping
        unique (
            provider_code,
            event_type,
            mapping_code
        )
);

comment on column public.device_integration_map.hardware_id is
    'Stable provider-side hardware identity used to reconcile changing external provider identifiers. Provider-agnostic.';


comment on column public.device_integration_map.external_id is
    'Current provider-side device identifier. May change when the provider reassigns or recreates the external identity.';


comment on table public.device_integration_map is
    'Provider device identity mapping. external_id is the current provider identifier; hardware_id is the stable provider hardware identity. No device state, telemetry or credentials.';


-- =====================================================
-- 8. PROVIDER AND CAPABILITY SEED DATA
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
    ('aqara', 'Aqara', 'smarthome', '2026-01-01 00:00:00+00'::timestamptz, true, false),
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
    ('ttlock', 'receive_event', true),
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
-- 9. WEBHOOK MAPPING SEED DATA
-- =====================================================

-- =====================================================
-- 9.1 AQARA WEBHOOK MAPPINGS
--
-- 007 Integration Engine
--
-- These mappings describe the Aqara message contract.
-- No provider-specific CASE logic is required in the
-- webhook processor.
-- =====================================================

insert into public.integration_webhook_mappings (
    provider_code,
    event_type,
    mapping_code,
    payload_path,
    value_type,
    is_required,
    is_active
)
values

    -- -------------------------------------------------
    -- Aqara device attribute messages
    -- -------------------------------------------------

    (
        'aqara',
        'resource_report',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'resource_report',
        'device_external_id',
        array['subjectId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'resource_report',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    ),


    -- -------------------------------------------------
    -- Aqara device control failure
    -- -------------------------------------------------

    (
        'aqara',
        'control_fail',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'control_fail',
        'device_external_id',
        array['subjectId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'control_fail',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    ),


    -- -------------------------------------------------
    -- Aqara device lifecycle events
    -- -------------------------------------------------

    (
        'aqara',
        'subdevice_online',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'subdevice_online',
        'device_external_id',
        array['did'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'subdevice_online',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    ),

    (
        'aqara',
        'subdevice_offline',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'subdevice_offline',
        'device_external_id',
        array['did'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'subdevice_offline',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    ),


    -- -------------------------------------------------
    -- Gateway lifecycle events
    -- -------------------------------------------------

    (
        'aqara',
        'gateway_online',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'gateway_online',
        'device_external_id',
        array['did'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'gateway_online',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    ),

    (
        'aqara',
        'gateway_offline',
        'provider_event_id',
        array['msgId'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'gateway_offline',
        'device_external_id',
        array['did'],
        'text',
        true,
        true
    ),

    (
        'aqara',
        'gateway_offline',
        'observed_at',
        array['time'],
        'epoch_milliseconds',
        true,
        true
    )

on conflict (
    provider_code,
    event_type,
    mapping_code
)
do update set
    payload_path = excluded.payload_path,
    value_type = excluded.value_type,
    is_required = excluded.is_required,
    is_active = excluded.is_active,
    updated_at = now();


-- =====================================================
-- 9.2 SHELLY WEBHOOK MAPPINGS
--
-- 007 Integration Engine
--
-- Shelly webhook payloads use different paths and
-- timestamps than Aqara/TTLock.
-- =====================================================

insert into public.integration_webhook_mappings (
    provider_code,
    event_type,
    mapping_code,
    payload_path,
    value_type,
    is_required,
    is_active
)
values

    -- -------------------------------------------------
    -- Temperature
    -- -------------------------------------------------

    (
        'shelly',
        'temperature.change',
        'device_external_id',
        array['info','mac'],
        'text',
        true,
        true
    ),

    (
        'shelly',
        'temperature.change',
        'temperature',
        array['ev','tC'],
        'text',
        true,
        true
    ),

    -- -------------------------------------------------
    -- Humidity
    -- -------------------------------------------------

    (
        'shelly',
        'humidity.change',
        'device_external_id',
        array['info','mac'],
        'text',
        true,
        true
    ),

    (
        'shelly',
        'humidity.change',
        'humidity',
        array['ev','rh'],
        'text',
        true,
        true
    )

on conflict (
    provider_code,
    event_type,
    mapping_code
)
do update set
    payload_path = excluded.payload_path,
    value_type = excluded.value_type,
    is_required = excluded.is_required,
    is_active = excluded.is_active,
    updated_at = now();


-- =====================================================
-- 9.3 TTLOCK WEBHOOK / RECORD MAPPINGS
--
-- 007 Integration Engine
--
-- TTLock records are normally obtained through the
-- TTLock API rather than native push webhooks.
--
-- These mappings are intended for the normalized raw
-- event representation created by the TTLock integration
-- worker.
-- =====================================================

insert into public.integration_webhook_mappings (
    provider_code,
    event_type,
    mapping_code,
    payload_path,
    value_type,
    is_required,
    is_active
)
values

    -- -------------------------------------------------
    -- DEVICE
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'device_external_id',
        array['lockId'],
        'text',
        true,
        true
    ),

    -- -------------------------------------------------
    -- EVENT
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'record_type',
        array['recordType'],
        'text',
        true,
        true
    ),

    (
        'ttlock',
        'lock.record',
        'success',
        array['success'],
        'text',
        true,
        true
    ),

    -- -------------------------------------------------
    -- ACTOR
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'username',
        array['username'],
        'text',
        false,
        true
    ),

    -- -------------------------------------------------
    -- PASSCODE / CREDENTIAL
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'credential',
        array['keyboardPwd'],
        'text',
        false,
        true
    ),

    -- -------------------------------------------------
    -- EVENT TIMESTAMP
    --
    -- TTLock uses Unix epoch milliseconds.
    -- This becomes device_telemetry_raw.observed_at.
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'observed_at',
        array['lockDate'],
        'epoch_milliseconds',
        true,
        true
    ),

    -- -------------------------------------------------
    -- SERVER TIMESTAMP
    --
    -- Also Unix epoch milliseconds.
    -- -------------------------------------------------

    (
        'ttlock',
        'lock.record',
        'server_at',
        array['serverDate'],
        'epoch_milliseconds',
        false,
        true
    )

on conflict (
    provider_code,
    event_type,
    mapping_code
)
do update set
    payload_path = excluded.payload_path,
    value_type = excluded.value_type,
    is_required = excluded.is_required,
    is_active = excluded.is_active,
    updated_at = now();


-- =====================================================
-- 10. INDEXES AND TABLE COMMENTS
-- =====================================================

create index if not exists idx_integration_providers_active
    on public.integration_providers (is_active);



create index if not exists idx_device_integration_hardware
    on public.device_integration_map (tenant_id, provider_code, hardware_id)
      where hardware_id is not null;



create index if not exists idx_integration_providers_category
    on public.integration_providers (category);



comment on table public.integration_providers is
    'Integration provider catalog. code is the stable FK target for provider_code columns.';



create index if not exists idx_tenant_integrations_tenant
    on public.tenant_integrations (tenant_id);



create index if not exists idx_tenant_integrations_tenant_created
    on public.tenant_integrations (tenant_id, created_at desc);



create index if not exists idx_tenant_integrations_provider
    on public.tenant_integrations (provider_code);



comment on column public.tenant_integrations.credentials_ref is
    'Vault secret name. Never store secrets in config.';



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



create index if not exists idx_capabilities_provider
    on public.integration_capabilities (provider_code);



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
-- HARDWARE IDENTITY UNIQUENESS
--
-- One physical provider device may not map to multiple
-- SmartHellas devices within the same tenant/provider.
-- =====================================================

create unique index if not exists uq_device_integration_tenant_provider_hardware
    on public.device_integration_map (tenant_id, provider_code, hardware_id)
        where hardware_id is not null;


-- =====================================================
-- 11. FOREIGN KEYS (PROVIDER + TENANT SSOT)
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
-- 12. RLS CONFIGURATION
-- =====================================================

alter table public.integration_providers enable row level security;



drop policy if exists integration_providers_select on public.integration_providers;


drop policy if exists integration_providers_write on public.integration_providers;



alter table public.integration_capabilities enable row level security;



drop policy if exists integration_capabilities_select on public.integration_capabilities;


drop policy if exists integration_capabilities_write on public.integration_capabilities;



alter table public.tenant_integrations enable row level security;



drop policy if exists tenant_integrations_select on public.tenant_integrations;


drop policy if exists tenant_integrations_insert on public.tenant_integrations;


drop policy if exists tenant_integrations_update on public.tenant_integrations;


drop policy if exists tenant_integrations_delete on public.tenant_integrations;



alter table public.webhook_definitions enable row level security;



drop policy if exists webhook_definitions_select on public.webhook_definitions;


drop policy if exists webhook_definitions_insert on public.webhook_definitions;


drop policy if exists webhook_definitions_update on public.webhook_definitions;


drop policy if exists webhook_definitions_delete on public.webhook_definitions;



alter table public.device_integration_map enable row level security;



drop policy if exists device_integration_map_select on public.device_integration_map;


drop policy if exists device_integration_map_insert on public.device_integration_map;


drop policy if exists device_integration_map_update on public.device_integration_map;


drop policy if exists device_integration_map_delete on public.device_integration_map;



-- =====================================================
-- 13. RLS POLICIES
-- =====================================================

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



create policy integration_capabilities_select on public.integration_capabilities
    for select to authenticated
    using (true);



create policy integration_capabilities_write on public.integration_capabilities
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());



create policy integration_providers_select on public.integration_providers
    for select to authenticated
    using (true);



create policy integration_providers_write on public.integration_providers
    for all to authenticated
    using (platform.is_platform_admin())
    with check (platform.is_platform_admin());



create policy tenant_integrations_delete on public.tenant_integrations
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy tenant_integrations_insert on public.tenant_integrations
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy tenant_integrations_select on public.tenant_integrations
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



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



create policy webhook_definitions_delete on public.webhook_definitions
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy webhook_definitions_insert on public.webhook_definitions
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy webhook_definitions_select on public.webhook_definitions
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



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


-- =====================================================
-- 14. OAUTH STATE RLS
-- Tenant-scoped OAuth state
--
-- Tenant authority:
-- public.resolve_active_tenant(auth.uid())
--
-- RLS compatibility shim:
-- platform.has_tenant_access(tenant_id)
-- =====================================================

alter table public.integration_oauth_states
    enable row level security;

alter table public.integration_oauth_states
    force row level security;


drop policy if exists integration_oauth_states_select
    on public.integration_oauth_states;

drop policy if exists integration_oauth_states_insert
    on public.integration_oauth_states;

drop policy if exists integration_oauth_states_update
    on public.integration_oauth_states;

drop policy if exists integration_oauth_states_delete
    on public.integration_oauth_states;


create policy integration_oauth_states_select
on public.integration_oauth_states
for select
to authenticated
using (
    platform.has_tenant_access(tenant_id)
);


create policy integration_oauth_states_insert
on public.integration_oauth_states
for insert
to authenticated
with check (
    platform.has_tenant_access(tenant_id)
);


create policy integration_oauth_states_update
on public.integration_oauth_states
for update
to authenticated
using (
    platform.has_tenant_access(tenant_id)
)
with check (
    platform.has_tenant_access(tenant_id)
);


-- =====================================================
-- 15. INTEGRATION DEVICE CONSISTENCY
-- =====================================================

-- -----------------------------------------------------
-- 007 Integrations: enforce active-tenant ownership on device-map writes
-- -----------------------------------------------------

create or replace function public.enforce_device_integration_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_tid uuid;
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

    if not platform.is_platform_admin() then
        v_tid := platform.current_tenant_id();
        if v_tid is null then
            raise exception 'no active tenant';
        end if;
        if new.tenant_id is distinct from v_tid then
            raise exception 'device does not belong to active tenant';
        end if;
    end if;

    return new;
end;
$$;


-- =====================================================
-- 16. TRIGGERS
-- =====================================================

create trigger trg_integration_providers_updated_at
before update on public.integration_providers
for each row execute function platform.set_updated_at();



create trigger trg_tenant_integrations_updated_at
before update on public.tenant_integrations
for each row execute function platform.set_updated_at();



create trigger trg_webhook_definitions_updated_at
before update on public.webhook_definitions
for each row execute function platform.set_updated_at();



create trigger trg_device_integration_consistency
before insert or update on public.device_integration_map
for each row execute function public.enforce_device_integration_consistency();


-- =====================================================
-- 17. WEBHOOK MAPPING RESOLUTION
-- =====================================================

create or replace function public.resolve_integration_webhook_mapping(
    p_provider_code text,
    p_event_type text,
    p_mapping_code text,
    p_payload jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_path text[];
    v_value text;
    v_value_type text;
begin

    if p_provider_code is null then
        raise exception 'provider_code is required';
    end if;

    if p_event_type is null then
        raise exception 'event_type is required';
    end if;

    if p_mapping_code is null then
        raise exception 'mapping_code is required';
    end if;

    if p_payload is null then
        return null;
    end if;

    select
        m.payload_path,
        m.value_type
    into
        v_path,
        v_value_type
    from public.integration_webhook_mappings m
    where m.provider_code = p_provider_code
      and (
            m.event_type = p_event_type
            or (
                m.event_type like '%*'
                and p_event_type like replace(m.event_type, '*', '%')
            )
          )
      and m.mapping_code = p_mapping_code
      and m.is_active = true
    order by
        case
            when m.event_type = p_event_type then 0
            else 1
        end,
        length(m.event_type) desc
    limit 1;

    if not found then
        return null;
    end if;

    v_value := p_payload #>> v_path;

    if v_value is null or btrim(v_value) = '' then
        return null;
    end if;

    v_value := btrim(v_value);

    case coalesce(v_value_type, 'text')

        when 'text' then
            return v_value;

        when 'uuid' then
            return v_value;

        when 'timestamptz' then
            return v_value;

        when 'epoch_seconds' then
            return extract(
                epoch from to_timestamp(v_value::double precision)
            )::text;

        when 'epoch_milliseconds' then
            return extract(
                epoch from to_timestamp(
                    v_value::double precision / 1000.0
                )
            )::text;

        else
            raise exception
                'Unsupported integration webhook mapping value_type: %',
                v_value_type;

    end case;

exception
    when invalid_text_representation then
        raise exception
            'Invalid value for mapping %, provider %, event %: %',
            p_mapping_code,
            p_provider_code,
            p_event_type,
            v_value;

end;
$$;



-- =====================================================
-- GENERIC PROVIDER DEVICE LOOKUP
-- =====================================================

create or replace function public.resolve_provider_device_by_external_id(
    p_tenant_id uuid,
    p_provider_code text,
    p_external_id text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select dim.device_id
    from public.device_integration_map dim
    where dim.tenant_id = p_tenant_id
      and dim.provider_code = p_provider_code
      and dim.external_id = p_external_id
    limit 1;
$$;


revoke all on function public.resolve_provider_device_by_external_id(
    uuid,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.resolve_provider_device_by_external_id(
    uuid,
    text,
    text
)
to service_role;


comment on function public.resolve_provider_device_by_external_id(
    uuid,
    text,
    text
) is
    'Generic provider device lookup by current external provider identifier.';


-- =====================================================
-- GENERIC PROVIDER HARDWARE LOOKUP
-- =====================================================

create or replace function public.resolve_provider_device_by_hardware_id(
    p_tenant_id uuid,
    p_provider_code text,
    p_hardware_id text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select dim.device_id
    from public.device_integration_map dim
    where dim.tenant_id = p_tenant_id
      and dim.provider_code = p_provider_code
      and dim.hardware_id = p_hardware_id
    limit 1;
$$;


revoke all on function public.resolve_provider_device_by_hardware_id(
    uuid,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.resolve_provider_device_by_hardware_id(
    uuid,
    text,
    text
)
to service_role;


comment on function public.resolve_provider_device_by_hardware_id(
    uuid,
    text,
    text
) is
    'Generic provider device lookup by stable provider hardware identity.';


-- =====================================================
-- GENERIC PROVIDER DEVICE RECONCILIATION
--
-- Purpose:
-- Replace the current provider external_id when the
-- provider-side identifier changes.
--
-- Example:
--
-- old external_id = OLD123
-- hardware_id     = HW001
--
-- provider reports:
--
-- new external_id = NEW456
-- hardware_id     = HW001
--
-- Result:
--
-- external_id = NEW456
-- hardware_id = HW001
--
-- device_id remains unchanged.
-- =====================================================

create or replace function public.reconcile_provider_device(
    p_tenant_id uuid,
    p_provider_code text,
    p_external_id text,
    p_hardware_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_map_id uuid;
    v_device_id uuid;
    v_previous_external_id text;
begin

    if p_tenant_id is null then
        raise exception
            'tenant_id is required';
    end if;

    if p_provider_code is null
       or btrim(p_provider_code) = '' then
        raise exception
            'provider_code is required';
    end if;

    if p_external_id is null
       or btrim(p_external_id) = '' then
        raise exception
            'external_id is required';
    end if;

    if p_hardware_id is null
       or btrim(p_hardware_id) = '' then
        raise exception
            'hardware_id is required';
    end if;


    -- =================================================
    -- FIND EXISTING PHYSICAL DEVICE
    -- =================================================

    select
        dim.id,
        dim.device_id,
        dim.external_id
    into
        v_map_id,
        v_device_id,
        v_previous_external_id
    from public.device_integration_map dim
    where dim.tenant_id = p_tenant_id
      and dim.provider_code = p_provider_code
      and dim.hardware_id = p_hardware_id
    for update;


    if not found then

        raise exception
            'No provider device mapping found for provider % and hardware identity %',
            p_provider_code,
            p_hardware_id;

    end if;


    -- =================================================
    -- PROTECT AGAINST CROSS-DEVICE COLLISION
    --
    -- The new external ID may not already belong to a
    -- different SmartHellas device.
    -- =================================================

    if exists (
        select 1
        from public.device_integration_map dim
        where dim.tenant_id = p_tenant_id
          and dim.provider_code = p_provider_code
          and dim.external_id = p_external_id
          and dim.id <> v_map_id
    ) then

        raise exception
            'External provider identifier % already belongs to another device',
            p_external_id;

    end if;


    -- =================================================
    -- UPDATE CURRENT PROVIDER IDENTITY
    -- =================================================

    update public.device_integration_map
    set
        external_id = btrim(p_external_id)
    where id = v_map_id;


    -- =================================================
    -- AUDIT
    -- =================================================

    perform platform.log_audit(
        'provider.device_identity_reconciled',
        'device_integration_map',
        v_map_id,
        jsonb_build_object(
            'provider_code', p_provider_code,
            'device_id', v_device_id,
            'hardware_id', p_hardware_id,
            'previous_external_id', v_previous_external_id,
            'current_external_id', btrim(p_external_id)
        )
    );


    return jsonb_build_object(
        'reconciled', true,
        'device_map_id', v_map_id,
        'device_id', v_device_id,
        'provider_code', p_provider_code,
        'hardware_id', p_hardware_id,
        'previous_external_id', v_previous_external_id,
        'external_id', btrim(p_external_id)
    );

end;
$$;


revoke all on function public.reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
to service_role;


comment on function public.reconcile_provider_device(
    uuid,
    text,
    text,
    text
) is
    'Generic provider device identity reconciliation. Stable hardware identity resolves a device when the current provider external identifier changes.';






-- =====================================================
-- 18. INTEGRATION DOMAIN FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- 007 Integrations: domain authorization hardening
-- -----------------------------------------------------

create or replace function public.integrations_domain(
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
    v_row record;
    v_result jsonb;
    v_existing uuid;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'list_providers' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.name), '[]'::jsonb) into v_result
        from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.is_active = true
        ) t;

    when 'get_provider' then
        select to_jsonb(t) into v_result from (
            select ip.code, ip.name, ip.category, ip.description, ip.supports_webhooks, ip.supports_oauth,
                   ip.supports_polling, ip.is_active, ip.configuration_schema
            from public.integration_providers ip where ip.code = p_payload->>'code'
        ) t;
        if v_result is null then raise exception 'Integration provider not found'; end if;

    when 'list_capabilities' then
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ic.provider_code, ic.capability_code, ic.description, ic.is_supported
            from public.integration_capabilities ic
            where ic.is_supported = true
              and (p_payload->>'provider_code' is null or ic.provider_code = p_payload->>'provider_code')
        ) t;

    when 'list_tenant_integrations' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.provider_code), '[]'::jsonb) into v_result
        from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti where ti.tenant_id = v_tid
        ) t;

    when 'get_tenant_integration' then
        v_tid := platform.current_tenant_id();
        select to_jsonb(t) into v_result from (
            select ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at
            from public.tenant_integrations ti
            where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        ) t;

    when 'connect_integration' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        if not exists (select 1 from public.integration_providers ip where ip.code = p_payload->>'provider_code') then
            raise exception 'Integration provider not found';
        end if;
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if found then
            update public.tenant_integrations ti set
                credentials_ref = coalesce(p_payload->>'credentials_ref', ti.credentials_ref),
                config = coalesce(p_payload->'config', ti.config),
                is_enabled = coalesce((p_payload->>'is_enabled')::boolean, ti.is_enabled)
            where ti.id = v_existing
            returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
            perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id);
        else
            insert into public.tenant_integrations (tenant_id, provider_code, credentials_ref, config, is_enabled)
            values (
                v_tid, p_payload->>'provider_code', p_payload->>'credentials_ref',
                coalesce(p_payload->'config', '{}'::jsonb),
                coalesce((p_payload->>'is_enabled')::boolean, true)
            )
            returning id, tenant_id, provider_code, credentials_ref, config, is_enabled, created_at, updated_at into v_row;
            perform platform.log_audit('integration.connected', 'tenant_integration', v_row.id,
                jsonb_build_object('provider_code', p_payload->>'provider_code'));
        end if;
        v_result := to_jsonb(v_row);

    when 'update_integration' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        update public.tenant_integrations ti set
            credentials_ref = case when p_payload ? 'credentials_ref' then p_payload->>'credentials_ref' else ti.credentials_ref end,
            config = case when p_payload ? 'config' then p_payload->'config' else ti.config end,
            is_enabled = case when p_payload ? 'is_enabled' then (p_payload->>'is_enabled')::boolean else ti.is_enabled end
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
        returning ti.id, ti.tenant_id, ti.provider_code, ti.credentials_ref, ti.config, ti.is_enabled, ti.created_at, ti.updated_at into v_row;
        if not found then raise exception 'Integration not found'; end if;
        perform platform.log_audit('integration.updated', 'tenant_integration', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'disconnect_integration' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        select ti.id into v_existing from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        if not found then raise exception 'Integration not found'; end if;
        delete from public.tenant_integrations ti
        where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code';
        perform platform.log_audit('integration.disconnected', 'tenant_integration', v_existing,
            jsonb_build_object('provider_code', p_payload->>'provider_code'));
        v_result := jsonb_build_object('disconnected', true, 'provider_code', p_payload->>'provider_code');

    when 'list_webhook_definitions' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at
            from public.webhook_definitions wd
            where wd.tenant_id = v_tid
              and (p_payload->>'provider_code' is null or wd.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_webhook_definition' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        insert into public.webhook_definitions (tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active)
        values (
            v_tid, p_payload->>'provider_code', p_payload->>'event_type', p_payload->>'target_url',
            p_payload->>'signing_secret_ref',
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, provider_code, event_type, target_url, signing_secret_ref, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('webhook_definition.created', 'webhook_definition', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_webhook_definition' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        update public.webhook_definitions wd set
            event_type = case when p_payload ? 'event_type' then p_payload->>'event_type' else wd.event_type end,
            target_url = case when p_payload ? 'target_url' then p_payload->>'target_url' else wd.target_url end,
            signing_secret_ref = case when p_payload ? 'signing_secret_ref' then p_payload->>'signing_secret_ref' else wd.signing_secret_ref end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else wd.is_active end
        where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid
        returning wd.id, wd.tenant_id, wd.provider_code, wd.event_type, wd.target_url, wd.signing_secret_ref, wd.is_active, wd.created_at, wd.updated_at into v_row;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.updated', 'webhook_definition', v_row.id, p_payload);
        v_result := to_jsonb(v_row);

    when 'delete_webhook_definition' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        delete from public.webhook_definitions wd where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.deleted', 'webhook_definition', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_maps' then

    v_tid := platform.current_tenant_id();

    select
        coalesce(
            jsonb_agg(
                to_jsonb(t)
                order by t.created_at
            ),
            '[]'::jsonb
        )
    into v_result

    from (
        select
            dim.id,
            dim.tenant_id,
            dim.device_id,
            dim.provider_code,
            dim.external_id,
            dim.hardware_id,
            dim.config,
            dim.created_at

        from public.device_integration_map dim

        where dim.tenant_id = v_tid

          and (
                p_payload->>'device_id' is null
                or dim.device_id =
                   (p_payload->>'device_id')::uuid
              )

          and (
                p_payload->>'provider_code' is null
                or dim.provider_code =
                   p_payload->>'provider_code'
              )

    ) t;

    when 'create_device_map' then

    perform public.edge_require_manager();

    v_tid := platform.current_tenant_id();

    insert into public.device_integration_map (
        device_id,
        provider_code,
        external_id,
        hardware_id,
        config
    )
    values (
        (p_payload->>'device_id')::uuid,
        lower(trim(p_payload->>'provider_code')),
        p_payload->>'external_id',
        nullif(
            trim(p_payload->>'hardware_id'),
            ''
        ),
        coalesce(
            p_payload->'config',
            '{}'::jsonb
        )
    )

    returning
        id,
        tenant_id,
        device_id,
        provider_code,
        external_id,
        hardware_id,
        config,
        created_at
    into v_row;

    perform platform.log_audit(
        'device_integration_map.created',
        'device_integration_map',
        v_row.id
    );

    v_result := to_jsonb(v_row);
    
    when 'update_device_map' then

    perform public.edge_require_manager();

    v_tid := platform.current_tenant_id();

    update public.device_integration_map dim

    set
        external_id =
            case
                when p_payload ? 'external_id'
                then p_payload->>'external_id'
                else dim.external_id
            end,

        hardware_id =
            case
                when p_payload ? 'hardware_id'
                then nullif(
                    trim(p_payload->>'hardware_id'),
                    ''
                )
                else dim.hardware_id
            end,

        config =
            case
                when p_payload ? 'config'
                then p_payload->'config'
                else dim.config
            end

    where dim.id =
          (p_payload->>'id')::uuid

      and dim.tenant_id = v_tid

    returning
        dim.id,
        dim.tenant_id,
        dim.device_id,
        dim.provider_code,
        dim.external_id,
        dim.hardware_id,
        dim.config,
        dim.created_at

    into v_row;


    if not found then
        raise exception
            'Device map not found';
    end if;


    perform platform.log_audit(
        'device_integration_map.updated',
        'device_integration_map',
        v_row.id
    );


    v_result := to_jsonb(v_row);

    when 'delete_device_map' then
        perform public.edge_require_manager();
        v_tid := platform.current_tenant_id();
        delete from public.device_integration_map dim where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.deleted', 'device_integration_map', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    else
        return public.integrations_domain_ext(p_op, p_payload);
    end case;

    return v_result;
end;
$$;


-- =====================================================
-- 19. INTEGRATION DOMAIN EXTENSIONS
-- =====================================================

-- -----------------------------------------------------
-- 007: extend integrations_domain_ext with start_oauth
-- -----------------------------------------------------

create or replace function public.integrations_domain_ext(
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
    v_result jsonb;
    v_state_token text;
    v_expires_at timestamptz;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
    when 'start_oauth' then
        return public.integrations_start_oauth(p_payload);

    when 'register_oauth_state' then
        v_tid := platform.current_tenant_id();
        v_uid := auth.uid();
        if p_payload->>'provider_code' is null then
            raise exception 'provider_code is required';
        end if;
        if not exists (
            select 1 from public.integration_providers ip
            where ip.code = p_payload->>'provider_code'
              and ip.supports_oauth = true
              and ip.is_active = true
        ) then
            raise exception 'Integration provider not found or does not support OAuth';
        end if;
        v_state_token := encode(extensions.gen_random_bytes(32), 'hex');
        v_expires_at := now() + interval '10 minutes';
        insert into public.integration_oauth_states (
            tenant_id, user_id, provider_code, state_token, expires_at
        )
        values (
            v_tid, v_uid, p_payload->>'provider_code', v_state_token, v_expires_at
        );
        v_result := jsonb_build_object(
            'state_token', v_state_token,
            'expires_at', v_expires_at,
            'provider_code', p_payload->>'provider_code'
        );

    when 'request_sync' then
        v_tid := platform.current_tenant_id();
        v_uid := auth.uid();
        if p_payload->>'provider_code' is null then
            raise exception 'provider_code is required';
        end if;
        if not exists (
            select 1 from public.tenant_integrations ti
            where ti.tenant_id = v_tid
              and ti.provider_code = p_payload->>'provider_code'
              and ti.is_enabled = true
        ) then
            raise exception 'Integration not connected or disabled';
        end if;
        perform platform.push_integration_event(
            p_payload->>'provider_code',
            'sync_state',
            jsonb_build_object(
                'tenant_id', v_tid,
                'triggered_by', v_uid,
                'scope', coalesce(p_payload->'scope', '{}'::jsonb)
            )
        );
        perform platform.log_audit(
            'integration.sync_requested',
            'tenant_integration',
            (
                select ti.id from public.tenant_integrations ti
                where ti.tenant_id = v_tid and ti.provider_code = p_payload->>'provider_code'
            ),
            jsonb_build_object('provider_code', p_payload->>'provider_code')
        );
        v_result := jsonb_build_object(
            'queued', true,
            'provider_code', p_payload->>'provider_code'
        );

    when 'resolve_oauth_state' then
        if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
            raise exception 'state_token is required';
        end if;
        return public.integrations_resolve_oauth_state(p_payload->>'state_token');

    when 'complete_oauth' then
        if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
            raise exception 'state_token is required';
        end if;
        return public.integrations_complete_oauth(
            (p_payload->>'tenant_id')::uuid,
            p_payload->>'provider_code',
            p_payload->>'credentials_ref',
            p_payload->>'state_token'
        );

    else
        raise exception 'unknown integrations_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;


-- -----------------------------------------------------
-- 007 Integrations: OAuth state completion
-- -----------------------------------------------------

create or replace function public.integrations_complete_oauth(
    p_tenant_id uuid,
    p_provider_code text,
    p_credentials_ref text,
    p_state_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.tenant_integrations;
    v_state public.integration_oauth_states;
begin
    if p_tenant_id is null or p_provider_code is null or p_credentials_ref is null then
        raise exception 'tenant_id, provider_code, and credentials_ref are required';
    end if;

    if p_state_token is null or length(trim(p_state_token)) = 0 then
        raise exception 'OAuth state token is required';
    end if;

    select * into v_state
    from public.integration_oauth_states s
    where s.state_token = p_state_token
      and s.consumed_at is null
      and s.expires_at > now()
      and s.tenant_id = p_tenant_id
      and s.provider_code = p_provider_code
    for update;

    if not found then
        raise exception 'Invalid OAuth state for tenant/provider';
    end if;

    if not exists (
        select 1 from public.integration_providers ip where ip.code = p_provider_code
    ) then
        raise exception 'Integration provider not found';
    end if;

    update public.integration_oauth_states
    set consumed_at = now()
    where id = v_state.id;

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


-- =====================================================
-- 20. OAUTH HELPERS
-- =====================================================

-- -----------------------------------------------------
-- 007: URL encode helper for OAuth query parameters
-- -----------------------------------------------------

create or replace function public.integrations_oauth_url_encode(p_value text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
    v_bytes bytea;
    v_result text := '';
    v_i int;
    v_byte int;
begin
    if p_value is null then
        return '';
    end if;

    v_bytes := convert_to(p_value, 'UTF8');
    for v_i in 0..(length(v_bytes) - 1) loop
        v_byte := get_byte(v_bytes, v_i);
        if (v_byte >= 48 and v_byte <= 57)
           or (v_byte >= 65 and v_byte <= 90)
           or (v_byte >= 97 and v_byte <= 122)
           or v_byte in (45, 46, 95, 126) then
            v_result := v_result || chr(v_byte);
        else
            v_result := v_result || '%' || upper(to_hex(v_byte));
        end if;
    end loop;

    return v_result;
end;
$$;


-- -----------------------------------------------------
-- 007: OAuth start (state registration + authorize URL)
-- Vault secrets: supabase_url, stripe_connect_client_id,
-- oauth_authorize_url_{provider_code}
-- -----------------------------------------------------

create or replace function public.integrations_start_oauth(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_uid uuid;
    v_provider_code text;
    v_state_token text;
    v_expires_at timestamptz;
    v_redirect_uri text;
    v_supabase_url text;
    v_authorize_url text;
    v_base_url text;
    v_client_id text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_tid := platform.current_tenant_id();
    v_uid := auth.uid();

    if p_payload->>'provider_code' is null then
        raise exception 'provider_code is required';
    end if;

    v_provider_code := lower(trim(p_payload->>'provider_code'));

    if not exists (
        select 1 from public.integration_providers ip
        where ip.code = v_provider_code
          and ip.supports_oauth = true
          and ip.is_active = true
    ) then
        raise exception 'Integration provider not found or does not support OAuth';
    end if;

    v_state_token := encode(extensions.gen_random_bytes(32), 'hex');
    v_expires_at := now() + interval '10 minutes';

    insert into public.integration_oauth_states (
        tenant_id, user_id, provider_code, state_token, expires_at
    )
    values (
        v_tid, v_uid, v_provider_code, v_state_token, v_expires_at
    );

    v_supabase_url := platform.get_vault_secret('supabase_url');
    if v_supabase_url is null then
        raise exception 'supabase_url not configured in vault';
    end if;

    v_redirect_uri := coalesce(
        nullif(trim(p_payload->>'redirect_uri'), ''),
        rtrim(v_supabase_url, '/') || '/functions/v1/integrations/oauth-callback'
    );

    if v_provider_code = 'stripe' then
        v_client_id := platform.get_vault_secret('stripe_connect_client_id');
        if v_client_id is null then
            raise exception 'stripe_connect_client_id not configured in vault';
        end if;

        v_authorize_url :=
            'https://connect.stripe.com/oauth/authorize?' ||
            'response_type=code&' ||
            'client_id=' || public.integrations_oauth_url_encode(v_client_id) || '&' ||
            'scope=read_write&' ||
            'state=' || public.integrations_oauth_url_encode(v_state_token) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);
    else
        v_base_url := platform.get_vault_secret('oauth_authorize_url_' || v_provider_code);
        if v_base_url is null then
            raise exception 'OAuth authorize URL not configured for %', v_provider_code;
        end if;

        v_authorize_url :=
            v_base_url || '?' ||
            'state=' || public.integrations_oauth_url_encode(v_state_token) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);
    end if;

    return jsonb_build_object(
        'authorize_url', v_authorize_url,
        'state', v_state_token,
        'provider_code', v_provider_code
    );
end;
$$;


-- -----------------------------------------------------
-- integrations_resolve_oauth_state: gate via current_tenant_id()
-- -----------------------------------------------------

create or replace function public.integrations_resolve_oauth_state(p_state_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.integration_oauth_states;
    v_uid uuid;
    v_tid uuid;
begin
    if p_state_token is null or length(trim(p_state_token)) = 0 then
        raise exception 'OAuth state token is required';
    end if;

    select * into v_row
    from public.integration_oauth_states s
    where s.state_token = p_state_token
      and s.consumed_at is null
      and s.expires_at > now()
    for update;

    if not found then
        raise exception 'Invalid or expired OAuth state';
    end if;

    v_uid := (select auth.uid());
    if v_uid is not null then
        v_tid := platform.current_tenant_id();
        if v_row.user_id <> v_uid then
            raise exception 'unauthorized';
        end if;
        if v_tid is null or v_row.tenant_id <> v_tid then
            raise exception 'unauthorized';
        end if;
    end if;

    return jsonb_build_object(
        'tenant_id', v_row.tenant_id,
        'provider_code', v_row.provider_code,
        'user_id', v_row.user_id
    );
end;
$$;


-- -----------------------------------------------------
-- 007 Integrations: OAuth token exchange (SSOT)
-- -----------------------------------------------------

create or replace function public.integrations_exchange_oauth_tokens(
    p_tenant_id uuid,
    p_provider_code text,
    p_code text,
    p_redirect_uri text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_provider_code text;
    v_credentials_ref text;
    v_redirect_uri text;
    v_supabase_url text;
    v_client_secret text;
    v_client_id text;
    v_token_url text;
    v_form_body text;
    v_http_result jsonb;
    v_status_code int;
    v_response_body text;
begin
    if p_code is null or length(trim(p_code)) = 0 then
        raise exception 'code is required';
    end if;

    if p_tenant_id is null or p_provider_code is null then
        raise exception 'tenant_id and provider_code are required';
    end if;

    v_provider_code := lower(trim(p_provider_code));
    v_credentials_ref := format('integrations/%s/%s', p_tenant_id, v_provider_code);

    if v_provider_code = 'stripe' then
        v_client_secret := platform.get_vault_secret('stripe_connect_client_secret');
        if v_client_secret is null then
            raise exception 'stripe_connect_client_secret not configured in vault';
        end if;

        v_form_body :=
            'grant_type=authorization_code&' ||
            'code=' || public.integrations_oauth_url_encode(p_code) || '&' ||
            'client_secret=' || public.integrations_oauth_url_encode(v_client_secret);

        v_http_result := platform.sync_http_request(
            'POST',
            'https://connect.stripe.com/oauth/token',
            'application/x-www-form-urlencoded',
            v_form_body
        );
    else
        v_token_url := platform.get_vault_secret('oauth_token_url_' || v_provider_code);
        v_client_secret := platform.get_vault_secret('oauth_client_secret_' || v_provider_code);
        v_client_id := platform.get_vault_secret('oauth_client_id_' || v_provider_code);

        if v_token_url is null then
            raise exception 'OAuth token URL not configured for %', v_provider_code;
        end if;
        if v_client_secret is null then
            raise exception 'OAuth client secret not configured for %', v_provider_code;
        end if;
        if v_client_id is null then
            raise exception 'OAuth client id not configured for %', v_provider_code;
        end if;

        v_supabase_url := platform.get_vault_secret('supabase_url');
        if v_supabase_url is null then
            raise exception 'supabase_url not configured in vault';
        end if;

        v_redirect_uri := coalesce(
            nullif(trim(p_redirect_uri), ''),
            rtrim(v_supabase_url, '/') || '/functions/v1/integrations/oauth-callback'
        );

        v_form_body :=
            'grant_type=authorization_code&' ||
            'code=' || public.integrations_oauth_url_encode(p_code) || '&' ||
            'client_id=' || public.integrations_oauth_url_encode(v_client_id) || '&' ||
            'client_secret=' || public.integrations_oauth_url_encode(v_client_secret) || '&' ||
            'redirect_uri=' || public.integrations_oauth_url_encode(v_redirect_uri);

        v_http_result := platform.sync_http_request(
            'POST',
            v_token_url,
            'application/x-www-form-urlencoded',
            v_form_body
        );
    end if;

    v_status_code := (v_http_result->>'status_code')::int;
    v_response_body := v_http_result->>'body';

    if v_status_code < 200 or v_status_code >= 300 then
        raise exception 'OAuth token exchange failed (HTTP %): %', v_status_code, v_response_body;
    end if;

    begin
        perform v_response_body::jsonb;
    exception
        when others then
            raise exception 'OAuth token exchange returned invalid JSON: %', v_response_body;
    end;

    perform platform.upsert_vault_secret(
        v_response_body,
        v_credentials_ref,
        format('OAuth credentials for %s tenant %s', v_provider_code, p_tenant_id)
    );

    return v_credentials_ref;
end;
$$;


-- -----------------------------------------------------
-- 007 Integrations: OAuth complete API (real token exchange)
-- -----------------------------------------------------

create or replace function public.integrations_oauth_complete_api(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_resolved jsonb;
    v_tenant_id uuid;
    v_provider_code text;
    v_credentials_ref text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    if p_payload->>'state_token' is null or length(trim(p_payload->>'state_token')) = 0 then
        raise exception 'state_token is required';
    end if;

    if p_payload->>'code' is null or length(trim(p_payload->>'code')) = 0 then
        raise exception 'code is required';
    end if;

    v_resolved := public.integrations_resolve_oauth_state(p_payload->>'state_token');
    v_tenant_id := (v_resolved->>'tenant_id')::uuid;
    v_provider_code := v_resolved->>'provider_code';

    v_credentials_ref := public.integrations_exchange_oauth_tokens(
        v_tenant_id,
        v_provider_code,
        p_payload->>'code',
        p_payload->>'redirect_uri'
    );

    return public.integrations_complete_oauth(
        v_tenant_id,
        v_provider_code,
        v_credentials_ref,
        p_payload->>'state_token'
    );
end;
$$;



-- =====================================================
-- 20. RESOLVE OR RECONCILE PROVIDER DEVICE
--
-- Purpose:
-- Resolve a provider device to a SmartHellas device.
--
-- Resolution order:
--
-- 1. Current external_id
-- 2. Stable hardware_id
--
-- 007 owns provider identity.
-- 004 remains device SSOT.
-- =====================================================

create or replace function public.resolve_or_reconcile_provider_device(
    p_tenant_id uuid,
    p_provider_code text,
    p_external_id text,
    p_hardware_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_device_id uuid;
    v_map_id uuid;
begin

    if p_tenant_id is null then
        raise exception 'tenant_id is required';
    end if;

    if p_provider_code is null
       or btrim(p_provider_code) = '' then
        raise exception 'provider_code is required';
    end if;

    if p_external_id is null
       or btrim(p_external_id) = '' then
        raise exception 'external_id is required';
    end if;


    -- =================================================
    -- 1. CURRENT EXTERNAL ID
    -- =================================================

    select dim.device_id
    into v_device_id
    from public.device_integration_map dim
    where dim.tenant_id = p_tenant_id
      and dim.provider_code = p_provider_code
      and dim.external_id = p_external_id
    limit 1;


    if v_device_id is not null then

        return v_device_id;

    end if;


    -- =================================================
    -- 2. STABLE HARDWARE ID
    -- =================================================

    if p_hardware_id is null
       or btrim(p_hardware_id) = '' then

        raise exception
            'Provider device % is unknown and no hardware identity was supplied',
            p_external_id;

    end if;


    select
        dim.id,
        dim.device_id
    into
        v_map_id,
        v_device_id
    from public.device_integration_map dim
    where dim.tenant_id = p_tenant_id
      and dim.provider_code = p_provider_code
      and dim.hardware_id = p_hardware_id
    limit 1
    for update;


    if v_device_id is null then

        raise exception
            'No SmartHellas device mapping found for provider % and hardware identity %',
            p_provider_code,
            p_hardware_id;

    end if;


    -- =================================================
    -- 3. RECONCILE CURRENT EXTERNAL ID
    -- =================================================

    if exists (
        select 1
        from public.device_integration_map dim
        where dim.tenant_id = p_tenant_id
          and dim.provider_code = p_provider_code
          and dim.external_id = p_external_id
          and dim.id <> v_map_id
    ) then

        raise exception
            'External provider identifier % already belongs to another device',
            p_external_id;

    end if;


    update public.device_integration_map
    set external_id = btrim(p_external_id)
    where id = v_map_id;


    perform platform.log_audit(
        'provider.device_identity_reconciled',
        'device_integration_map',
        v_map_id,
        jsonb_build_object(
            'provider_code',
            p_provider_code,

            'device_id',
            v_device_id,

            'hardware_id',
            p_hardware_id,

            'external_id',
            p_external_id
        )
    );


    return v_device_id;

end;
$$;


revoke all on function public.resolve_or_reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
from public, anon, authenticated;


grant execute on function public.resolve_or_reconcile_provider_device(
    uuid,
    text,
    text,
    text
)
to service_role;



-- =====================================================
-- 21. INBOUND WEBHOOK PROCESSOR
-- =====================================================

-- =====================================================
-- 007 INTEGRATION ENGINE
-- INBOUND WEBHOOK PROCESSOR
--
-- Responsibility:
-- - Resolve external webhook provider
-- - Resolve provider category
-- - Resolve device through integration mapping
-- - Resolve mapped values through mapping layer
-- - Route device-related input to 007 telemetry
--
-- 007 MUST NOT:
-- - interpret provider-specific payload structure
-- - calculate device state
-- - calculate metrics
-- - make automation decisions
-- - modify platform webhook processing lifecycle
--
-- 000 owns:
--   platform.external_webhooks
--   generic processing lifecycle
--   retry handling
--
-- 007 owns:
--   device_telemetry_raw
--   immutable raw device telemetry storage
--
-- =====================================================


create or replace function public.process_integration_webhook(
    p_webhook_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_webhook record;

    v_provider_code text;
    v_event_type text;
    v_tenant_id uuid;

    v_device_external_id text;
    v_device_id uuid;

    v_provider_event_id text;
    v_observed_at_text text;

    v_observed_at timestamptz;

    v_inserted_id uuid;

    v_payload jsonb;

begin

    -- =====================================================
    -- 1. LOAD PLATFORM WEBHOOK
    -- =====================================================

    select
        ew.id,
        ew.source,
        ew.external_event_id,
        ew.event_type,
        ew.tenant_id,
        ew.payload,
        ew.received_at
    into v_webhook
    from platform.external_webhooks ew
    where ew.id = p_webhook_id;

    if not found then
        raise exception
            'external webhook % not found',
            p_webhook_id;
    end if;


    v_provider_code := lower(trim(v_webhook.source));

    v_event_type := v_webhook.event_type;

    v_tenant_id := v_webhook.tenant_id;

    v_payload := coalesce(
        v_webhook.payload,
        '{}'::jsonb
    );


    -- =====================================================
    -- 2. PROVIDER VALIDATION
    -- =====================================================

    if not exists (
        select 1
        from public.integration_providers ip
        where ip.code = v_provider_code
          and ip.is_active = true
    ) then

        raise exception
            'Unknown or inactive integration provider: %',
            v_provider_code;

    end if;


    -- =====================================================
    -- 3. EVENT TYPE
    --
    -- event_type may already have been determined by
    -- the platform webhook receiver.
    --
    -- If not available, the integration mapping layer
    -- cannot safely interpret the payload.
    -- =====================================================

    if v_event_type is null
       or length(trim(v_event_type)) = 0 then

        raise exception
            'event_type is required for integration webhook %',
            p_webhook_id;

    end if;


    -- =====================================================
    -- 4. PROVIDER EVENT ID
    -- =====================================================

    v_provider_event_id :=
        coalesce(
            nullif(
                public.resolve_integration_webhook_mapping(
                    v_provider_code,
                    v_event_type,
                    'provider_event_id',
                    v_payload
                ),
                ''
            ),
            v_webhook.external_event_id
        );


    -- =====================================================
    -- 5. DEVICE EXTERNAL ID
    -- =====================================================

    v_device_external_id :=
        public.resolve_integration_webhook_mapping(
            v_provider_code,
            v_event_type,
            'device_external_id',
            v_payload
        );


    -- =====================================================
    -- 6. TENANT RESOLUTION
    --
    -- If tenant was already assigned by the platform
    -- boundary, retain it.
    --
    -- Otherwise the integration mapping must resolve it
    -- through the tenant integration/device relationship.
    -- =====================================================

    if v_tenant_id is null
       and v_device_external_id is not null then

        select dim.tenant_id
        into v_tenant_id
        from public.device_integration_map dim
        where dim.provider_code = v_provider_code
          and dim.external_id = v_device_external_id
        limit 1;

    end if;


    -- =====================================================
    -- 7. DEVICE RESOLUTION
    -- =====================================================

    if v_device_external_id is not null then

        select dim.device_id
        into v_device_id
        from public.device_integration_map dim
        where dim.provider_code = v_provider_code
          and dim.external_id = v_device_external_id
          and (
                v_tenant_id is null
                or dim.tenant_id = v_tenant_id
              )
        limit 1;

    end if;


    -- =====================================================
    -- 8. TELEMETRY ROUTING
    --
    -- Only events for which the mapping layer explicitly
    -- provides a device are written to 007.
    --
    -- 007 performs routing.
    -- 007 performs raw telemetry storage.
    -- =====================================================

    if v_device_id is not null then

        -- -------------------------------------------------
        -- 8A. Resolve observed event timestamp
        -- -------------------------------------------------

        v_observed_at_text :=
            public.resolve_integration_webhook_mapping(
                v_provider_code,
                v_event_type,
                'observed_at',
                v_payload
            );


        -- -------------------------------------------------
        -- 8B. Convert observed timestamp
        --
        -- Mapping itself determines the provider format.
        -- -------------------------------------------------

        if v_observed_at_text is not null then

            if exists (
                select 1
                from public.integration_webhook_mappings m
                where m.provider_code = v_provider_code
                  and (
                        m.event_type = v_event_type
                        or (
                            m.event_type like '%*'
                            and v_event_type like replace(m.event_type, '*', '%')
                        )
                      )
                  and m.mapping_code = 'observed_at'
                  and m.is_active = true
                  and m.value_type = 'epoch_milliseconds'
            ) then

                v_observed_at :=
                    to_timestamp(
                        v_observed_at_text::double precision
                        / 1000.0
                    );

            elsif exists (
                select 1
                from public.integration_webhook_mappings m
                where m.provider_code = v_provider_code
                  and (
                        m.event_type = v_event_type
                        or (
                            m.event_type like '%*'
                            and v_event_type like replace(m.event_type, '*', '%')
                        )
                      )
                  and m.mapping_code = 'observed_at'
                  and m.is_active = true
                  and m.value_type = 'epoch_seconds'
            ) then

                v_observed_at :=
                    to_timestamp(
                        v_observed_at_text::double precision
                    );

            else

                v_observed_at :=
                    v_observed_at_text::timestamptz;

            end if;

        end if;


        -- -------------------------------------------------
        -- 8C. Insert immutable raw telemetry
        -- -------------------------------------------------

        insert into public.device_telemetry_raw (
            tenant_id,
            device_id,
            source,
            provider_event_id,
            observed_at,
            received_at,
            raw_payload
        )
        values (
            v_tenant_id,
            v_device_id,
            v_provider_code,
            v_provider_event_id,
            v_observed_at,
            v_webhook.received_at,
            v_payload
        )
        returning id
        into v_inserted_id;


        return jsonb_build_object(
            'processed', true,
            'route', 'device_telemetry',
            'webhook_id', p_webhook_id,
            'provider_code', v_provider_code,
            'event_type', v_event_type,
            'tenant_id', v_tenant_id,
            'device_id', v_device_id,
            'telemetry_id', v_inserted_id,
            'observed_at', v_observed_at,
            'received_at', v_webhook.received_at
        );

    end if;


    -- =====================================================
    -- 9. NO DEVICE ROUTE
    --
    -- Not every integration webhook is telemetry.
    --
    -- Examples:
    -- - Stripe payment
    -- - OAuth callback
    -- - PMS event
    -- - Airbnb reservation
    -- - messaging event
    --
    -- These must NOT be written into 007.
    -- =====================================================

    return jsonb_build_object(
        'processed', true,
        'route', 'unhandled_domain_event',
        'webhook_id', p_webhook_id,
        'provider_code', v_provider_code,
        'event_type', v_event_type,
        'tenant_id', v_tenant_id
    );

end;
$$;


-- =====================================================
-- 22. FUNCTION SECURITY HARDENING
-- =====================================================

alter function public.process_integration_webhook(uuid)
set search_path = '';



alter function public.integrations_resolve_oauth_state(text) set search_path = '';


-- =====================================================
-- 23. LEGACY / CROSS-MODULE SECURITY HARDENING
-- =====================================================

-- -----------------------------------------------------
-- 007 Logistics: close direct authenticated execute bypass on dispatch RPC
-- Idempotent: skip if function not yet created (050 re-applies lockdown)
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
          and p.proname = 'logistics_dispatch_fulfilment_order'
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


-- =====================================================
-- 24. MIGRATION REGISTRATION
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('007_integration_engine', 'REV22.INTEGRATION', false)
on conflict (version) do nothing;