-- =====================================================
-- 026 ONBOARDING LIFECYCLE EXTENSIONS (011)
-- Adds missing FK, tenant consistency, Appsmith view, read RPCs
-- Does NOT modify prior migrations
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('026_onboarding_lifecycle_extensions_rev19', 'REV19.ONBOARDING.LIFECYCLE.EXT', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. ONBOARDING LIFECYCLE STATE MACHINE (011 SSOT)
-- Enum SSOT: 001 — idempotent when 001 predates this type
-- =====================================================

do $$
begin
    if not exists (
        select 1
        from pg_type t
        join pg_namespace n on n.oid = t.typnamespace
        where t.typname = 'onboarding_lifecycle_state'
          and n.nspname = 'public'
    ) then
        create type public.onboarding_lifecycle_state as enum (
            'created',
            'pre_onboarding',
            'configured',
            'devices_assigned',
            'shipped',
            'installed',
            'verified',
            'active'
        );
    end if;
end $$;

create table if not exists onboarding_lifecycle (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    session_id uuid references onboarding_sessions(id) on delete set null,

    current_state public.onboarding_lifecycle_state not null default 'created',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    unique (property_id)
);

create index if not exists idx_onboarding_lifecycle_tenant
    on onboarding_lifecycle (tenant_id, updated_at desc);

create trigger trg_onboarding_lifecycle_updated_at
before update on onboarding_lifecycle
for each row execute function platform.set_updated_at();

create table if not exists onboarding_lifecycle_transitions (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    lifecycle_id uuid not null references onboarding_lifecycle(id) on delete cascade,

    from_state public.onboarding_lifecycle_state,

    to_state public.onboarding_lifecycle_state not null,

    metadata jsonb not null default '{}'::jsonb,

    created_at timestamptz not null default now()
);

create index if not exists idx_onboarding_lifecycle_transitions_lifecycle
    on onboarding_lifecycle_transitions (lifecycle_id, created_at desc);

create or replace function public.onboarding_lifecycle_allowed_transition(
    p_from public.onboarding_lifecycle_state,
    p_to public.onboarding_lifecycle_state
)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select case
        when p_from is null and p_to = 'created' then true
        when p_from = 'created' and p_to = 'pre_onboarding' then true
        when p_from = 'pre_onboarding' and p_to = 'configured' then true
        when p_from = 'configured' and p_to = 'devices_assigned' then true
        when p_from = 'devices_assigned' and p_to = 'shipped' then true
        when p_from = 'shipped' and p_to = 'installed' then true
        when p_from = 'installed' and p_to = 'verified' then true
        when p_from = 'verified' and p_to = 'active' then true
        else false
    end;
$$;

create or replace function public.onboarding_lifecycle_apply_transition(
    p_property_id uuid,
    p_to_state public.onboarding_lifecycle_state,
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_row public.onboarding_lifecycle%rowtype;
    v_from public.onboarding_lifecycle_state;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    select * into v_row
    from public.onboarding_lifecycle ol
    where ol.property_id = p_property_id and ol.tenant_id = v_tid
    for update;

    if not found then
        if p_to_state <> 'created' then
            raise exception 'lifecycle must start at created';
        end if;

        insert into public.onboarding_lifecycle (tenant_id, property_id, current_state)
        values (v_tid, p_property_id, 'created')
        returning * into v_row;

        v_from := null;
    else
        v_from := v_row.current_state;
    end if;

    if v_from = p_to_state then
        return to_jsonb(v_row);
    end if;

    if not public.onboarding_lifecycle_allowed_transition(v_from, p_to_state) then
        raise exception 'invalid onboarding lifecycle transition: % -> %', v_from, p_to_state;
    end if;

    update public.onboarding_lifecycle ol set
        current_state = p_to_state,
        updated_at = now()
    where ol.id = v_row.id
    returning * into v_row;

    insert into public.onboarding_lifecycle_transitions (
        tenant_id, lifecycle_id, from_state, to_state, metadata
    )
    values (v_tid, v_row.id, v_from, p_to_state, coalesce(p_metadata, '{}'::jsonb));

    perform public.insert_event(
        'onboarding.lifecycle.changed',
        jsonb_build_object(
            'property_id', p_property_id,
            'from_state', v_from,
            'to_state', p_to_state
        ) || coalesce(p_metadata, '{}'::jsonb)
    );

    return to_jsonb(v_row);
end;
$$;

revoke all on function public.onboarding_lifecycle_apply_transition(uuid, public.onboarding_lifecycle_state, jsonb) from public;
grant execute on function public.onboarding_lifecycle_apply_transition(uuid, public.onboarding_lifecycle_state, jsonb) to service_role;

alter table public.onboarding_lifecycle enable row level security;
alter table public.onboarding_lifecycle_transitions enable row level security;

select public._apply_public_tenant_rls('public.onboarding_lifecycle'::regclass);
select public._apply_public_tenant_rls('public.onboarding_lifecycle_transitions'::regclass);

-- =====================================================
-- 2. TENANT FK CONSTRAINTS (011 pattern)
-- =====================================================

do $$
begin
    alter table public.onboarding_lifecycle
        add constraint fk_onboarding_lifecycle_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.onboarding_lifecycle_transitions
        add constraint fk_onboarding_lifecycle_transitions_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

create index if not exists idx_onboarding_lifecycle_transitions_tenant_created
    on public.onboarding_lifecycle_transitions (tenant_id, created_at desc);

-- =====================================================
-- 3. TENANT CONSISTENCY TRIGGERS
-- =====================================================

create or replace function public.enforce_onboarding_lifecycle_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_property_tenant uuid;
    v_session_tenant uuid;
begin
    select p.tenant_id into v_property_tenant
    from public.properties p
    where p.id = new.property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if v_property_tenant is distinct from new.tenant_id then
        raise exception 'onboarding lifecycle property must belong to the same tenant';
    end if;

    if new.session_id is not null then
        select s.tenant_id into v_session_tenant
        from public.onboarding_sessions s
        where s.id = new.session_id;

        if not found then
            raise exception 'onboarding session not found';
        end if;

        if v_session_tenant is distinct from new.tenant_id then
            raise exception 'onboarding lifecycle session must belong to the same tenant';
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_onboarding_lifecycle_tenant_consistency on public.onboarding_lifecycle;
create trigger trg_onboarding_lifecycle_tenant_consistency
before insert or update on public.onboarding_lifecycle
for each row execute function public.enforce_onboarding_lifecycle_tenant_consistency();

create or replace function public.enforce_onboarding_lifecycle_transitions_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_lifecycle_tenant uuid;
begin
    select ol.tenant_id into v_lifecycle_tenant
    from public.onboarding_lifecycle ol
    where ol.id = new.lifecycle_id;

    if not found then
        raise exception 'onboarding lifecycle not found';
    end if;

    if v_lifecycle_tenant is distinct from new.tenant_id then
        raise exception 'onboarding lifecycle transition tenant mismatch';
    end if;

    return new;
end;
$$;

drop trigger if exists trg_onboarding_lifecycle_transitions_consistency on public.onboarding_lifecycle_transitions;
create trigger trg_onboarding_lifecycle_transitions_consistency
before insert or update on public.onboarding_lifecycle_transitions
for each row execute function public.enforce_onboarding_lifecycle_transitions_consistency();

-- =====================================================
-- 4. DOMAIN READ FUNCTIONS (011 — no Edge guards)
-- =====================================================

create or replace function public.onboarding_lifecycle_get(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_result jsonb;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    select to_jsonb(t) into v_result
    from (
        select
            ol.id,
            ol.tenant_id,
            ol.property_id,
            ol.session_id,
            ol.current_state,
            ol.created_at,
            ol.updated_at
        from public.onboarding_lifecycle ol
        where ol.property_id = p_property_id
          and ol.tenant_id = v_tid
    ) t;

    return coalesce(v_result, 'null'::jsonb);
end;
$$;

create or replace function public.onboarding_lifecycle_list_transitions(p_property_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_result jsonb;
begin
    v_tid := platform.current_tenant_id();
    if v_tid is null then
        raise exception 'no active tenant';
    end if;

    select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb)
    into v_result
    from (
        select
            olt.id,
            olt.lifecycle_id,
            olt.from_state,
            olt.to_state,
            olt.metadata,
            olt.created_at
        from public.onboarding_lifecycle_transitions olt
        join public.onboarding_lifecycle ol on ol.id = olt.lifecycle_id
        where ol.property_id = p_property_id
          and olt.tenant_id = v_tid
    ) t;

    return v_result;
end;
$$;

revoke all on function public.onboarding_lifecycle_get(uuid) from public;
grant execute on function public.onboarding_lifecycle_get(uuid) to service_role;

revoke all on function public.onboarding_lifecycle_list_transitions(uuid) from public;
grant execute on function public.onboarding_lifecycle_list_transitions(uuid) to service_role;

-- =====================================================
-- 5. UI VIEWS (Appsmith read contract)
-- =====================================================

drop view if exists public.v_onboarding_lifecycle;
drop view if exists public.v_properties_overview;
drop view if exists public.v_onboarding_progress;

create or replace view public.v_properties_overview
with (security_invoker = true)
as
select
    p.id,
    p.tenant_id,
    p.name,
    p.address,
    p.property_type,
    p.timezone,
    count(distinct r.id) as room_count,
    count(distinct d.id) as device_count,
    ol.current_state as onboarding_lifecycle_state,
    p.created_at,
    p.updated_at
from public.properties p
left join public.rooms r on r.property_id = p.id
left join public.device_assignments da on da.room_id = r.id
left join public.devices d on d.id = da.device_id and d.is_active = true
left join public.onboarding_lifecycle ol on ol.property_id = p.id
group by p.id, ol.current_state;

create or replace view public.v_onboarding_progress
with (security_invoker = true)
as
select
    os.id as session_id,
    os.tenant_id,
    os.property_id,
    p.name as property_name,
    os.status as session_status,
    os.current_step,
    ol.current_state as lifecycle_state,
    count(*) filter (where ss.status = 'completed') as completed_steps,
    count(*) as total_steps,
    os.created_at,
    os.updated_at
from public.onboarding_sessions os
join public.properties p on p.id = os.property_id
left join public.onboarding_lifecycle ol on ol.property_id = os.property_id
left join public.onboarding_step_state ss on ss.session_id = os.id
group by os.id, p.name, ol.current_state;

create or replace view public.v_onboarding_lifecycle_overview
with (security_invoker = true)
as
select
    ol.id,
    ol.tenant_id,
    ol.property_id,
    p.name as property_name,
    ol.session_id,
    os.status as session_status,
    ol.current_state,
    (
        select count(*)
        from public.onboarding_lifecycle_transitions olt
        where olt.lifecycle_id = ol.id
    ) as transition_count,
    (
        select olt.created_at
        from public.onboarding_lifecycle_transitions olt
        where olt.lifecycle_id = ol.id
        order by olt.created_at desc
        limit 1
    ) as last_transition_at,
    ol.created_at,
    ol.updated_at
from public.onboarding_lifecycle ol
join public.properties p on p.id = ol.property_id
left join public.onboarding_sessions os on os.id = ol.session_id;

grant select on public.v_onboarding_lifecycle_overview to authenticated;

-- =====================================================
-- END 026 ONBOARDING LIFECYCLE EXTENSIONS
-- =====================================================
