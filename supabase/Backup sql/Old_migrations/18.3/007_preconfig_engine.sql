-- =====================================================
-- 007_PRECONFIG_ENGINE.sql
-- REV18.3 MODULE
-- =====================================================

-- ROOT PRECONFIG STATE PER PROPERTY
create table if not exists property_preconfiguration (
    id uuid primary key default gen_random_uuid(),
    property_id uuid not null references properties(id) on delete cascade,

    status text default 'draft',
    -- draft | configured | in_prep | shipped | active

    config jsonb default '{}'::jsonb,

    created_at timestamptz default now(),
    updated_at timestamptz default now(),

    unique(property_id)
);

-- ROOM ↔ DEVICE MAPPING LAYER
create table if not exists room_devices (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null,
    room_id uuid not null references rooms(id) on delete cascade,
    device_id uuid references devices(id) on delete set null,

    intent text,
    -- energy_saving | security | comfort | aircon | heating | leak_protection

    label text,
    qr_code text,

    status text default 'planned',
    -- planned | packed | installed | active

    created_at timestamptz default now()
);

create index if not exists idx_room_devices_property
on room_devices(property_id);

-- EXTEND DEVICE CONFIG (intent layer)
alter table device_configs
add column if not exists intent text,
add column if not exists priority int default 1;

-- WORKFLOW PIPELINE (preconfig steps)
create table if not exists preconfig_workflow (
    id uuid primary key default gen_random_uuid(),
    property_id uuid not null references properties(id) on delete cascade,

    step text not null,
    -- rooms_defined
    -- devices_mapped
    -- devices_paired
    -- devices_labeled
    -- qr_generated
    -- packed
    -- shipped
    -- onboarding_ready

    status text default 'pending',
    -- pending | in_progress | completed | failed

    metadata jsonb default '{}'::jsonb,

    updated_at timestamptz default now(),

    unique(property_id, step)
);

create index if not exists idx_preconfig_workflow_property
on preconfig_workflow(property_id);