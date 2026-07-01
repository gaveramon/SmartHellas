-- =====================================================
-- 011 ONBOARDING ENGINE (CLEAN STATE TRACKING LAYER)
-- NO EXECUTION / NO AUTOMATION / NO SIDE EFFECTS
-- =====================================================
--
-- Wizard state, QR pairing outcomes, room/device mapping input,
-- and progress tracking only. QR minting and step orchestration → 000.
-- Flow definition → 007 onboarding_blueprints / preconfig_templates.
-- =====================================================

-- =====================================================
-- 1. ONBOARDING SESSIONS (PER TENANT PROPERTY)
-- =====================================================

create table if not exists onboarding_sessions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null,

    preconfig_template_id uuid references preconfig_templates(id) on delete set null,

    onboarding_blueprint_id uuid references onboarding_blueprints(id) on delete set null,

    status onboarding_status default 'not_started',

    current_step onboarding_step_type,

    created_at timestamptz default now(),

    updated_at timestamptz default now()
);

create index if not exists idx_onboarding_sessions_tenant_created
on onboarding_sessions (tenant_id, created_at desc);

create index if not exists idx_onboarding_sessions_property
on onboarding_sessions (property_id);

create unique index if not exists uq_onboarding_sessions_property_active
on onboarding_sessions (property_id)
where status in ('not_started', 'in_progress', 'waiting_user');

create trigger trg_onboarding_sessions_updated_at
before update on onboarding_sessions
for each row execute function platform.set_updated_at();

comment on column public.onboarding_sessions.preconfig_template_id is
    'Links wizard to global 007 preconfig_templates / onboarding_blueprints. Tenant selection only — no tenant-owned templates.';

comment on column public.onboarding_sessions.onboarding_blueprint_id is
    'Optional traceability FK to 007 onboarding_blueprints. May mirror preconfig_templates.onboarding_blueprint_id.';

comment on column public.onboarding_sessions.current_step is
    'Denormalized wizard pointer; canonical progress lives in onboarding_step_state.';

-- =====================================================
-- 2. ONBOARDING STEPS STATE (PROGRESS TRACKING ONLY)
-- =====================================================

create table if not exists onboarding_step_state (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    step_type onboarding_step_type not null,

    status onboarding_step_status not null default 'pending',

    completed_at timestamptz,

    unique (session_id, step_type)
);

create index if not exists idx_onboarding_step_state_session
on onboarding_step_state (session_id);

create index if not exists idx_onboarding_step_state_tenant
on onboarding_step_state (tenant_id);

-- =====================================================
-- 3. ROOM MAPPING INPUT (USER-DEFINED STRUCTURE)
-- =====================================================

create table if not exists onboarding_room_mapping (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    room_name text not null,

    room_type room_type,

    promoted_room_id uuid references rooms(id) on delete set null,

    created_at timestamptz default now(),

    unique (session_id, room_name)
);

create index if not exists idx_onboarding_room_mapping_session
on onboarding_room_mapping (session_id);

create index if not exists idx_onboarding_room_mapping_tenant_created
on onboarding_room_mapping (tenant_id, created_at desc);

comment on column public.onboarding_room_mapping.promoted_room_id is
    'Set after wizard promotes draft mapping into 003 rooms SSOT.';

-- =====================================================
-- 4. DEVICE PLACEMENT + QR PAIRING STATE (NO EXECUTION)
-- =====================================================

create table if not exists onboarding_device_mapping (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    category_code text references public.device_categories(code),

    room_name text,

    desired_action text,

    device_id uuid references devices(id) on delete set null,

    scan_status onboarding_step_status default 'pending',

    scanned_at timestamptz,

    created_at timestamptz default now(),

    unique (session_id, category_code, room_name)
);

create index if not exists idx_onboarding_device_mapping_session
on onboarding_device_mapping (session_id);

create index if not exists idx_onboarding_device_mapping_tenant_created
on onboarding_device_mapping (tenant_id, created_at desc);

comment on column public.onboarding_device_mapping.device_id is
    'Populated after QR scan pairs hardware into 003 devices registry.';
comment on column public.onboarding_device_mapping.scan_status is
    'QR pairing outcome only — token generation belongs in 000 / app layer.';

-- =====================================================
-- 5. ONBOARDING CHECKLIST (BUSINESS VALIDATION STATE)
-- =====================================================

create table if not exists onboarding_checklist (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    checklist_key text not null,
    -- wifi_connected, devices_received, app_installed

    is_completed boolean default false,

    updated_at timestamptz default now(),

    unique (session_id, checklist_key)
);

create index if not exists idx_onboarding_checklist_session
on onboarding_checklist (session_id);

create index if not exists idx_onboarding_checklist_tenant
on onboarding_checklist (tenant_id);

create trigger trg_onboarding_checklist_updated_at
before update on onboarding_checklist
for each row execute function platform.set_updated_at();

-- =====================================================
-- 6. ONBOARDING NOTES (SUPPORT + CONTEXT ONLY)
-- =====================================================

create table if not exists onboarding_notes (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    session_id uuid not null references onboarding_sessions(id) on delete cascade,

    author_user_id uuid references platform.profiles(id) on delete set null,

    note text,

    created_at timestamptz default now()
);

create index if not exists idx_onboarding_notes_session
on onboarding_notes (session_id);

create index if not exists idx_onboarding_notes_tenant_created
on onboarding_notes (tenant_id, created_at desc);

-- =====================================================
-- 7. TENANT / PROPERTY FKs + CONSISTENCY (DEFERRED)
-- =====================================================

do $$
begin
    alter table public.onboarding_sessions
        add constraint fk_onboarding_sessions_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_sessions
        add constraint fk_onboarding_sessions_property
        foreign key (property_id) references public.properties(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

create or replace function public.enforce_onboarding_session_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_property_tenant uuid;
begin
    select p.tenant_id
    into v_property_tenant
    from public.properties p
    where p.id = new.property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if v_property_tenant <> new.tenant_id then
        raise exception 'onboarding session property must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_onboarding_sessions_tenant_consistency
before insert or update on public.onboarding_sessions
for each row execute function public.enforce_onboarding_session_tenant_consistency();

create or replace function public.enforce_onboarding_room_mapping_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_session record;
begin
    if new.promoted_room_id is null then
        return new;
    end if;

    select s.property_id, s.tenant_id
    into v_session
    from public.onboarding_sessions s
    where s.id = new.session_id;

    if not found then
        raise exception 'onboarding session not found';
    end if;

    if not exists (
        select 1
        from public.rooms r
        join public.properties p on p.id = r.property_id
        where r.id = new.promoted_room_id
          and r.property_id = v_session.property_id
          and p.tenant_id = v_session.tenant_id
    ) then
        raise exception 'promoted room must belong to the onboarding session property and tenant';
    end if;

    return new;
end;
$$;

create trigger trg_onboarding_room_mapping_consistency
before insert or update on public.onboarding_room_mapping
for each row execute function public.enforce_onboarding_room_mapping_consistency();

create or replace function public.enforce_onboarding_device_mapping_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_session_tenant uuid;
    v_device_tenant uuid;
begin
    if new.device_id is null then
        return new;
    end if;

    select s.tenant_id
    into v_session_tenant
    from public.onboarding_sessions s
    where s.id = new.session_id;

    if not found then
        raise exception 'onboarding session not found';
    end if;

    select d.tenant_id
    into v_device_tenant
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    if v_device_tenant <> v_session_tenant then
        raise exception 'paired device must belong to the onboarding session tenant';
    end if;

    return new;
end;
$$;

create trigger trg_onboarding_device_mapping_consistency
before insert or update on public.onboarding_device_mapping
for each row execute function public.enforce_onboarding_device_mapping_consistency();

create or replace function public.enforce_onboarding_child_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_session_tenant uuid;
begin
    select s.tenant_id
    into v_session_tenant
    from public.onboarding_sessions s
    where s.id = new.session_id;

    if not found then
        raise exception 'onboarding session not found';
    end if;

    new.tenant_id := v_session_tenant;

    return new;
end;
$$;

create trigger trg_onboarding_step_state_tenant_consistency
before insert or update on public.onboarding_step_state
for each row execute function public.enforce_onboarding_child_tenant_consistency();

create trigger trg_onboarding_room_mapping_tenant_consistency
before insert or update on public.onboarding_room_mapping
for each row execute function public.enforce_onboarding_child_tenant_consistency();

create trigger trg_onboarding_device_mapping_tenant_consistency
before insert or update on public.onboarding_device_mapping
for each row execute function public.enforce_onboarding_child_tenant_consistency();

create trigger trg_onboarding_checklist_tenant_consistency
before insert or update on public.onboarding_checklist
for each row execute function public.enforce_onboarding_child_tenant_consistency();

create trigger trg_onboarding_notes_tenant_consistency
before insert or update on public.onboarding_notes
for each row execute function public.enforce_onboarding_child_tenant_consistency();

create or replace function public.enforce_onboarding_session_blueprint_trace()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_template_blueprint uuid;
begin
    if new.onboarding_blueprint_id is null or new.preconfig_template_id is null then
        return new;
    end if;

    select pt.onboarding_blueprint_id
    into v_template_blueprint
    from public.preconfig_templates pt
    where pt.id = new.preconfig_template_id;

    if v_template_blueprint is not null
       and v_template_blueprint is distinct from new.onboarding_blueprint_id then
        raise exception 'onboarding_blueprint_id must match preconfig_templates.onboarding_blueprint_id';
    end if;

    return new;
end;
$$;

create trigger trg_onboarding_sessions_blueprint_trace
before insert or update on public.onboarding_sessions
for each row execute function public.enforce_onboarding_session_blueprint_trace();

-- =====================================================
-- 8. RLS
-- onboarding_sessions: explicit tenant RLS (not 014 bootstrap)
-- Child tables: session join; mutations admin/manager
-- =====================================================

alter table public.onboarding_sessions enable row level security;

drop policy if exists onboarding_sessions_select on public.onboarding_sessions;
drop policy if exists onboarding_sessions_insert on public.onboarding_sessions;
drop policy if exists onboarding_sessions_update on public.onboarding_sessions;
drop policy if exists onboarding_sessions_delete on public.onboarding_sessions;

create policy onboarding_sessions_select on public.onboarding_sessions
    for select to authenticated
    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));

create policy onboarding_sessions_insert on public.onboarding_sessions
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

create policy onboarding_sessions_update on public.onboarding_sessions
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

create policy onboarding_sessions_delete on public.onboarding_sessions
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

do $$
declare
    v_table text;
begin
    foreach v_table in array array[
        'onboarding_step_state',
        'onboarding_room_mapping',
        'onboarding_device_mapping',
        'onboarding_checklist',
        'onboarding_notes'
    ] loop
        execute format('alter table public.%I enable row level security', v_table);
        execute format('drop policy if exists %1$s_select on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_insert on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_update on public.%1$I', v_table);
        execute format('drop policy if exists %1$s_delete on public.%1$I', v_table);
        execute format(
            'create policy %1$s_select on public.%1$I for select to authenticated using (platform.is_platform_admin() or public.has_tenant_access(tenant_id))',
            v_table
        );
        execute format(
            'create policy %1$s_insert on public.%1$I for insert to authenticated with check (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
        execute format(
            'create policy %1$s_update on public.%1$I for update to authenticated using (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager'')))) with check (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
        execute format(
            'create policy %1$s_delete on public.%1$I for delete to authenticated using (platform.is_platform_admin() or (public.has_tenant_access(tenant_id) and (platform.is_admin() or platform.has_role(''manager''))))',
            v_table
        );
    end loop;
end $$;

-- =====================================================
-- END 011 ONBOARDING ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================

do $$
begin
    alter table public.onboarding_step_state
        add constraint fk_onboarding_step_state_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_room_mapping
        add constraint fk_onboarding_room_mapping_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_device_mapping
        add constraint fk_onboarding_device_mapping_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_checklist
        add constraint fk_onboarding_checklist_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_notes
        add constraint fk_onboarding_notes_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('011_onboarding_engine_rev19', 'REV19.ONBOARDING', false)
on conflict (version) do nothing;
