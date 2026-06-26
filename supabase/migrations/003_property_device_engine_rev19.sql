
-- =====================================================
-- 003 PROPERTY & DEVICE ENGINE (CLEAN DOMAIN MODEL)
-- NO RUNTIME / NO LOGGING / NO EXECUTION STATE
-- =====================================================

-- =====================================================
-- 1. PROPERTIES (AIRBNB UNITS)
-- =====================================================

create table if not exists properties (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    address text,

    property_type property_type not null,

    timezone text default 'UTC',

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_properties_tenant
on properties (tenant_id);

-- =====================================================
-- 2. ROOMS (LOGICAL STRUCTURE INSIDE PROPERTY)
-- =====================================================

create table if not exists rooms (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,

    name text not null,

    room_type room_type not null,

    floor int,

    created_at timestamptz default now()
);

create index if not exists idx_rooms_property
on rooms (property_id);

-- =====================================================
-- 3. DEVICES (MASTER DEVICE REGISTRY)
-- =====================================================

create table if not exists devices (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    device_name text not null,

    category device_category not null,

    protocol device_protocol not null,

    model text,

    manufacturer text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_devices_tenant
on devices (tenant_id);

-- =====================================================
-- 4. DEVICE ASSIGNMENT (DEVICE ↔ ROOM LINK)
-- =====================================================

create table if not exists device_assignments (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    room_id uuid not null references rooms(id) on delete cascade,

    assigned_at timestamptz default now(),

    unique (device_id)
);

create index if not exists idx_device_assignments_room
on device_assignments (room_id);

-- =====================================================
-- 5. DEVICE CONFIGURATION (STATIC SETUP ONLY)
-- =====================================================

create table if not exists device_configurations (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    config jsonb not null,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (device_id)
);

-- =====================================================
-- END 003 PROPERTY & DEVICE ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================