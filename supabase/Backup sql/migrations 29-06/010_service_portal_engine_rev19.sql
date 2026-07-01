-- =====================================================

-- 010 SERVICE & PORTAL ENGINE (CLEAN UI LAYER)

-- NO LOGS / NO EVENTS / NO DOMAIN TRUTH / NO SUPPORT CASES

-- =====================================================

--

-- Tenant config SSOT: tenant_portal_settings (replaces platform.tenant_settings).

-- Plan entitlements SSOT: feature_entitlements (009).

-- Support cases SSOT: support_tickets / support_messages (006).

-- Runtime logs SSOT: platform.event_log, operation_log, audit_log (000).

-- =====================================================



-- =====================================================

-- 1. TENANT PORTAL SETTINGS (UI CONFIGURATION SSOT)

-- =====================================================



create table if not exists tenant_portal_settings (

    id uuid primary key default gen_random_uuid(),



    tenant_id uuid not null references tenants(id) on delete cascade,



    theme jsonb,



    default_language text default 'en',



    created_at timestamptz default now(),



    updated_at timestamptz default now(),



    unique (tenant_id)

);



create index if not exists idx_portal_settings_tenant_created

on tenant_portal_settings (tenant_id, created_at desc);



create trigger trg_portal_settings_updated_at

before update on tenant_portal_settings

for each row execute function platform.set_updated_at();



comment on table public.tenant_portal_settings is

    'Tenant portal UI configuration SSOT. Platform infra must not duplicate tenant config.';



-- =====================================================

-- 2. DASHBOARD CONFIGURATION (LAYOUT DEFINITION)

-- =====================================================



create table if not exists dashboard_configs (

    id uuid primary key default gen_random_uuid(),



    tenant_id uuid not null references tenants(id) on delete cascade,



    name text not null,



    layout jsonb,



    is_default boolean default false,



    created_at timestamptz default now()

);



create index if not exists idx_dashboard_configs_tenant_created

on dashboard_configs (tenant_id, created_at desc);



create unique index if not exists idx_dashboard_configs_one_default_per_tenant

on dashboard_configs (tenant_id)

where is_default = true;



-- =====================================================

-- 3. PORTAL USER PREFERENCES (PER-USER UI STATE)

-- =====================================================



create table if not exists portal_user_preferences (

    id uuid primary key default gen_random_uuid(),



    tenant_id uuid not null references tenants(id) on delete cascade,



    user_id uuid not null references platform.profiles(id) on delete cascade,



    preference_key text not null,



    value jsonb not null default '{}'::jsonb,



    created_at timestamptz default now(),



    updated_at timestamptz default now(),



    unique (tenant_id, user_id, preference_key)

);



create index if not exists idx_portal_user_preferences_tenant_created

on portal_user_preferences (tenant_id, created_at desc);



create index if not exists idx_portal_user_preferences_user

on portal_user_preferences (tenant_id, user_id);



create trigger trg_portal_user_preferences_updated_at

before update on portal_user_preferences

for each row execute function platform.set_updated_at();



-- =====================================================

-- 4. PORTAL FEATURE FLAGS (UI-ONLY CONTROL)

-- Keys MUST use ui_ prefix — never overlap feature_entitlements (009).

-- =====================================================



create table if not exists portal_feature_flags (

    id uuid primary key default gen_random_uuid(),



    tenant_id uuid not null references tenants(id) on delete cascade,



    feature_key text not null,



    enabled boolean default true,

    created_at timestamptz not null default now(),

    unique (tenant_id, feature_key),



    constraint chk_portal_feature_flags_ui_prefix
        check (feature_key ~ '^ui_')
);



create index if not exists idx_portal_feature_flags_tenant

on portal_feature_flags (tenant_id);

create index if not exists idx_portal_feature_flags_tenant_created
on portal_feature_flags (tenant_id, created_at desc);

comment on table public.portal_feature_flags is

    'Portal UI visibility only (ui_* keys). Plan entitlements SSOT: feature_entitlements (009).';



-- =====================================================

-- 5. TENANT CONSISTENCY GUARDS

-- =====================================================



create or replace function public.enforce_portal_user_preference_membership()

returns trigger

language plpgsql

set search_path = ''

as $$

begin

    if not exists (

        select 1

        from public.tenant_memberships tm

        where tm.tenant_id = new.tenant_id

          and tm.user_id = new.user_id

          and tm.is_active = true

    ) then

        raise exception 'user_id must be an active member of tenant_id';

    end if;



    return new;

end;

$$;



create trigger trg_portal_user_preferences_membership

before insert or update on public.portal_user_preferences

for each row execute function public.enforce_portal_user_preference_membership();



-- =====================================================

-- 6. RLS

-- =====================================================



alter table public.tenant_portal_settings enable row level security;



drop policy if exists tenant_portal_settings_select on public.tenant_portal_settings;

drop policy if exists tenant_portal_settings_insert on public.tenant_portal_settings;

drop policy if exists tenant_portal_settings_update on public.tenant_portal_settings;

drop policy if exists tenant_portal_settings_delete on public.tenant_portal_settings;



create policy tenant_portal_settings_select on public.tenant_portal_settings

    for select to authenticated

    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy tenant_portal_settings_insert on public.tenant_portal_settings

    for insert to authenticated

    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy tenant_portal_settings_update on public.tenant_portal_settings

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



create policy tenant_portal_settings_delete on public.tenant_portal_settings

    for delete to authenticated

    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



alter table public.dashboard_configs enable row level security;



drop policy if exists dashboard_configs_select on public.dashboard_configs;

drop policy if exists dashboard_configs_insert on public.dashboard_configs;

drop policy if exists dashboard_configs_update on public.dashboard_configs;

drop policy if exists dashboard_configs_delete on public.dashboard_configs;



create policy dashboard_configs_select on public.dashboard_configs

    for select to authenticated

    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy dashboard_configs_insert on public.dashboard_configs

    for insert to authenticated

    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy dashboard_configs_update on public.dashboard_configs

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



create policy dashboard_configs_delete on public.dashboard_configs

    for delete to authenticated

    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



alter table public.portal_user_preferences enable row level security;



drop policy if exists portal_user_preferences_select on public.portal_user_preferences;

drop policy if exists portal_user_preferences_insert on public.portal_user_preferences;

drop policy if exists portal_user_preferences_update on public.portal_user_preferences;

drop policy if exists portal_user_preferences_delete on public.portal_user_preferences;



create policy portal_user_preferences_select on public.portal_user_preferences

    for select to authenticated

    using (
        platform.is_platform_admin()
        or (
            user_id = (select auth.uid())
            and public.has_tenant_access(tenant_id)
        )
    );



create policy portal_user_preferences_insert on public.portal_user_preferences

    for insert to authenticated

    with check (
        platform.is_platform_admin()
        or (
            user_id = (select auth.uid())
            and public.has_tenant_access(tenant_id)
        )
    );



create policy portal_user_preferences_update on public.portal_user_preferences

    for update to authenticated

    using (
        platform.is_platform_admin()
        or (
            user_id = (select auth.uid())
            and public.has_tenant_access(tenant_id)
        )
    )

    with check (
        platform.is_platform_admin()
        or (
            user_id = (select auth.uid())
            and public.has_tenant_access(tenant_id)
        )
    );



create policy portal_user_preferences_delete on public.portal_user_preferences

    for delete to authenticated

    using (
        platform.is_platform_admin()
        or (
            user_id = (select auth.uid())
            and public.has_tenant_access(tenant_id)
        )
    );



alter table public.portal_feature_flags enable row level security;



drop policy if exists portal_feature_flags_select on public.portal_feature_flags;

drop policy if exists portal_feature_flags_insert on public.portal_feature_flags;

drop policy if exists portal_feature_flags_update on public.portal_feature_flags;

drop policy if exists portal_feature_flags_delete on public.portal_feature_flags;



create policy portal_feature_flags_select on public.portal_feature_flags

    for select to authenticated

    using (platform.is_platform_admin() or public.has_tenant_access(tenant_id));



create policy portal_feature_flags_insert on public.portal_feature_flags

    for insert to authenticated

    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



create policy portal_feature_flags_update on public.portal_feature_flags

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



create policy portal_feature_flags_delete on public.portal_feature_flags

    for delete to authenticated

    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );



-- =====================================================

-- END 010 SERVICE & PORTAL ENGINE

-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('010_service_portal_engine_rev19', 'REV19.SERVICE.PORTAL', false)
on conflict (version) do nothing;

