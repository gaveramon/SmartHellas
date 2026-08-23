-- =====================================================
-- 006 OPERATIONS ENGINE (REV19)
-- DEFINITION LAYER + SUPPORT CASE DOMAIN
-- Operational blueprints only — advisory rules live in 012.optimization_rules.
-- NO EXECUTION / NO LOGGING / NO RUNTIME STATE
-- =====================================================

-- =====================================================
-- 1. OPERATION TEMPLATES (SYSTEM + TENANT BLUEPRINTS)
-- =====================================================

create table if not exists operation_templates (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid,

    is_system boolean not null default false,

    name text not null,

    description text,

    template jsonb not null,

    version int not null default 1,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint chk_operation_templates_system_scope check (
        (is_system and tenant_id is null)
        or (not is_system and tenant_id is not null)
    )
);

create index if not exists idx_operation_templates_tenant
    on operation_templates (tenant_id);

create index if not exists idx_operation_templates_tenant_created
    on operation_templates (tenant_id, created_at desc);

create index if not exists idx_operation_templates_system
    on operation_templates (is_system);

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

    is_active boolean not null default true,

    version int not null default 1,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);

create index if not exists idx_operation_workflows_tenant
    on operation_workflows (tenant_id);

create index if not exists idx_operation_workflows_created
    on operation_workflows (tenant_id, created_at desc);

create trigger trg_operation_workflows_updated_at
before update on operation_workflows
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. WORKFLOW STEPS (PIPELINE DEFINITION)
-- =====================================================

create table if not exists workflow_steps (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    step_order int not null,

    action_type automation_action_type not null,

    config jsonb not null default '{}'::jsonb,

    delay_seconds int not null default 0,

    created_at timestamptz not null default now(),

    unique (workflow_id, step_order),

    constraint chk_workflow_steps_order check (step_order > 0),
    constraint chk_workflow_steps_delay check (delay_seconds >= 0)
);

create index if not exists idx_workflow_steps_workflow
    on workflow_steps (workflow_id);

create index if not exists idx_workflow_steps_tenant_created
    on workflow_steps (tenant_id, created_at desc);

-- =====================================================
-- 4. WORKFLOW TRIGGERS (START CONDITIONS)
-- =====================================================

create table if not exists workflow_triggers (

    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    workflow_id uuid not null references operation_workflows(id) on delete cascade,

    property_id uuid references properties(id) on delete cascade,

    trigger_type automation_trigger_type not null,

    trigger_config jsonb not null default '{}'::jsonb,

    is_active boolean not null default true,

    created_at timestamptz not null default now(),

    unique (workflow_id, trigger_type, property_id)
);

create index if not exists idx_workflow_triggers_workflow
    on workflow_triggers (workflow_id);

create index if not exists idx_workflow_triggers_property
    on workflow_triggers (property_id)
    where property_id is not null;

create index if not exists idx_workflow_triggers_active
    on workflow_triggers (workflow_id, trigger_type)
    where is_active = true;

create index if not exists idx_workflow_triggers_property_type
    on workflow_triggers (property_id, trigger_type)
    where property_id is not null;

create index if not exists idx_workflow_triggers_workflow_created
    on workflow_triggers (workflow_id, created_at desc);

create index if not exists idx_workflow_triggers_tenant_created
    on workflow_triggers (tenant_id, created_at desc);

-- =====================================================
-- 5. SCOPE VALIDATION (TENANT CONSISTENCY)
-- =====================================================

create or replace function public.enforce_workflow_template_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_template_tenant uuid;
    v_template_is_system boolean;
begin

    if new.source_template_id is null then
        return new;
    end if;

    select tenant_id, is_system
    into v_template_tenant, v_template_is_system
    from public.operation_templates
    where id = new.source_template_id;

    if not found then
        raise exception 'template not found';
    end if;

    if v_template_is_system then
        return new;
    end if;

    if v_template_tenant is distinct from new.tenant_id then
        raise exception 'tenant mismatch between workflow and template';
    end if;

    return new;
end;
$$;

create trigger trg_operation_workflows_template_scope
before insert or update on operation_workflows
for each row execute function public.enforce_workflow_template_scope();

create or replace function public.enforce_workflow_trigger_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_tenant uuid;
    v_property_tenant uuid;
begin

    select tenant_id
    into v_tenant
    from public.operation_workflows
    where id = new.workflow_id;

    if not found then
        raise exception 'workflow not found';
    end if;

    if new.property_id is null then
        return new;
    end if;

    select tenant_id
    into v_property_tenant
    from public.properties
    where id = new.property_id;

    if v_property_tenant is distinct from v_tenant then
        raise exception 'tenant mismatch between workflow and property';
    end if;

    return new;
end;
$$;

create trigger trg_workflow_triggers_scope
before insert or update on workflow_triggers
for each row execute function public.enforce_workflow_trigger_scope();

create or replace function public.enforce_workflow_child_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_workflow_tenant uuid;
begin
    select w.tenant_id
    into v_workflow_tenant
    from public.operation_workflows w
    where w.id = new.workflow_id;

    if not found then
        raise exception 'workflow not found';
    end if;

    if new.tenant_id <> v_workflow_tenant then
        raise exception 'workflow child tenant_id must match operation_workflows tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_workflow_steps_tenant_consistency
before insert or update on public.workflow_steps
for each row execute function public.enforce_workflow_child_tenant_consistency();

create trigger trg_workflow_triggers_tenant_consistency
before insert or update on public.workflow_triggers
for each row execute function public.enforce_workflow_child_tenant_consistency();

-- =====================================================
-- 6. TENANT FKs
-- =====================================================

do $$
begin
    alter table public.operation_workflows
        add constraint fk_operation_workflows_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.operation_templates
        add constraint fk_operation_templates_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.workflow_steps
        add constraint fk_workflow_steps_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

do $$
begin
    alter table public.workflow_triggers
        add constraint fk_workflow_triggers_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception when duplicate_object then null;
end $$;

-- =====================================================
-- 7. RLS
-- =====================================================

alter table public.operation_templates enable row level security;

drop policy if exists operation_templates_select on public.operation_templates;
drop policy if exists operation_templates_insert on public.operation_templates;
drop policy if exists operation_templates_update on public.operation_templates;
drop policy if exists operation_templates_delete on public.operation_templates;

create policy operation_templates_select on public.operation_templates
    for select to authenticated
    using (
        platform.is_platform_admin()
        or is_system = true
        or public.has_tenant_access(tenant_id)
    );

create policy operation_templates_insert on public.operation_templates
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            not is_system
            and tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy operation_templates_update on public.operation_templates
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            not is_system
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            not is_system
            and tenant_id is not null
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy operation_templates_delete on public.operation_templates
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            not is_system
            and public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.operation_workflows enable row level security;

drop policy if exists operation_workflows_select on public.operation_workflows;
drop policy if exists operation_workflows_insert on public.operation_workflows;
drop policy if exists operation_workflows_update on public.operation_workflows;
drop policy if exists operation_workflows_delete on public.operation_workflows;

create policy operation_workflows_select on public.operation_workflows
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy operation_workflows_insert on public.operation_workflows
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy operation_workflows_update on public.operation_workflows
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy operation_workflows_delete on public.operation_workflows
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

-- =====================================================
-- 8. CHILD-TABLE RLS (tenant_id DENORMALIZED)
-- =====================================================

alter table public.workflow_steps enable row level security;

drop policy if exists workflow_steps_select on public.workflow_steps;
drop policy if exists workflow_steps_insert on public.workflow_steps;
drop policy if exists workflow_steps_update on public.workflow_steps;
drop policy if exists workflow_steps_delete on public.workflow_steps;

create policy workflow_steps_select on public.workflow_steps
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy workflow_steps_insert on public.workflow_steps
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy workflow_steps_update on public.workflow_steps
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy workflow_steps_delete on public.workflow_steps
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

alter table public.workflow_triggers enable row level security;

drop policy if exists workflow_triggers_select on public.workflow_triggers;
drop policy if exists workflow_triggers_insert on public.workflow_triggers;
drop policy if exists workflow_triggers_update on public.workflow_triggers;
drop policy if exists workflow_triggers_delete on public.workflow_triggers;

create policy workflow_triggers_select on public.workflow_triggers
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy workflow_triggers_insert on public.workflow_triggers
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy workflow_triggers_update on public.workflow_triggers
    for update to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    )
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy workflow_triggers_delete on public.workflow_triggers
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

-- =====================================================
-- 9. SUPPORT CASES (OPERATIONS SERVICE DOMAIN)
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

alter table public.support_tickets enable row level security;

drop policy if exists support_tickets_select on public.support_tickets;
drop policy if exists support_tickets_insert on public.support_tickets;
drop policy if exists support_tickets_update on public.support_tickets;
drop policy if exists support_tickets_delete on public.support_tickets;

create policy support_tickets_select on public.support_tickets
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_tickets_insert on public.support_tickets
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_tickets_update on public.support_tickets
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_tickets_delete on public.support_tickets
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

alter table public.support_messages enable row level security;

drop policy if exists support_messages_select on public.support_messages;
drop policy if exists support_messages_insert on public.support_messages;
drop policy if exists support_messages_update on public.support_messages;
drop policy if exists support_messages_delete on public.support_messages;

create policy support_messages_select on public.support_messages
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_messages_insert on public.support_messages
    for insert to authenticated
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_messages_update on public.support_messages
    for update to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))
    with check (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy support_messages_delete on public.support_messages
    for delete to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

-- =====================================================
-- END 006 OPERATIONS ENGINE
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('006_operations_engine_rev19', 'REV19.OPERATIONS', false)
on conflict (version) do nothing;