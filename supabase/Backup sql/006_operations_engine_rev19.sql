-- =====================================================
-- 006 OPERATIONS ENGINE (CLEAN WORKFLOW DEFINITION LAYER)
-- NO EXECUTION / NO RUNTIME STATE / NO LOGGING / NO QUEUES
-- =====================================================
--
-- DEFINITIONS ONLY
-- operation_workflows  — automation blueprint per tenant
-- workflow_steps       — ordered action pipeline
-- workflow_triggers    — start conditions (not DB triggers)
-- operation_templates  — reusable JSON blueprints (clone into workflows)
--
-- RUNTIME (000): platform.operation_contexts, internal_events, operation_log,
--               retry_tasks, integration_queue, device_commands
-- =====================================================

-- =====================================================
-- 1. OPERATION TEMPLATES (REUSABLE BLUEPRINTS)
-- =====================================================

create table if not exists operation_templates (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    name text not null,

    template jsonb not null,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_operation_templates_tenant
on operation_templates (tenant_id);

comment on table public.operation_templates is
    'JSON blueprint for cloning into operation_workflows. Normalized steps/triggers are SSOT after instantiation.';

create trigger trg_operation_templates_updated_at
before update on operation_templates
for each row execute function platform.set_updated_at();

-- =====================================================
-- 2. OPERATION WORKFLOWS (MASTER DEFINITION)
-- =====================================================

create table if not exists operation_workflows (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    source_template_id uuid references operation_templates(id) on delete set null,

    name text not null,

    description text,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_operation_workflows_tenant
on operation_workflows (tenant_id);

create index if not exists idx_operation_workflows_tenant_created
on operation_workflows (tenant_id, created_at desc);

create trigger trg_operation_workflows_updated_at
before update on operation_workflows
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. WORKFLOW STEPS (SEQUENTIAL LOGIC DEFINITION)
-- =====================================================

create table if not exists workflow_steps (
    id uuid primary key default gen_random_uuid(),

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    step_order int not null,

    action_type automation_action_type not null,

    config jsonb not null default '{}'::jsonb,

    delay_seconds int not null default 0,

    unique (workflow_id, step_order),

    constraint chk_workflow_steps_order check (step_order > 0),

    constraint chk_workflow_steps_delay check (delay_seconds >= 0)
);

create index if not exists idx_workflow_steps_workflow
on workflow_steps (workflow_id);

comment on column public.workflow_steps.config is
    'Action parameters only. generate_code: { lock_device_id }. trigger_webhook: { webhook_definition_id }.';

-- =====================================================
-- 4. TRIGGER DEFINITIONS (WHEN WORKFLOWS START)
-- =====================================================

create table if not exists workflow_triggers (
    id uuid primary key default gen_random_uuid(),

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    property_id uuid references properties(id) on delete cascade,

    trigger_type automation_trigger_type not null,

    trigger_config jsonb default '{}'::jsonb,

    is_active boolean default true,

    unique (workflow_id, trigger_type)
);

create index if not exists idx_workflow_triggers_workflow
on workflow_triggers (workflow_id);

create index if not exists idx_workflow_triggers_property
on workflow_triggers (property_id)
where property_id is not null;

comment on column public.workflow_triggers.property_id is
    'Null = tenant-wide trigger. Set for property-scoped automation.';

comment on column public.workflow_triggers.trigger_config is
    'schedule_based: { cron_expression }. booking_*: { status_filter }. device_added: { device_category }.';

-- =====================================================
-- 4B. WORKFLOW TRIGGER SCOPE CONSISTENCY
-- =====================================================

create or replace function public.enforce_workflow_trigger_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_workflow_tenant uuid;
    v_property_tenant uuid;
begin
    select ow.tenant_id
    into v_workflow_tenant
    from public.operation_workflows ow
    where ow.id = new.workflow_id;

    if not found then
        raise exception 'workflow not found';
    end if;

    if new.property_id is null then
        return new;
    end if;

    select p.tenant_id
    into v_property_tenant
    from public.properties p
    where p.id = new.property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if v_property_tenant <> v_workflow_tenant then
        raise exception 'trigger property must belong to the workflow tenant';
    end if;

    return new;
end;
$$;

create trigger trg_workflow_triggers_scope
before insert or update on public.workflow_triggers
for each row execute function public.enforce_workflow_trigger_scope();

-- =====================================================
-- 5. PLATFORM CONTEXT TYPE BINDING (I1 — RUNTIME IN 000)
-- =====================================================

do $$
begin
    alter table platform.operation_contexts
        alter column context_type type operation_context_type
        using context_type::operation_context_type;
exception
    when undefined_table then null;
    when others then
        raise notice 'platform.operation_contexts type bind skipped: %', sqlerrm;
end $$;

comment on table platform.operation_contexts is
    'Transient workflow input inbox (000). context_type uses 001 operation_context_type. Not a workflow definition.';

-- =====================================================
-- 6. TENANT FKs (DEFERRED — TENANTS EXIST FROM 002)
-- =====================================================

do $$
begin
    alter table public.operation_workflows
        add constraint fk_operation_workflows_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.operation_templates
        add constraint fk_operation_templates_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 7. CHILD-TABLE RLS (workflow_steps / workflow_triggers)
-- operation_workflows → generic tenant RLS via 014 bootstrap
-- =====================================================

alter table public.workflow_steps enable row level security;

drop policy if exists workflow_steps_select on public.workflow_steps;
drop policy if exists workflow_steps_insert on public.workflow_steps;
drop policy if exists workflow_steps_update on public.workflow_steps;
drop policy if exists workflow_steps_delete on public.workflow_steps;

create policy workflow_steps_select on public.workflow_steps
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_steps.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_steps_insert on public.workflow_steps
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_steps.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_steps_update on public.workflow_steps
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_steps.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_steps.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_steps_delete on public.workflow_steps
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_steps.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

alter table public.workflow_triggers enable row level security;

drop policy if exists workflow_triggers_select on public.workflow_triggers;
drop policy if exists workflow_triggers_insert on public.workflow_triggers;
drop policy if exists workflow_triggers_update on public.workflow_triggers;
drop policy if exists workflow_triggers_delete on public.workflow_triggers;

create policy workflow_triggers_select on public.workflow_triggers
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_triggers.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_triggers_insert on public.workflow_triggers
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_triggers.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_triggers_update on public.workflow_triggers
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_triggers.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_triggers.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

create policy workflow_triggers_delete on public.workflow_triggers
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.operation_workflows ow
            where ow.id = workflow_triggers.workflow_id
              and public.has_tenant_access(ow.tenant_id)
        )
    );

-- Platform templates (tenant_id null) — admin-only write; authenticated read for clone UX
alter table public.operation_templates enable row level security;

drop policy if exists operation_templates_select on public.operation_templates;
drop policy if exists operation_templates_insert on public.operation_templates;
drop policy if exists operation_templates_update on public.operation_templates;
drop policy if exists operation_templates_delete on public.operation_templates;

create policy operation_templates_select on public.operation_templates
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

create policy operation_templates_insert on public.operation_templates
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy operation_templates_update on public.operation_templates
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    )
    with check (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

create policy operation_templates_delete on public.operation_templates
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (tenant_id is not null and public.has_tenant_access(tenant_id))
    );

-- =====================================================
-- END 006 OPERATIONS ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
