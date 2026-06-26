-- =====================================================
-- 010 SERVICE & PORTAL ENGINE (CLEAN UI + SERVICE LAYER)
-- NO LOGS / NO EVENTS / NO SYSTEM STATE
-- =====================================================

-- =====================================================
-- 1. TENANT PORTAL SETTINGS (UI CONFIGURATION)
-- =====================================================

create table if not exists tenant_portal_settings (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    theme jsonb,
    -- colors, branding, logo, layout preferences

    default_language text default 'en',

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_portal_settings_tenant
on tenant_portal_settings (tenant_id);

-- =====================================================
-- 2. DASHBOARD CONFIGURATION (LAYOUT DEFINITION)
-- =====================================================

create table if not exists dashboard_configs (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    layout jsonb,
    -- widgets, arrangement, visibility rules

    is_default boolean default false,

    created_at timestamptz default now()
);

-- =====================================================
-- 3. SUPPORT TICKETS (BUSINESS SERVICE STATE)
-- =====================================================

create table if not exists support_tickets (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    user_id uuid,

    subject text,

    description text,

    status text default 'open',
    -- open | in_progress | resolved | closed

    priority text default 'normal',
    -- low | normal | high | urgent

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_support_tickets_tenant
on support_tickets (tenant_id);

-- =====================================================
-- 4. SUPPORT MESSAGES (CONVERSATION LAYER ONLY)
-- =====================================================

create table if not exists support_messages (
    id uuid primary key default gen_random_uuid(),

    ticket_id uuid not null references support_tickets(id) on delete cascade,

    sender_type text,
    -- user | support | system

    message text,

    created_at timestamptz default now()
);

create index if not exists idx_support_messages_ticket
on support_messages (ticket_id);

-- =====================================================
-- 5. PORTAL FEATURE FLAGS (UI-ONLY CONTROL)
-- =====================================================

create table if not exists portal_feature_flags (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    feature_key text not null,
    -- show_energy_dashboard, show_device_map, show_logs_view

    enabled boolean default true
);

create index if not exists idx_portal_feature_flags_tenant
on portal_feature_flags (tenant_id);

-- =====================================================
-- END 010 SERVICE & PORTAL ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================