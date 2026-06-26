-- =====================================================
-- 011 ONBOARDING ENGINE (CLEAN STATE TRACKING LAYER)
-- NO EXECUTION / NO AUTOMATION / NO SIDE EFFECTS
-- =====================================================

-- =====================================================
-- 1. ONBOARDING SESSIONS (PER TENANT PROPERTY)
-- =====================================================

create table if not exists onboarding_sessions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null,

    status onboarding_status default 'not_started',

    current_step text,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_onboarding_sessions_property
on onboarding_sessions (property_id);

-- =====================================================
-- 2. ONBOARDING STEPS STATE (PROGRESS TRACKING ONLY)
-- =====================================================

create table if not exists onboarding_step_state (
    id uuid primary key default gen_random_uuid(),

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    step_type onboarding_step_type not null,

    status text default 'pending',
    -- pending | completed | skipped

    completed_at timestamptz
);

create index if not exists idx_onboarding_step_state_session
on onboarding_step_state (session_id);

-- =====================================================
-- 3. ROOM MAPPING INPUT (USER-DEFINED STRUCTURE)
-- =====================================================

create table if not exists onboarding_room_mapping (
    id uuid primary key default gen_random_uuid(),

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    room_name text,

    room_type room_type,

    created_at timestamptz default now()
);

-- =====================================================
-- 4. DEVICE PLACEMENT INPUT (NO EXECUTION)
-- =====================================================

create table if not exists onboarding_device_mapping (
    id uuid primary key default gen_random_uuid(),

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    device_category device_category,

    room_name text,

    desired_action text,

    created_at timestamptz default now()
);

-- =====================================================
-- 5. ONBOARDING CHECKLIST (BUSINESS VALIDATION STATE)
-- =====================================================

create table if not exists onboarding_checklist (
    id uuid primary key default gen_random_uuid(),

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    checklist_key text,
    -- wifi_connected, devices_received, app_installed

    is_completed boolean default false,

    updated_at timestamptz default now()
);

-- =====================================================
-- 6. ONBOARDING NOTES (SUPPORT + CONTEXT ONLY)
-- =====================================================

create table if not exists onboarding_notes (
    id uuid primary key default gen_random_uuid(),

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    note text,

    created_at timestamptz default now()
);

-- =====================================================
-- END 011 ONBOARDING ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================