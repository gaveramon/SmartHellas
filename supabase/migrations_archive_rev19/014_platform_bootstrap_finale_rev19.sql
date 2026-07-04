-- =====================================================
-- 014 PLATFORM BOOTSTRAP FINALE (REV19)
-- Mandatory production gate — runs after full domain stack (002–013)
-- =====================================================
--
-- Responsibilities:
-- 1. Post-domain column/type binds (001 SSOT → 000 platform columns)
-- 2. Safety-net generic tenant RLS for uncovered public.tenant_id tables only
-- 3. pg_cron wiring for platform maintenance workers (platform.ensure_pg_cron_jobs)
-- 4. Commerce ↔ platform cross-schema binds (009/005 → 000)
-- 5. Authenticated grants + default privileges for post-014 migrations
--
-- RLS precedence:
-- - Domain modules (002–015) MUST define explicit policies where role gates differ
-- - Module 015 (CRM) runs after this file and MUST enable + force RLS locally
-- - This file applies public._apply_public_tenant_rls() ONLY when zero policies exist
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('014_platform_bootstrap_finale', 'REV19.PLATFORM.BOOTSTRAP', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. POST-DOMAIN TYPE BINDS (001 SSOT → 000 PLATFORM)
-- =====================================================

select platform.bind_operation_context_type_column();

-- =====================================================
-- 2. SAFETY-NET TENANT RLS (UNCOVERED public.tenant_id TABLES ONLY)
-- Skips tables that already have any policy (custom domain RLS preserved)
-- =====================================================

do $$
declare
    v_row record;
begin
    for v_row in
        select distinct c.table_name
        from information_schema.columns c
        join information_schema.tables t
          on t.table_schema = c.table_schema
         and t.table_name = c.table_name
        where c.table_schema = 'public'
          and c.column_name = 'tenant_id'
          and t.table_type = 'BASE TABLE'
          and not exists (
              select 1
              from pg_policies p
              where p.schemaname = 'public'
                and p.tablename = c.table_name
          )
        order by c.table_name
    loop
        perform public._apply_public_tenant_rls(
            format('public.%I', v_row.table_name)::regclass
        );
        raise notice '014 bootstrap: applied generic tenant RLS to public.%', v_row.table_name;
    end loop;
end $$;

-- =====================================================
-- 3. POST-BOOTSTRAP RLS VERIFICATION (WARN ONLY)
-- =====================================================

do $$
declare
    v_row record;
begin
    for v_row in
        select distinct c.table_name
        from information_schema.columns c
        join information_schema.tables t
          on t.table_schema = c.table_schema
         and t.table_name = c.table_name
        join pg_class pc
          on pc.relname = c.table_name
        join pg_namespace pn
          on pn.oid = pc.relnamespace
         and pn.nspname = 'public'
        where c.table_schema = 'public'
          and c.column_name = 'tenant_id'
          and t.table_type = 'BASE TABLE'
          and (
              not pc.relrowsecurity
              or not exists (
                  select 1
                  from pg_policies p
                  where p.schemaname = 'public'
                    and p.tablename = c.table_name
              )
          )
        order by c.table_name
    loop
        raise warning
            '014 bootstrap: public.% has tenant_id but RLS is disabled or has no policies',
            v_row.table_name;
    end loop;
end $$;

-- =====================================================
-- 4. pg_cron JOB WIRING (idempotent; re-callable via ensure_pg_cron_jobs)
-- =====================================================

create or replace function platform.ensure_pg_cron_jobs()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_job record;
begin
    if not exists (select 1 from pg_extension where extname = 'pg_cron') then
        begin
            create extension pg_cron with schema pg_catalog;
        exception
            when duplicate_object then null;
            when others then
                raise warning '014 bootstrap: pg_cron extension unavailable — invoke platform.run_platform_cron_tick() and platform.run_platform_daily_maintenance() externally, or call platform.ensure_pg_cron_jobs() after enabling pg_cron';
                return false;
        end;
    end if;

    if not exists (select 1 from pg_extension where extname = 'pg_cron') then
        raise warning '014 bootstrap: pg_cron extension missing — invoke platform.run_platform_cron_tick() and platform.run_platform_daily_maintenance() externally, or call platform.ensure_pg_cron_jobs() after enabling pg_cron';
        return false;
    end if;

    grant usage on schema cron to postgres;
    grant all privileges on all tables in schema cron to postgres;

    for v_job in
        select jobid
        from cron.job
        where jobname in ('platform-cron-tick', 'platform-daily-maintenance')
    loop
        perform cron.unschedule(v_job.jobid);
    end loop;

    perform cron.schedule(
        'platform-cron-tick',
        '* * * * *',
        $cmd$select platform.run_platform_cron_tick();$cmd$
    );

    perform cron.schedule(
        'platform-daily-maintenance',
        '15 2 * * *',
        $cmd$select platform.run_platform_daily_maintenance();$cmd$
    );

    return true;
end;
$$;

revoke all on function platform.ensure_pg_cron_jobs() from public, authenticated;
grant execute on function platform.ensure_pg_cron_jobs() to service_role;

select platform.ensure_pg_cron_jobs();

insert into platform.scheduled_jobs (job_name, cron_expression, handler, is_active, metadata)
select *
from (
    values
        (
            'platform-cron-tick',
            '* * * * *',
            'platform.run_platform_cron_tick',
            true,
            '{"description":"Watchdog + retry queues"}'::jsonb
        ),
        (
            'platform-daily-maintenance',
            '15 2 * * *',
            'platform.run_platform_daily_maintenance',
            true,
            '{"description":"Partition ensure + log retention purge + service activation sync"}'::jsonb
        )
) as v(job_name, cron_expression, handler, is_active, metadata)
where not exists (
    select 1
    from platform.scheduled_jobs sj
    where sj.job_name = v.job_name
);

update platform.scheduled_jobs
set is_active = exists (select 1 from pg_extension where extname = 'pg_cron'),
    metadata = case
        when exists (select 1 from pg_extension where extname = 'pg_cron')
        then coalesce(metadata, '{}'::jsonb) - 'pg_cron_missing'
        else coalesce(metadata, '{}'::jsonb) || '{"pg_cron_missing":true}'::jsonb
    end
where job_name in ('platform-cron-tick', 'platform-daily-maintenance');

-- =====================================================
-- 5. SERVICE ACTIVATION PROJECTION SYNC (013 SSOT → WORKER)
-- Writes service_activation_state (013) only via service_role.
-- SSOT remains subscriptions (002) + feature_entitlements (009).
-- =====================================================

create or replace function platform.sync_service_activation_state()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.service_activation_state sas
    set status = 'inactive'::public.service_activation_status,
        updated_at = now()
    where sas.source_subscription_id is not null
      and not exists (
          select 1
          from public.subscriptions s
          where s.id = sas.source_subscription_id
            and s.status in ('trial', 'pending', 'active', 'past_due')
      );

    insert into public.service_activation_state (
        tenant_id,
        service_type,
        status,
        source_subscription_id
    )
    select
        ae.tenant_id,
        ae.service_type,
        case
            when ae.subscription_status in ('active', 'past_due') then 'active'::public.service_activation_status
            when ae.subscription_status in ('trial', 'pending') then 'pending'::public.service_activation_status
            else 'inactive'::public.service_activation_status
        end,
        ae.subscription_id
    from (
        select distinct
            s.tenant_id,
            s.id as subscription_id,
            s.status as subscription_status,
            case fe.feature_key
                when 'auto_door_code' then 'auto_door_code'::public.service_type
                when 'energy_reports' then 'energy_optimization'::public.service_type
                when 'energy_optimization' then 'energy_optimization'::public.service_type
                when 'security_monitoring' then 'security_monitoring'::public.service_type
                when 'managed_service' then 'managed_service'::public.service_type
            end as service_type
        from public.subscriptions s
        join public.feature_entitlements fe
          on fe.plan_id = s.plan_id
         and fe.enabled = true
        where s.plan_id is not null
          and s.status in ('trial', 'pending', 'active', 'past_due')
    ) ae
    where ae.service_type is not null
    on conflict (tenant_id, service_type) where property_id is null
    do update set
        status = excluded.status,
        source_subscription_id = excluded.source_subscription_id,
        updated_at = now();
end;
$$;

revoke all on function platform.sync_service_activation_state() from public, authenticated;
grant execute on function platform.sync_service_activation_state() to service_role;

create or replace function platform.run_platform_daily_maintenance()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_started timestamptz := clock_timestamp();
    v_elapsed_ms int;
begin
    perform platform.ensure_log_partitions(3);
    perform platform.purge_expired_logs();
    perform platform.sync_service_activation_state();

    v_elapsed_ms := (extract(epoch from (clock_timestamp() - v_started)) * 1000)::int;

    perform platform.log_job_execution(
        null,
        'success',
        v_elapsed_ms,
        null,
        gen_random_uuid(),
        1
    );
end;
$$;

revoke all on function platform.run_platform_daily_maintenance() from public, authenticated;
grant execute on function platform.run_platform_daily_maintenance() to service_role;

-- =====================================================
-- 5B. COMMERCE ↔ PLATFORM BRIDGE (009/005 → 000)
-- Cross-schema binds live here — not in business modules.
-- =====================================================

do $$
begin
    alter table platform.payment_intents
        alter column status drop default;

    alter table platform.payment_intents
        alter column status type payment_status using status::payment_status;

    alter table platform.payment_intents
        alter column status set default 'pending'::payment_status;

    alter table platform.payment_events
        alter column old_status type payment_status using old_status::payment_status;

    alter table platform.payment_events
        alter column new_status type payment_status using new_status::payment_status;
exception
    when undefined_table then null;
    when undefined_object then null;
end $$;

do $$
begin
    alter table platform.payment_intents
        add constraint fk_payment_intents_provider_code
        foreign key (provider) references public.integration_providers(code);
exception
    when duplicate_object then null;
    when undefined_table then null;
end $$;

do $$
begin
    alter table platform.payment_provider_refs
        add constraint fk_payment_provider_refs_provider_code
        foreign key (provider) references public.integration_providers(code);
exception
    when duplicate_object then null;
    when undefined_table then null;
end $$;

do $$
begin
    alter table platform.payment_intents
        add constraint chk_payment_intents_target_type
        check (target_type in ('subscription', 'proposal', 'invoice'));
exception
    when duplicate_object then null;
    when undefined_table then null;
end $$;

create or replace function platform.enforce_payment_intent_target_tenant()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.target_type = 'subscription' then
        if not exists (
            select 1
            from public.subscriptions s
            where s.id = new.target_id
              and s.tenant_id = new.tenant_id
        ) then
            raise exception 'payment_intent target subscription must belong to tenant_id';
        end if;
    elsif new.target_type = 'proposal' then
        if not exists (
            select 1
            from public.customer_proposals cp
            where cp.id = new.target_id
              and cp.tenant_id = new.tenant_id
        ) then
            raise exception 'payment_intent target proposal must belong to tenant_id';
        end if;
    elsif new.target_type = 'invoice' then
        if to_regclass('public.invoices') is null then
            raise exception 'payment_intent target_type invoice requires public.invoices table';
        end if;

        if not exists (
            select 1
            from public.invoices inv
            where inv.id = new.target_id
              and inv.tenant_id = new.tenant_id
        ) then
            raise exception 'payment_intent target invoice must belong to tenant_id';
        end if;
    else
        raise exception 'payment_intent target_type % is not allowed', new.target_type;
    end if;

    return new;
end;
$$;

drop trigger if exists trg_payment_intents_target_tenant on platform.payment_intents;

create trigger trg_payment_intents_target_tenant
before insert or update of tenant_id, target_type, target_id on platform.payment_intents
for each row execute function platform.enforce_payment_intent_target_tenant();

do $$
begin
    alter table platform.payment_intents
        add constraint fk_payment_intents_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
    when undefined_table then null;
end $$;

do $$
begin
    alter table platform.webhook_provider_tenant_map
        add constraint fk_webhook_provider_tenant_map_tenant
        foreign key (tenant_id) references public.tenants(id) on delete cascade;
exception
    when duplicate_object then null;
    when undefined_table then null;
end $$;

revoke all on function platform.enforce_payment_intent_target_tenant() from public, authenticated;
grant execute on function platform.enforce_payment_intent_target_tenant() to service_role;

-- =====================================================
-- 6. AUTHENTICATED ROLE GRANTS (RLS gate — policies enforce isolation)
-- Canonical authenticated grants live here (000 grants service_role only).
-- =====================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

grant usage on schema platform to authenticated;
grant select on all tables in schema platform to authenticated;
grant update on table platform.profiles to authenticated;

-- =====================================================
-- 6B. DEFAULT PRIVILEGES (tables created in migrations after 014, e.g. 015+)
-- =====================================================

alter default privileges for role postgres in schema public
    grant select, insert, update, delete on tables to authenticated;

alter default privileges for role postgres in schema public
    grant usage, select on sequences to authenticated;

alter default privileges for role postgres in schema public
    grant all on tables to service_role;

alter default privileges for role postgres in schema public
    grant usage, select on sequences to service_role;

alter default privileges for role postgres in schema platform
    grant select on tables to authenticated;

alter default privileges for role postgres in schema platform
    grant all on tables to service_role;

-- =====================================================
-- 7. FORCE ROW LEVEL SECURITY (public + platform)
-- =====================================================

do $$
declare
    v_row record;
begin
    for v_row in
        select n.nspname as schema_name, c.relname as table_name
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where c.relkind = 'r'
          and c.relrowsecurity
          and n.nspname in ('public', 'platform')
        order by n.nspname, c.relname
    loop
        execute format(
            'alter table %I.%I force row level security',
            v_row.schema_name,
            v_row.table_name
        );
    end loop;
end $$;

-- =====================================================
-- END 014 PLATFORM BOOTSTRAP FINALE
-- =====================================================
