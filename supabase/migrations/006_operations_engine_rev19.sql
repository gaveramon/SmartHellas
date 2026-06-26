-- =====================================================
-- 006 OPERATIONS ENGINE (CLEAN WORKFLOW DEFINITION LAYER)
-- NO EXECUTION / NO RUNTIME STATE / NO LOGGING
-- =====================================================

-- =====================================================
-- 1. OPERATION WORKFLOWS (MASTER DEFINITION)
-- =====================================================

create table if not exists operation_workflows (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    name text not null,

    description text,

    is_active boolean default true,

    created_at timestamptz default now()
);

create index if not exists idx_operation_workflows_tenant
on operation_workflows (tenant_id);

-- =====================================================
-- 2. WORKFLOW STEPS (SEQUENTIAL LOGIC DEFINITION)
-- =====================================================

create table if not exists workflow_steps (
    id uuid primary key default gen_random_uuid(),

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    step_order int not null,

    action_type automation_action_type not null,

    config jsonb not null,

    delay_seconds int default 0
);

create index if not exists idx_workflow_steps_workflow
on workflow_steps (workflow_id);

-- =====================================================
-- 3. TRIGGER DEFINITIONS (WHEN WORKFLOWS START)
-- =====================================================

create table if not exists workflow_triggers (
    id uuid primary key default gen_random_uuid(),

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    trigger_type automation_trigger_type not null,

    trigger_config jsonb,

    is_active boolean default true
);

create index if not exists idx_workflow_triggers_workflow
on workflow_triggers (workflow_id);

-- =====================================================
-- 4. OPERATION TEMPLATES (REUSABLE BLUEPRINTS)
-- =====================================================

create table if not exists operation_templates (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    name text not null,

    template jsonb not null,

    created_at timestamptz default now()
);

create index if not exists idx_operation_templates_tenant
on operation_templates (tenant_id);

-- =====================================================
-- 5. OPERATION CONTEXT (LIGHTWEIGHT INPUT MODEL ONLY)
-- =====================================================

create table if not exists operation_contexts (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    context_type text,
    -- booking_event | device_event | manual_trigger

    payload jsonb,

    created_at timestamptz default now()
);

create index if not exists idx_operation_contexts_tenant
on operation_contexts (tenant_id);

-- =====================================================
-- END 006 OPERATIONS ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================