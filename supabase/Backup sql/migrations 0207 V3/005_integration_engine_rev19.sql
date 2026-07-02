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

-- -----------------------------------------------------
-- Domain SSOT (extensions delegate to *_domain_ext)
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
        v_tid := platform.current_tenant_id();
        delete from public.webhook_definitions wd where wd.id = (p_payload->>'id')::uuid and wd.tenant_id = v_tid;
        if not found then raise exception 'Webhook definition not found'; end if;
        perform platform.log_audit('webhook_definition.deleted', 'webhook_definition', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_device_maps' then
        v_tid := platform.current_tenant_id();
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at), '[]'::jsonb) into v_result
        from (
            select dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at
            from public.device_integration_map dim
            where dim.tenant_id = v_tid
              and (p_payload->>'device_id' is null or dim.device_id = (p_payload->>'device_id')::uuid)
              and (p_payload->>'provider_code' is null or dim.provider_code = p_payload->>'provider_code')
        ) t;

    when 'create_device_map' then
        v_tid := platform.current_tenant_id();
        insert into public.device_integration_map (device_id, provider_code, external_id, config)
        values (
            (p_payload->>'device_id')::uuid,
            p_payload->>'provider_code',
            p_payload->>'external_id',
            coalesce(p_payload->'config', '{}'::jsonb)
        )
        returning id, tenant_id, device_id, provider_code, external_id, config, created_at into v_row;
        perform platform.log_audit('device_integration_map.created', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_device_map' then
        v_tid := platform.current_tenant_id();
        update public.device_integration_map dim set
            external_id = case when p_payload ? 'external_id' then p_payload->>'external_id' else dim.external_id end,
            config = case when p_payload ? 'config' then p_payload->'config' else dim.config end
        where dim.id = (p_payload->>'id')::uuid and dim.tenant_id = v_tid
        returning dim.id, dim.tenant_id, dim.device_id, dim.provider_code, dim.external_id, dim.config, dim.created_at into v_row;
        if not found then raise exception 'Device map not found'; end if;
        perform platform.log_audit('device_integration_map.updated', 'device_integration_map', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_device_map' then
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


create or replace function public.integrations_domain_ext(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    raise exception 'unknown integrations_domain operation: %', p_op;
end;
$$;

revoke all on function public.integrations_domain(text, jsonb) from public;
grant execute on function public.integrations_domain(text, jsonb) to authenticated, service_role;

revoke all on function public.integrations_domain_ext(text, jsonb) from public;
grant execute on function public.integrations_domain_ext(text, jsonb) to authenticated, service_role;


-- END 005 INTEGRATION ENGINE (REV19)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('005_integration_engine_rev19', 'REV19.INTEGRATION', false)
on conflict (version) do nothing;
