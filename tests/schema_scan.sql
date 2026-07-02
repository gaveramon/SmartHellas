-- =====================================================
-- SmartHellas schema introspection (public + platform)
-- Idempotent: safe to re-run; refreshes tests.schema_inventory
-- =====================================================

create schema if not exists tests;

create table if not exists tests.schema_inventory (
    scan_id uuid not null default gen_random_uuid(),
    scanned_at timestamptz not null default now(),
    category text not null,
    object_schema text,
    object_name text,
    detail jsonb not null default '{}'::jsonb,
    primary key (scan_id, category, object_schema, object_name)
);

create or replace function tests.assert(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
    if not coalesce(p_condition, false) then
        raise exception 'ASSERT FAILED: %', p_message;
    end if;
end;
$$;

create or replace function tests.assert_eq(p_expected text, p_actual text, p_message text)
returns void
language plpgsql
as $$
begin
    if p_expected is distinct from p_actual then
        raise exception 'ASSERT FAILED: % (expected=%, actual=%)', p_message, p_expected, p_actual;
    end if;
end;
$$;

create or replace function tests.run_schema_scan()
returns table (
    category text,
    object_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_scan_id uuid := gen_random_uuid();
begin
    delete from tests.schema_inventory;

    -- tables
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'table',
        n.nspname,
        c.relname,
        jsonb_build_object(
            'kind', c.relkind,
            'rls_enabled', c.relrowsecurity,
            'rls_forced', c.relforcerowsecurity
        )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'r'
      and n.nspname in ('public', 'platform')
      and c.relname not like '%\_20%' escape '\';

    -- columns (defaults, not null, generated)
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'column',
        c.table_schema,
        c.table_name || '.' || c.column_name,
        jsonb_build_object(
            'data_type', c.data_type,
            'udt_name', c.udt_name,
            'is_nullable', c.is_nullable,
            'column_default', c.column_default,
            'is_generated', c.is_generated,
            'generation_expression', c.generation_expression
        )
    from information_schema.columns c
    where c.table_schema in ('public', 'platform')
      and c.table_name not like '%\_20%' escape '\';

    -- enums (001 SSOT)
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'enum',
        n.nspname,
        t.typname,
        jsonb_build_object(
            'labels', coalesce(
                (
                    select jsonb_agg(e.enumlabel order by e.enumsortorder)
                    from pg_enum e
                    where e.enumtypid = t.oid
                ),
                '[]'::jsonb
            )
        )
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typtype = 'e'
      and n.nspname in ('public', 'platform');

    -- foreign keys
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'foreign_key',
        tc.table_schema,
        tc.table_name || '.' || tc.constraint_name,
        jsonb_build_object(
            'column', kcu.column_name,
            'references_schema', ccu.table_schema,
            'references_table', ccu.table_name,
            'references_column', ccu.column_name,
            'delete_rule', rc.delete_rule,
            'update_rule', rc.update_rule
        )
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name
     and tc.table_schema = kcu.table_schema
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name = tc.constraint_name
     and ccu.table_schema = tc.table_schema
    join information_schema.referential_constraints rc
      on rc.constraint_name = tc.constraint_name
     and rc.constraint_schema = tc.table_schema
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema in ('public', 'platform');

    -- indexes
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'index',
        n.nspname,
        c.relname,
        jsonb_build_object(
            'table', tn.relname,
            'definition', pg_get_indexdef(ix.indexrelid),
            'is_unique', ix.indisunique,
            'is_primary', ix.indisprimary
        )
    from pg_index ix
    join pg_class i on i.oid = ix.indexrelid
    join pg_class c on c.oid = ix.indexrelid
    join pg_class tn on tn.oid = ix.indrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'platform')
      and tn.relname not like '%\_20%' escape '\';

    -- unique + check constraints
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        case tc.constraint_type
            when 'UNIQUE' then 'unique_constraint'
            when 'CHECK' then 'check_constraint'
            else lower(tc.constraint_type)
        end,
        tc.table_schema,
        tc.table_name || '.' || tc.constraint_name,
        jsonb_build_object(
            'definition', pg_get_constraintdef(con.oid),
            'constraint_type', tc.constraint_type
        )
    from information_schema.table_constraints tc
    join pg_constraint con
      on con.conname = tc.constraint_name
    join pg_namespace n on n.oid = con.connamespace and n.nspname = tc.table_schema
    where tc.constraint_type in ('UNIQUE', 'CHECK')
      and tc.table_schema in ('public', 'platform');

    -- rls policies
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'rls_policy',
        p.schemaname,
        p.tablename || '.' || p.policyname,
        jsonb_build_object(
            'command', p.cmd,
            'roles', p.roles,
            'permissive', p.permissive,
            'using', p.qual,
            'with_check', p.with_check
        )
    from pg_policies p
    where p.schemaname in ('public', 'platform');

    -- triggers
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'trigger',
        n.nspname,
        c.relname || '.' || t.tgname,
        jsonb_build_object(
            'function', p.proname,
            'function_schema', pn.nspname,
            'timing', case
                when t.tgtype & 2 = 2 then 'before'
                when t.tgtype & 64 = 64 then 'instead of'
                else 'after'
            end,
            'events', trim(both ' ' from concat_ws(
                ' ',
                case when t.tgtype & 4 = 4 then 'insert' end,
                case when t.tgtype & 8 = 8 then 'delete' end,
                case when t.tgtype & 16 = 16 then 'update' end,
                case when t.tgtype & 32 = 32 then 'truncate' end
            )),
            'enabled', t.tgenabled <> 'D'
        )
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace pn on pn.oid = p.pronamespace
    where not t.tgisinternal
      and n.nspname in ('public', 'platform');

    -- trigger / business functions with RAISE paths
    insert into tests.schema_inventory (scan_id, category, object_schema, object_name, detail)
    select
        v_scan_id,
        'function',
        n.nspname,
        p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
        jsonb_build_object(
            'oid', p.oid,
            'kind', case p.prokind when 'f' then 'function' when 'p' then 'procedure' else p.prokind::text end,
            'returns', pg_get_function_result(p.oid),
            'language', l.lanname,
            'security_definer', p.prosecdef,
            'raises_exception', position('raise exception' in lower(pg_get_functiondef(p.oid))) > 0
        )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname in ('public', 'platform', 'tests')
      and p.prokind in ('f', 'p');

    return query
    select si.category, count(*)::bigint
    from tests.schema_inventory si
    where si.scan_id = v_scan_id
    group by si.category
    order by si.category;
end;
$$;

-- module SSOT ownership map (static contract — validated by integration_tests)
create table if not exists tests.module_ownership (
    module_code text primary key,
    owns text[] not null
);

insert into tests.module_ownership (module_code, owns)
values
    ('000', array['platform', 'execution', 'audit', 'queues', 'webhooks', 'logging']),
    ('001', array['enum', 'shared type']),
    ('002', array['tenants', 'tenant_memberships', 'subscriptions', 'service_accounts']),
    ('003', array['properties', 'rooms', 'devices', 'device_categories']),
    ('004', array['bookings', 'access', 'lock_devices', 'credentials']),
    ('005', array['integration_providers', 'tenant_integrations', 'webhook_definitions']),
    ('006', array['operation_templates', 'workflows', 'support_tickets']),
    ('007', array['device_bundles', 'onboarding_blueprints', 'preconfig_templates']),
    ('008', array['logistics_templates', 'fulfilment_orders', 'shipping']),
    ('009', array['product_plans', 'feature_entitlements', 'upsell_rules']),
    ('010', array['tenant_portal_settings', 'dashboard_configs', 'portal']),
    ('011', array['onboarding_sessions', 'onboarding_step_state']),
    ('012', array['optimization_rules', 'insight_events', 'recommendations']),
    ('013', array['customer_proposals', 'monetization_packages', 'service_activation_state']),
    ('014', array['bootstrap', 'platform binds', 'cron wiring']),
    ('015', array['crm_pipelines', 'crm_contacts', 'crm_leads', 'crm_opportunities'])
on conflict (module_code) do update set owns = excluded.owns;
