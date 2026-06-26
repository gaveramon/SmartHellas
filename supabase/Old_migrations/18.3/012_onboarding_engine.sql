-- =====================================================
-- 007A_ONBOARDING_ENGINE.sql
-- REV18.3 MODULE
-- =====================================================

-- ONBOARDING STEPS (definition layer)
create table if not exists onboarding_steps (
    id uuid primary key default gen_random_uuid(),
    step_code text unique not null,
    product_type text not null,

    title text not null,
    description text,

    required boolean default true,
    sort_order int default 0,

    created_at timestamptz default now()
);

-- PROGRESS TRACKING PER PROPERTY
create table if not exists property_onboarding_progress (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,
    step_id uuid not null references onboarding_steps(id) on delete cascade,

    status text default 'pending',
    -- pending | in_progress | completed | failed | skipped

    completed_at timestamptz,

    metadata jsonb default '{}'::jsonb,

    updated_at timestamptz default now(),

    unique(property_id, step_id)
);

create index if not exists idx_onboarding_property
on property_onboarding_progress(property_id);

-- AIRCON COMMISSIONING (special onboarding flow extension)
create table if not exists aircon_commissioning_status (
    id uuid primary key default gen_random_uuid(),

    property_id uuid not null references properties(id) on delete cascade,
    device_id uuid references devices(id),

    aircon_brand text,
    aircon_model text,

    status text default 'pending',
    -- pending | ir_learned | tested | commissioned | failed

    ir_power_on_test boolean default false,
    ir_power_off_test boolean default false,
    ir_mode_test boolean default false,
    ir_temperature_test boolean default false,

    customer_validation_passed boolean default false,

    last_test_at timestamptz,

    created_at timestamptz default now(),
    updated_at timestamptz default now(),

    unique(property_id, device_id)
);

-- default onboarding step
insert into onboarding_steps (
    step_code,
    product_type,
    title,
    description,
    required,
    sort_order
)
values (
    'AIRCON_CUSTOMER_VALIDATION',
    'AIRCON',
    'Airco klant validatie',
    'Klant bevestigt correcte IR werking (aan/uit + modus)',
    true,
    40
)
on conflict (step_code) do nothing;