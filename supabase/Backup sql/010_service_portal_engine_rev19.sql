-- =====================================================
-- 010 SERVICE & PORTAL ENGINE (CLEAN UI + SERVICE LAYER)
-- NO LOGS / NO EVENTS / NO SYSTEM STATE
-- =====================================================
--
-- Runtime logs SSOT: platform.event_log, operation_log, audit_log (000).
-- portal_feature_flags.show_logs_view is a UI gate only — never store logs here.
-- =====================================================

-- =====================================================
-- 1. TENANT PORTAL SETTINGS (UI CONFIGURATION)
-- =====================================================

create table if not exists tenant_portal_settings (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    theme jsonb,
    -- colors, branding, logo

    default_language text default 'en',

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (tenant_id)
);

create index if not exists idx_portal_settings_tenant_created
on tenant_portal_settings (tenant_id, created_at desc);

create trigger trg_portal_settings_updated_at
before update on tenant_portal_settings
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. DASHBOARD CONFIGURATION (LAYOUT DEFINITION)
-- =====================================================

create table if not exists dashboard_configs (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    name text not null,

    layout jsonb,
    -- widgets, arrangement, visibility rules

    is_default boolean default false,

    created_at timestamptz default now()
);

create index if not exists idx_dashboard_configs_tenant_created
on dashboard_configs (tenant_id, created_at desc);

create unique index if not exists idx_dashboard_configs_one_default_per_tenant
on dashboard_configs (tenant_id)
where is_default = true;

-- =====================================================
-- 3. PORTAL USER PREFERENCES (PER-USER UI STATE)
-- =====================================================

create table if not exists portal_user_preferences (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    user_id uuid not null references platform.profiles(id) on delete cascade,

    preference_key text not null,
    -- dashboard_layout, widget_visibility, locale_override

    value jsonb not null default '{}'::jsonb,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (tenant_id, user_id, preference_key)
);

create index if not exists idx_portal_user_preferences_tenant_created
on portal_user_preferences (tenant_id, created_at desc);

create index if not exists idx_portal_user_preferences_user
on portal_user_preferences (tenant_id, user_id);

create trigger trg_portal_user_preferences_updated_at
before update on portal_user_preferences
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. SUPPORT TICKETS (BUSINESS SERVICE STATE)
-- =====================================================

create table if not exists support_tickets (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    user_id uuid references platform.profiles(id) on delete set null,

    subject text,

    description text,

    status support_ticket_status not null default 'open',

    priority priority_level not null default 'normal',

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    constraint chk_support_tickets_has_content check (
        subject is not null or description is not null
    )
);

create index if not exists idx_support_tickets_tenant_created
on support_tickets (tenant_id, created_at desc);

create index if not exists idx_support_tickets_tenant_status_created
on support_tickets (tenant_id, status, created_at desc);

create index if not exists idx_support_tickets_tenant_priority_created
on support_tickets (tenant_id, priority, created_at desc);

create trigger trg_support_tickets_updated_at
before update on support_tickets
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5. SUPPORT MESSAGES (CONVERSATION LAYER ONLY)
-- =====================================================

create table if not exists support_messages (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    ticket_id uuid not null references support_tickets(id) on delete cascade,

    sender_type support_sender_type not null,

    message text,

    created_at timestamptz default now()
);

create index if not exists idx_support_messages_tenant_created
on support_messages (tenant_id, created_at desc);

create index if not exists idx_support_messages_ticket_created
on support_messages (ticket_id, created_at asc);

-- =====================================================
-- 6. PORTAL FEATURE FLAGS (UI-ONLY CONTROL)
-- =====================================================

create table if not exists portal_feature_flags (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null references tenants(id) on delete cascade,

    feature_key text not null,
    -- show_energy_dashboard, show_device_map, show_logs_view

    enabled boolean default true,

    unique (tenant_id, feature_key)
);

create index if not exists idx_portal_feature_flags_tenant
on portal_feature_flags (tenant_id);

comment on table public.portal_feature_flags is
    'Portal UI visibility only. Plan entitlements SSOT: feature_entitlements (009). '
    'show_logs_view gates read access to platform.event_log / operation_log (000) — no log storage here.';

-- =====================================================
-- 7. TENANT CONSISTENCY GUARDS
-- =====================================================

create or replace function public.enforce_portal_user_preference_membership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if not exists (
        select 1
        from public.tenant_memberships tm
        where tm.tenant_id = new.tenant_id
          and tm.user_id = new.user_id
          and tm.is_active = true
    ) then
        raise exception 'user_id must be an active member of tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_portal_user_preferences_membership
before insert or update on public.portal_user_preferences
for each row execute function public.enforce_portal_user_preference_membership();

create or replace function public.enforce_support_ticket_user_membership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.user_id is null then
        return new;
    end if;

    if not exists (
        select 1
        from public.tenant_memberships tm
        where tm.tenant_id = new.tenant_id
          and tm.user_id = new.user_id
          and tm.is_active = true
    ) then
        raise exception 'support ticket user_id must be an active member of tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_support_tickets_user_membership
before insert or update on public.support_tickets
for each row execute function public.enforce_support_ticket_user_membership();

create or replace function public.enforce_support_message_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_ticket_tenant uuid;
begin
    select st.tenant_id
    into v_ticket_tenant
    from public.support_tickets st
    where st.id = new.ticket_id;

    if not found then
        raise exception 'support ticket not found';
    end if;

    if new.tenant_id <> v_ticket_tenant then
        raise exception 'support message tenant_id must match ticket tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_support_messages_tenant_consistency
before insert or update on public.support_messages
for each row execute function public.enforce_support_message_tenant_consistency();

-- =====================================================
-- END 010 SERVICE & PORTAL ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
