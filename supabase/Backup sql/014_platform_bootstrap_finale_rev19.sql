-- =====================================================
-- 014 PLATFORM BOOTSTRAP FINALE
-- Generic tenant RLS for uncovered tables + pg_cron wiring
-- Runs after full domain stack (002–013)
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('014_platform_bootstrap_finale', 'REV19.PLATFORM.BOOTSTRAP', false)
on conflict (version) do nothing;

-- Apply generic tenant RLS only where no policy exists yet (preserves custom domain RLS)
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
    loop
        perform public._apply_public_tenant_rls(
            format('public.%I', v_row.table_name)::regclass
        );
    end loop;
end $$;

-- =====================================================
-- pg_cron JOB WIRING
-- =====================================================

do $cron$
declare
    v_job record;
begin
    if not exists (select 1 from pg_extension where extname = 'pg_cron') then
        raise notice 'pg_cron not available; skipping job registration';
        return;
    end if;

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
        $$select platform.run_platform_cron_tick();$$
    );

    perform cron.schedule(
        'platform-daily-maintenance',
        '15 2 * * *',
        $$select platform.run_platform_daily_maintenance();$$
    );
end $cron$;

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
            '{"description":"Partition ensure + log retention purge"}'::jsonb
        )
) as v(job_name, cron_expression, handler, is_active, metadata)
where not exists (
    select 1
    from platform.scheduled_jobs sj
    where sj.job_name = v.job_name
);

-- =====================================================
-- END 014 PLATFORM BOOTSTRAP FINALE
-- =====================================================
