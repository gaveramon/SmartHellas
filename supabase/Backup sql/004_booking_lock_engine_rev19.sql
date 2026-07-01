-- =====================================================
-- 004 BOOKING & LOCK ENGINE (CLEAN DOMAIN RULE LAYER)
-- NO EXECUTION / NO QUEUES / NO NOTIFICATIONS / NO CODE GENERATION
-- =====================================================
--
-- ACCESS MODEL (SSOT HIERARCHY)
-- 1. property_access_schedules — property default check-in/out times (guest template)
-- 2. booking_access           — resolved guest window per booking (stored outcome)
-- 3. access_policies          — non-guest grants only (owner, emergency, temporary, scheduled)
-- 4. access_rules             — property exceptions only (override, emergency_access)
--
-- Composition: booking dates + property_access_schedules → booking_access.valid_from/until
-- 5. access_credentials       — issued grant metadata (vault ref, never plaintext codes)
-- Door code generation remains in 000; 004 stores grant records and windows only.
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

    updated_at timestamptz default now(),

    constraint chk_bookings_date_range check (start_date <= end_date)
);

create index if not exists idx_bookings_property
on bookings (property_id);

create index if not exists idx_bookings_tenant
on bookings (tenant_id);

create index if not exists idx_bookings_tenant_created
on bookings (tenant_id, created_at desc);

create index if not exists idx_bookings_property_dates
on bookings (property_id, start_date, end_date);

create trigger trg_bookings_updated_at
before update on bookings
for each row execute function platform.set_updated_at();

-- =====================================================
-- 1B. BOOKING TENANT CONSISTENCY (PROPERTY ↔ TENANT)
-- =====================================================

create or replace function public.enforce_booking_tenant_consistency()
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

    if new.tenant_id <> v_property_tenant then
        raise exception 'booking tenant_id must match property tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_bookings_tenant_consistency
before insert or update on public.bookings
for each row execute function public.enforce_booking_tenant_consistency();

-- =====================================================
-- 2. PROPERTY ACCESS SCHEDULE (GUEST WINDOW TEMPLATE — SSOT)
-- One row per property: default check-in/out times for guest stays.
-- =====================================================

create table if not exists property_access_schedules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    check_in_time time not null default '15:00',

    check_out_time time not null default '11:00',

    early_check_in_minutes int not null default 0,

    late_checkout_minutes int not null default 0,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (property_id),

    constraint chk_property_access_schedule_buffers check (
        early_check_in_minutes >= 0
        and late_checkout_minutes >= 0
    )
);

create index if not exists idx_property_access_schedules_tenant
on property_access_schedules (tenant_id);

comment on table public.property_access_schedules is
    'SSOT for guest stay window templates. Compose with booking dates to populate booking_access.';

create trigger trg_property_access_schedules_updated_at
before update on property_access_schedules
for each row execute function platform.set_updated_at();

-- =====================================================
-- 3. BOOKING ACCESS (RESOLVED GUEST WINDOW PER BOOKING)
-- Populated when a booking is confirmed — not generated here.
-- =====================================================

create table if not exists booking_access (
    id uuid primary key default gen_random_uuid(),

    booking_id uuid not null references bookings(id) on delete cascade,

    access_type access_type not null default 'guest',

    valid_from timestamptz not null,

    valid_until timestamptz not null,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    unique (booking_id),

    constraint chk_booking_access_guest_only check (access_type = 'guest'),

    constraint chk_booking_access_window check (valid_from < valid_until)
);

create index if not exists idx_booking_access_booking
on booking_access (booking_id);

create index if not exists idx_booking_access_window
on booking_access (valid_from, valid_until);

comment on table public.booking_access is
    'Resolved guest access window for a booking. valid_from/until = booking dates + property_access_schedules.';

-- =====================================================
-- 3B. BOOKING ACCESS CONSISTENCY (GUEST-ONLY)
-- =====================================================

create or replace function public.enforce_booking_access_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_booking record;
begin
    select b.property_id, b.tenant_id, b.status
    into v_booking
    from public.bookings b
    where b.id = new.booking_id;

    if not found then
        raise exception 'booking not found';
    end if;

    if new.access_type <> 'guest' then
        raise exception 'booking_access is guest-only; use access_policies for other access types';
    end if;

    return new;
end;
$$;

create trigger trg_booking_access_consistency
before insert or update on public.booking_access
for each row execute function public.enforce_booking_access_consistency();

create trigger trg_booking_access_updated_at
before update on booking_access
for each row execute function platform.set_updated_at();

-- =====================================================
-- 4. ACCESS POLICIES (NON-GUEST GRANTS ONLY)
-- Owner, emergency, temporary, and scheduled access outside bookings.
-- =====================================================

create table if not exists access_policies (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    access_type access_type not null,

    valid_from timestamptz not null,

    valid_until timestamptz not null,

    is_active boolean default true,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    constraint chk_access_policies_non_guest check (access_type <> 'guest'),

    constraint chk_access_policies_window check (valid_from < valid_until)
);

create index if not exists idx_access_policies_property
on access_policies (property_id);

create index if not exists idx_access_policies_property_active
on access_policies (property_id, is_active)
where is_active = true;

comment on table public.access_policies is
    'Non-guest access grants (owner, emergency, temporary, scheduled). Guest stays use booking_access.';

create trigger trg_access_policies_updated_at
before update on access_policies
for each row execute function platform.set_updated_at();

-- =====================================================
-- 5. ACCESS RULES (PROPERTY EXCEPTIONS ONLY)
-- Overrides and emergency rules — not the default guest schedule.
-- =====================================================

create table if not exists access_rules (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    property_id uuid not null references properties(id) on delete cascade,

    rule_type access_rule_type not null,

    rule_config jsonb,

    is_active boolean default true,

    created_at timestamptz default now(),

    constraint chk_access_rules_exceptions_only check (
        rule_type in ('override', 'emergency_access')
    )
);

create index if not exists idx_access_rules_property
on access_rules (property_id);

create index if not exists idx_access_rules_property_type
on access_rules (property_id, rule_type);

comment on table public.access_rules is
    'Property-level access exceptions. Default guest windows live in property_access_schedules.';

comment on column public.access_rules.rule_config is
    'Exception payload only. override: { reason, valid_from, valid_until }. emergency_access: { reason, contacts }.';

-- =====================================================
-- 6. LOCK DEVICE MAPPING (NO EXECUTION)
-- =====================================================

create table if not exists lock_devices (
    id uuid primary key default gen_random_uuid(),

    device_id uuid not null references devices(id) on delete cascade,

    property_id uuid not null references properties(id) on delete cascade,

    lock_provider integration_provider not null,

    is_primary boolean default false,

    created_at timestamptz default now(),

    unique (device_id)
);

create index if not exists idx_lock_devices_property
on lock_devices (property_id);

create unique index if not exists uq_lock_devices_primary_property
on lock_devices (property_id)
where is_primary = true;

-- =====================================================
-- 6B. LOCK DEVICE INTEGRITY (CATEGORY + TENANT)
-- =====================================================

create or replace function public.enforce_lock_device_integrity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_device record;
    v_property_tenant uuid;
begin
    select d.tenant_id, d.category
    into v_device
    from public.devices d
    where d.id = new.device_id;

    if not found then
        raise exception 'device not found';
    end if;

    if v_device.category <> 'lock' then
        raise exception 'lock_devices requires device category lock';
    end if;

    select p.tenant_id
    into v_property_tenant
    from public.properties p
    where p.id = new.property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if v_device.tenant_id <> v_property_tenant then
        raise exception 'lock device and property must belong to the same tenant';
    end if;

    return new;
end;
$$;

create trigger trg_lock_devices_integrity
before insert or update on public.lock_devices
for each row execute function public.enforce_lock_device_integrity();

-- =====================================================
-- 6C. ACCESS CREDENTIALS (ISSUED GRANT METADATA — NO GENERATION)
-- Records what was issued to which lock for a booking. PIN stored in vault (000).
-- =====================================================

create table if not exists access_credentials (
    id uuid primary key default gen_random_uuid(),

    tenant_id uuid not null,

    booking_id uuid not null references bookings(id) on delete cascade,

    lock_device_id uuid not null references lock_devices(id) on delete restrict,

    booking_access_id uuid references booking_access(id) on delete set null,

    provider integration_provider not null,

    credential_ref text not null,

    external_credential_id text,

    status access_credential_status not null default 'pending',

    valid_from timestamptz not null,

    valid_until timestamptz not null,

    revoked_at timestamptz,

    created_at timestamptz default now(),

    updated_at timestamptz default now(),

    constraint chk_access_credentials_window check (valid_from < valid_until),

    constraint chk_access_credentials_revoked check (
        status <> 'revoked' or revoked_at is not null
    )
);

create index if not exists idx_access_credentials_tenant
on access_credentials (tenant_id);

create index if not exists idx_access_credentials_booking
on access_credentials (booking_id);

create index if not exists idx_access_credentials_lock
on access_credentials (lock_device_id);

create index if not exists idx_access_credentials_status
on access_credentials (tenant_id, status);

create unique index if not exists uq_access_credentials_active_booking_lock
on access_credentials (booking_id, lock_device_id)
where status in ('pending', 'active');

comment on table public.access_credentials is
    'Issued door-code grant metadata per booking and lock. Never store plaintext PINs — use credential_ref (vault).';

comment on column public.access_credentials.credential_ref is
    'Opaque vault secret name or platform handle. Plaintext codes must not be stored here.';

comment on column public.access_credentials.external_credential_id is
    'Provider-side credential ID (e.g. TTLock keyboardPwdId) for revoke/sync in 000.';

create trigger trg_access_credentials_updated_at
before update on access_credentials
for each row execute function platform.set_updated_at();

-- =====================================================
-- 6D. ACCESS CREDENTIAL CONSISTENCY (BOOKING ↔ LOCK)
-- =====================================================

create or replace function public.enforce_access_credential_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_booking record;
    v_lock record;
    v_access record;
begin
    select b.tenant_id, b.property_id
    into v_booking
    from public.bookings b
    where b.id = new.booking_id;

    if not found then
        raise exception 'booking not found';
    end if;

    if new.tenant_id <> v_booking.tenant_id then
        raise exception 'credential tenant_id must match booking tenant_id';
    end if;

    select ld.property_id, ld.lock_provider
    into v_lock
    from public.lock_devices ld
    where ld.id = new.lock_device_id;

    if not found then
        raise exception 'lock device not found';
    end if;

    if v_lock.property_id <> v_booking.property_id then
        raise exception 'lock device must belong to the booking property';
    end if;

    if new.provider <> v_lock.lock_provider then
        raise exception 'credential provider must match lock device provider';
    end if;

    if new.booking_access_id is not null then
        select ba.booking_id, ba.valid_from, ba.valid_until
        into v_access
        from public.booking_access ba
        where ba.id = new.booking_access_id;

        if not found then
            raise exception 'booking_access not found';
        end if;

        if v_access.booking_id <> new.booking_id then
            raise exception 'booking_access must belong to the same booking';
        end if;
    end if;

    if new.status = 'revoked' and new.revoked_at is null then
        new.revoked_at := now();
    end if;

    return new;
end;
$$;

create trigger trg_access_credentials_consistency
before insert or update on public.access_credentials
for each row execute function public.enforce_access_credential_consistency();

-- =====================================================
-- 7. TENANT CONSISTENCY (PROPERTY-SCOPED TABLES)
-- =====================================================

create or replace function public.enforce_property_tenant_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_property_tenant uuid;
    v_property_id uuid;
begin
    v_property_id := case
        when tg_table_name = 'property_access_schedules' then new.property_id
        when tg_table_name = 'access_policies' then new.property_id
        when tg_table_name = 'access_rules' then new.property_id
    end;

    select p.tenant_id
    into v_property_tenant
    from public.properties p
    where p.id = v_property_id;

    if not found then
        raise exception 'property not found';
    end if;

    if new.tenant_id <> v_property_tenant then
        raise exception 'tenant_id must match property tenant_id';
    end if;

    return new;
end;
$$;

create trigger trg_property_access_schedules_tenant_consistency
before insert or update on public.property_access_schedules
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_access_policies_tenant_consistency
before insert or update on public.access_policies
for each row execute function public.enforce_property_tenant_consistency();

create trigger trg_access_rules_tenant_consistency
before insert or update on public.access_rules
for each row execute function public.enforce_property_tenant_consistency();

-- =====================================================
-- 8. TENANT FKs (DEFERRED — TENANTS EXIST FROM 002)
-- =====================================================

do $$
begin
    alter table public.bookings
        add constraint fk_bookings_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.property_access_schedules
        add constraint fk_property_access_schedules_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.access_policies
        add constraint fk_access_policies_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.access_rules
        add constraint fk_access_rules_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

do $$
begin
    alter table public.access_credentials
        add constraint fk_access_credentials_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
end $$;

-- =====================================================
-- 9. CHILD-TABLE RLS (NO tenant_id COLUMN — EXPLICIT POLICIES)
-- access_credentials has tenant_id — generic RLS via 014 bootstrap
-- =====================================================

alter table public.booking_access enable row level security;

drop policy if exists booking_access_select on public.booking_access;
drop policy if exists booking_access_insert on public.booking_access;
drop policy if exists booking_access_update on public.booking_access;
drop policy if exists booking_access_delete on public.booking_access;

create policy booking_access_select on public.booking_access
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.bookings b
            where b.id = booking_access.booking_id
              and public.has_tenant_access(b.tenant_id)
        )
    );

create policy booking_access_insert on public.booking_access
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.bookings b
            where b.id = booking_access.booking_id
              and public.has_tenant_access(b.tenant_id)
        )
    );

create policy booking_access_update on public.booking_access
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.bookings b
            where b.id = booking_access.booking_id
              and public.has_tenant_access(b.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.bookings b
            where b.id = booking_access.booking_id
              and public.has_tenant_access(b.tenant_id)
        )
    );

create policy booking_access_delete on public.booking_access
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.bookings b
            where b.id = booking_access.booking_id
              and public.has_tenant_access(b.tenant_id)
        )
    );

alter table public.lock_devices enable row level security;

drop policy if exists lock_devices_select on public.lock_devices;
drop policy if exists lock_devices_insert on public.lock_devices;
drop policy if exists lock_devices_update on public.lock_devices;
drop policy if exists lock_devices_delete on public.lock_devices;

create policy lock_devices_select on public.lock_devices
    for select to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = lock_devices.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy lock_devices_insert on public.lock_devices
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = lock_devices.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy lock_devices_update on public.lock_devices
    for update to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = lock_devices.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    )
    with check (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = lock_devices.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

create policy lock_devices_delete on public.lock_devices
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or exists (
            select 1
            from public.properties p
            where p.id = lock_devices.property_id
              and public.has_tenant_access(p.tenant_id)
        )
    );

-- =====================================================
-- END 004 BOOKING & LOCK ENGINE (CLEAN DOMAIN ONLY)
-- =====================================================
