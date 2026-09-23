-- ============================================================
-- SUPABASE FUNCTIONAL HEALTHCHECK SUPPORT
-- ============================================================

begin;

create schema if not exists healthcheck;

-- ------------------------------------------------------------
-- REST/PostgREST test
-- ------------------------------------------------------------

create or replace function healthcheck.ping()
returns jsonb
language sql
security invoker
set search_path = healthcheck, public
as $$
    select jsonb_build_object(
        'status', 'ok',
        'timestamp', now()
    );
$$;

revoke all on function healthcheck.ping() from public;
grant execute on function healthcheck.ping() to authenticated;


-- ------------------------------------------------------------
-- Realtime test table
-- ------------------------------------------------------------

create table if not exists healthcheck.realtime_test (
    id uuid primary key default gen_random_uuid(),
    test_id uuid not null,
    created_at timestamptz not null default now()
);

alter table healthcheck.realtime_test enable row level security;

revoke all on healthcheck.realtime_test from anon;
revoke all on healthcheck.realtime_test from authenticated;

grant insert on healthcheck.realtime_test to authenticated;
grant select on healthcheck.realtime_test to authenticated;

drop policy if exists healthcheck_realtime_insert
    on healthcheck.realtime_test;

create policy healthcheck_realtime_insert
on healthcheck.realtime_test
for insert
to authenticated
with check (true);

drop policy if exists healthcheck_realtime_select
    on healthcheck.realtime_test;

create policy healthcheck_realtime_select
on healthcheck.realtime_test
for select
to authenticated
using (true);


-- ------------------------------------------------------------
-- Realtime publication
-- ------------------------------------------------------------

do $$
begin
    if not exists (
        select 1
        from pg_publication
        where pubname = 'supabase_realtime'
    ) then
        create publication supabase_realtime;
    end if;
end
$$;

alter publication supabase_realtime
add table healthcheck.realtime_test;


-- ------------------------------------------------------------
-- Storage bucket
-- ------------------------------------------------------------

insert into storage.buckets (
    id,
    name,
    public
)
values (
    'healthcheck',
    'healthcheck',
    false
)
on conflict (id) do nothing;


-- ------------------------------------------------------------
-- Storage policies
-- ------------------------------------------------------------

drop policy if exists healthcheck_storage_insert
on storage.objects;

create policy healthcheck_storage_insert
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'healthcheck'
);

drop policy if exists healthcheck_storage_select
on storage.objects;

create policy healthcheck_storage_select
on storage.objects
for select
to authenticated
using (
    bucket_id = 'healthcheck'
);

drop policy if exists healthcheck_storage_delete
on storage.objects;

create policy healthcheck_storage_delete
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'healthcheck'
);


commit;