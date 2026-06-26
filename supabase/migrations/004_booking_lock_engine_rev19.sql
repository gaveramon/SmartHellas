-- =====================================================
-- 004 BOOKING & LOCK ENGINE (CLEAN DOMAIN RULE LAYER)
-- NO EXECUTION / NO QUEUES / NO NOTIFICATIONS
-- =====================================================

-- =====================================================
-- 1. BOOKINGS (CORE RESERVATION MODEL)
-- =====================================================

create table if not exists bookings (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    guest_name text,

    guest_email text,

    start_date date not null,

    end_date date not null,

    status booking_status default 'pending',

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_bookings_property
on bookings (property_id);

create index if not exists idx_bookings_tenant
on bookings (tenant_id);

-- =====================================================
-- 2. ACCESS POLICY (BUSINESS RULES ONLY)
-- =====================================================

create table if not exists access_policies (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    access_type access_type not null,

    valid_from time,

    valid_to time,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_access_policies_property
on access_policies (property_id);

-- =====================================================
-- 3. BOOKING ACCESS LINK (LOGICAL MAPPING ONLY)
-- =====================================================

create table if not exists booking_access (
    id uuid primary key default gen_random_uuid(),

    booking_id uuid not null references bookings(id) on delete cascade,

    access_type access_type not null,

    valid_from timestamptz,

    valid_until timestamptz,

    created_at timestamptz default now(),

    unique (booking_id)
);

-- =====================================================
-- 4. LOCK DEVICE MAPPING (NO EXECUTION)
-- =====================================================

create table if not exists lock_devices (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    property_id uuid not null references properties(id) on delete cascade,

    lock_type text, -- TTLock, Aqara, etc.

    is_primary boolean default false,

    created_at timestamptz default now()
);

create index if not exists idx_lock_devices_property
on lock_devices (property_id);

-- =====================================================
-- 5. ACCESS RULES ENGINE (PURE BUSINESS RULES)
-- =====================================================

create table if not exists access_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null,

    rule_type text,
    -- check_in_window | checkout_window | override | emergency_access

    rule_config jsonb,

    is_active boolean default true,

    created_at timestamptz default now()
);

-- =====================================================
-- END 004 BOOKING & LOCK ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================