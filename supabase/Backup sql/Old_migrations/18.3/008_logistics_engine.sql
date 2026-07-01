-- =====================================================
-- 008_LOGISTICS_ENGINE.sql
-- REV18.3 MODULE
-- =====================================================

-- SHIPMENT MASTER
create table if not exists shipments (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,

    status text default 'preparing',
    -- preparing | packed | shipped | delivered | installed

    tracking_number text,
    carrier text,

    shipped_at timestamptz,
    delivered_at timestamptz,

    created_at timestamptz default now()
);

-- SHIPMENT ITEMS (PACKING CONTENTS)
create table if not exists shipment_items (
    id uuid primary key default gen_random_uuid(),

    shipment_id uuid references shipments(id) on delete cascade,
    device_id uuid references devices(id),

    room_id uuid,

    label text,
    qr_code text,

    created_at timestamptz default now()
);

-- EVENT TRACEABILITY (lightweight vs operation_logs)
create table if not exists preconfig_event_log (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,

    event_type text not null,
    -- ROOM_CREATED | DEVICE_ASSIGNED | QR_GENERATED | SHIPMENT_CREATED

    source text,
    -- appsmith | api | system

    payload jsonb default '{}'::jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_preconfig_event_property
on preconfig_event_log(property_id);