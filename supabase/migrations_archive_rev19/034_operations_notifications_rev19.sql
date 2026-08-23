-- =====================================================
-- 034 OPERATIONS NOTIFICATIONS (006 SSOT)
-- Queue-driven notification domain. Delivery via 000 platform workers.
-- Automation (016) enqueues only — never delivers.
-- =====================================================

insert into platform.schema_migrations (migration_name, version, rollback_available)
values ('034_operations_notifications_rev19', 'REV19.DOMAIN.OPERATIONS.NOTIFICATIONS', false)
on conflict (version) do nothing;

-- =====================================================
-- 1. TYPES
-- =====================================================

do $$
begin
    if not exists (select 1 from pg_type where typname = 'notification_channel') then
        create type public.notification_channel as enum (
            'email',
            'sms',
            'push',
            'portal'
        );
    end if;

    if not exists (select 1 from pg_type where typname = 'notification_delivery_status') then
        create type public.notification_delivery_status as enum (
            'queued',
            'processing',
            'sent',
            'failed',
            'cancelled'
        );
    end if;
end $$;

-- =====================================================
-- 2. TABLES (006 Operations SSOT)
-- =====================================================

create table if not exists public.notification_templates (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid references public.tenants(id) on delete cascade,
    code text not null,
    channel public.notification_channel not null,
    subject_template text,
    body_template text not null,
    metadata jsonb not null default '{}'::jsonb,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint chk_notification_templates_scope check (
        (tenant_id is null) or (tenant_id is not null)
    ),
    unique (tenant_id, code, channel)
);

create index if not exists idx_notification_templates_tenant_created
on public.notification_templates (tenant_id, created_at desc);

create index if not exists idx_notification_templates_code
on public.notification_templates (code, channel);

create trigger trg_notification_templates_updated_at
before update on public.notification_templates
for each row execute function platform.set_updated_at();

create table if not exists public.notification_preferences (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    user_id uuid references platform.profiles(id) on delete cascade,
    channel public.notification_channel not null,
    is_enabled boolean not null default true,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (tenant_id, user_id, channel)
);

create unique index if not exists uq_notification_preferences_tenant_default_channel
on public.notification_preferences (tenant_id, channel)
where user_id is null;

create index if not exists idx_notification_preferences_tenant_created
on public.notification_preferences (tenant_id, created_at desc);

create trigger trg_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function platform.set_updated_at();

create table if not exists public.notification_queue (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    channel public.notification_channel not null,
    recipient text not null,
    template_id uuid references public.notification_templates(id) on delete set null,
    template_code text,
    subject text,
    body text,
    payload jsonb not null default '{}'::jsonb,
    status public.notification_delivery_status not null default 'queued',
    scheduled_at timestamptz not null default now(),
    attempt_count int not null default 0,
    max_attempts int not null default 5,
    last_error jsonb,
    correlation_id uuid not null default gen_random_uuid(),
    source text not null default 'api',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint chk_notification_queue_attempts check (
        attempt_count >= 0 and max_attempts > 0 and attempt_count <= max_attempts + 1
    )
);

create index if not exists idx_notification_queue_pending
on public.notification_queue (status, scheduled_at)
where status in ('queued', 'processing');

create index if not exists idx_notification_queue_tenant_created
on public.notification_queue (tenant_id, created_at desc);

create trigger trg_notification_queue_updated_at
before update on public.notification_queue
for each row execute function platform.set_updated_at();

create table if not exists public.notification_history (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants(id) on delete cascade,
    queue_id uuid references public.notification_queue(id) on delete set null,
    channel public.notification_channel not null,
    recipient text not null,
    status public.notification_delivery_status not null,
    subject text,
    body text,
    payload jsonb not null default '{}'::jsonb,
    error jsonb,
    sent_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

create index if not exists idx_notification_history_tenant_sent
on public.notification_history (tenant_id, sent_at desc);

create index if not exists idx_notification_history_queue
on public.notification_history (queue_id);

-- =====================================================
-- 3. RLS
-- =====================================================

alter table public.notification_templates enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_queue enable row level security;
alter table public.notification_history enable row level security;

drop policy if exists notification_templates_select on public.notification_templates;
create policy notification_templates_select on public.notification_templates
    for select to authenticated
    using (
        platform.is_platform_admin()
        or tenant_id is null
        or public.has_tenant_access(tenant_id)
    );

drop policy if exists notification_templates_insert on public.notification_templates;
create policy notification_templates_insert on public.notification_templates
    for insert to authenticated
    with check (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

drop policy if exists notification_templates_update on public.notification_templates;
create policy notification_templates_update on public.notification_templates
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

drop policy if exists notification_templates_delete on public.notification_templates;
create policy notification_templates_delete on public.notification_templates
    for delete to authenticated
    using (
        platform.is_platform_admin()
        or (
            public.has_tenant_access(tenant_id)
            and (platform.is_admin() or platform.has_role('manager'))
        )
    );

select public._apply_public_tenant_rls('public.notification_preferences'::regclass);
select public._apply_public_tenant_rls('public.notification_queue'::regclass);
select public._apply_public_tenant_rls('public.notification_history'::regclass);

-- =====================================================
-- 4. INTERNAL HELPERS
-- =====================================================

create or replace function public.notification_resolve_template(
    p_tenant_id uuid,
    p_template_code text,
    p_channel public.notification_channel
)
returns public.notification_templates
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_row public.notification_templates;
begin
    select * into v_row
    from public.notification_templates nt
    where nt.code = p_template_code
      and nt.channel = p_channel
      and nt.is_active = true
      and (nt.tenant_id = p_tenant_id or nt.tenant_id is null)
    order by nt.tenant_id nulls last
    limit 1;

    return v_row;
end;
$$;

create or replace function public.notification_is_channel_enabled(
    p_tenant_id uuid,
    p_user_id uuid,
    p_channel public.notification_channel
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_pref boolean;
begin
    select np.is_enabled into v_pref
    from public.notification_preferences np
    where np.tenant_id = p_tenant_id
      and np.channel = p_channel
      and (np.user_id = p_user_id or np.user_id is null)
    order by np.user_id nulls last
    limit 1;

    return coalesce(v_pref, true);
end;
$$;

-- =====================================================
-- 5. NOTIFICATION DOMAIN (006 SSOT)
-- =====================================================

create or replace function public.notification_domain(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tid uuid;
    v_uid uuid;
    v_row record;
    v_template public.notification_templates;
    v_result jsonb;
    v_subject text;
    v_body text;
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    v_tid := platform.current_tenant_id();
    v_uid := auth.uid();

    case p_op
    when 'list_templates' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.code), '[]'::jsonb) into v_result
        from (
            select nt.id, nt.tenant_id, nt.code, nt.channel, nt.subject_template,
                   nt.body_template, nt.metadata, nt.is_active, nt.created_at, nt.updated_at
            from public.notification_templates nt
            where nt.tenant_id is null or nt.tenant_id = v_tid
        ) t;

    when 'get_template' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select to_jsonb(t) into v_result from (
            select nt.id, nt.tenant_id, nt.code, nt.channel, nt.subject_template,
                   nt.body_template, nt.metadata, nt.is_active, nt.created_at, nt.updated_at
            from public.notification_templates nt
            where nt.id = (p_payload->>'id')::uuid
              and (nt.tenant_id is null or nt.tenant_id = v_tid)
        ) t;
        if v_result is null then raise exception 'Notification template not found'; end if;

    when 'create_template' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        insert into public.notification_templates (
            tenant_id, code, channel, subject_template, body_template, metadata, is_active
        )
        values (
            v_tid,
            p_payload->>'code',
            (p_payload->>'channel')::public.notification_channel,
            p_payload->>'subject_template',
            p_payload->>'body_template',
            coalesce(p_payload->'metadata', '{}'::jsonb),
            coalesce((p_payload->>'is_active')::boolean, true)
        )
        returning id, tenant_id, code, channel, subject_template, body_template,
                  metadata, is_active, created_at, updated_at into v_row;
        perform platform.log_audit('notification_template.created', 'notification_template', v_row.id);
        v_result := to_jsonb(v_row);

    when 'update_template' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        update public.notification_templates nt set
            subject_template = case when p_payload ? 'subject_template' then p_payload->>'subject_template' else nt.subject_template end,
            body_template = case when p_payload ? 'body_template' then p_payload->>'body_template' else nt.body_template end,
            metadata = case when p_payload ? 'metadata' then p_payload->'metadata' else nt.metadata end,
            is_active = case when p_payload ? 'is_active' then (p_payload->>'is_active')::boolean else nt.is_active end
        where nt.id = (p_payload->>'id')::uuid and nt.tenant_id = v_tid
        returning nt.id, nt.tenant_id, nt.code, nt.channel, nt.subject_template, nt.body_template,
                  nt.metadata, nt.is_active, nt.created_at, nt.updated_at into v_row;
        if not found then raise exception 'Notification template not found'; end if;
        perform platform.log_audit('notification_template.updated', 'notification_template', v_row.id);
        v_result := to_jsonb(v_row);

    when 'delete_template' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        delete from public.notification_templates nt
        where nt.id = (p_payload->>'id')::uuid and nt.tenant_id = v_tid;
        if not found then raise exception 'Notification template not found'; end if;
        perform platform.log_audit('notification_template.deleted', 'notification_template', (p_payload->>'id')::uuid);
        v_result := jsonb_build_object('deleted', true, 'id', p_payload->>'id');

    when 'list_preferences' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.channel), '[]'::jsonb) into v_result
        from (
            select np.id, np.tenant_id, np.user_id, np.channel, np.is_enabled, np.metadata,
                   np.created_at, np.updated_at
            from public.notification_preferences np
            where np.tenant_id = v_tid
              and (p_payload->>'user_id' is null or np.user_id = (p_payload->>'user_id')::uuid)
        ) t;

    when 'upsert_preference' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        insert into public.notification_preferences (tenant_id, user_id, channel, is_enabled, metadata)
        values (
            v_tid,
            case when p_payload ? 'user_id' then (p_payload->>'user_id')::uuid else null end,
            (p_payload->>'channel')::public.notification_channel,
            coalesce((p_payload->>'is_enabled')::boolean, true),
            coalesce(p_payload->'metadata', '{}'::jsonb)
        )
        on conflict (tenant_id, user_id, channel) do update set
            is_enabled = excluded.is_enabled,
            metadata = excluded.metadata,
            updated_at = now()
        returning id, tenant_id, user_id, channel, is_enabled, metadata, created_at, updated_at into v_row;
        perform platform.log_audit('notification_preference.upserted', 'notification_preference', v_row.id);
        v_result := to_jsonb(v_row);

    when 'enqueue_notification' then
        if v_tid is null then raise exception 'no active tenant'; end if;

        if not public.notification_is_channel_enabled(
            v_tid,
            case when p_payload ? 'user_id' then (p_payload->>'user_id')::uuid else v_uid end,
            (p_payload->>'channel')::public.notification_channel
        ) then
            return jsonb_build_object('skipped', true, 'reason', 'channel_disabled');
        end if;

        v_subject := p_payload->>'subject';
        v_body := p_payload->>'body';

        if p_payload ? 'template_code' then
            v_template := public.notification_resolve_template(
                v_tid,
                p_payload->>'template_code',
                (p_payload->>'channel')::public.notification_channel
            );
            if v_template.id is not null then
                v_subject := coalesce(v_subject, v_template.subject_template);
                v_body := coalesce(v_body, v_template.body_template);
            end if;
        end if;

        if v_body is null then
            raise exception 'notification body or template_code is required';
        end if;

        insert into public.notification_queue (
            tenant_id, channel, recipient, template_id, template_code,
            subject, body, payload, status, scheduled_at, source, correlation_id
        )
        values (
            v_tid,
            (p_payload->>'channel')::public.notification_channel,
            p_payload->>'recipient',
            v_template.id,
            p_payload->>'template_code',
            v_subject,
            v_body,
            coalesce(p_payload->'payload', '{}'::jsonb),
            'queued'::public.notification_delivery_status,
            coalesce((p_payload->>'scheduled_at')::timestamptz, now()),
            coalesce(p_payload->>'source', 'api'),
            coalesce((p_payload->>'correlation_id')::uuid, gen_random_uuid())
        )
        returning id, tenant_id, channel, recipient, template_id, template_code, subject, body,
                  payload, status, scheduled_at, attempt_count, max_attempts, correlation_id,
                  source, created_at, updated_at into v_row;

        perform platform.log_audit('notification.enqueued', 'notification_queue', v_row.id);
        v_result := to_jsonb(v_row);

    when 'list_queue' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) into v_result
        from (
            select nq.id, nq.tenant_id, nq.channel, nq.recipient, nq.template_code, nq.status,
                   nq.scheduled_at, nq.attempt_count, nq.max_attempts, nq.correlation_id,
                   nq.source, nq.created_at, nq.updated_at
            from public.notification_queue nq
            where nq.tenant_id = v_tid
              and (p_payload->>'status' is null or nq.status::text = p_payload->>'status')
        ) t;

    when 'get_notification' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select to_jsonb(t) into v_result from (
            select nh.id, nh.tenant_id, nh.queue_id, nh.channel, nh.recipient, nh.status,
                   nh.subject, nh.body, nh.payload, nh.error, nh.sent_at, nh.created_at
            from public.notification_history nh
            where nh.id = (p_payload->>'id')::uuid and nh.tenant_id = v_tid
        ) t;
        if v_result is null then raise exception 'Notification not found'; end if;

    when 'list_history' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        select coalesce(jsonb_agg(to_jsonb(t) order by t.sent_at desc), '[]'::jsonb) into v_result
        from (
            select nh.id, nh.tenant_id, nh.queue_id, nh.channel, nh.recipient, nh.status,
                   nh.subject, nh.payload, nh.sent_at, nh.created_at
            from public.notification_history nh
            where nh.tenant_id = v_tid
              and (p_payload->>'channel' is null or nh.channel::text = p_payload->>'channel')
        ) t;

    when 'cancel_notification' then
        if v_tid is null then raise exception 'no active tenant'; end if;
        update public.notification_queue nq set
            status = 'cancelled'::public.notification_delivery_status,
            updated_at = now()
        where nq.id = (p_payload->>'id')::uuid
          and nq.tenant_id = v_tid
          and nq.status = 'queued'::public.notification_delivery_status
        returning nq.id into v_row;
        if not found then raise exception 'Queued notification not found'; end if;
        perform platform.log_audit('notification.cancelled', 'notification_queue', v_row.id);
        v_result := jsonb_build_object('cancelled', true, 'id', v_row.id);

    else
        raise exception 'unknown notification_domain operation: %', p_op;
    end case;

    return v_result;
end;
$$;

revoke all on function public.notification_domain(text, jsonb) from public;
grant execute on function public.notification_domain(text, jsonb) to authenticated, service_role;

-- =====================================================
-- 6. NOTIFICATION API (017 Edge wrapper)
-- =====================================================

create or replace function public.notification_api(
    p_op text,
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);

    case p_op
        when 'list_templates', 'get_template', 'list_preferences', 'list_queue',
             'get_notification', 'list_history' then
            perform public.edge_require_tenant();
        when 'create_template', 'update_template', 'delete_template', 'upsert_preference',
             'enqueue_notification', 'cancel_notification' then
            perform public.edge_require_manager();
        else
            raise exception 'unknown notification_api operation: %', p_op;
    end case;

    return public.notification_domain(p_op, p_payload);
end;
$$;

revoke all on function public.notification_api(text, jsonb) from public;
grant execute on function public.notification_api(text, jsonb) to authenticated, service_role;

-- =====================================================
-- 7. AUTOMATION ENQUEUE ONLY (016 → 006)
-- =====================================================

create or replace function public.automation_enqueue_notification(
    p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
    p_payload := coalesce(p_payload, '{}'::jsonb);
    p_payload := p_payload || jsonb_build_object('source', 'automation');
    return public.notification_domain('enqueue_notification', p_payload);
end;
$$;

revoke all on function public.automation_enqueue_notification(jsonb) from public;
grant execute on function public.automation_enqueue_notification(jsonb) to authenticated, service_role;

-- =====================================================
-- 8. PLATFORM DELIVERY WORKERS (000)
-- =====================================================

create or replace function platform.fetch_notification_batch(p_limit int default 50)
returns setof public.notification_queue
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    with picked as (
        select nq.id
        from public.notification_queue nq
        where nq.status = 'queued'::public.notification_delivery_status
          and nq.scheduled_at <= now()
        order by nq.scheduled_at
        for update skip locked
        limit greatest(p_limit, 1)
    )
    update public.notification_queue nq set
        status = 'processing'::public.notification_delivery_status,
        attempt_count = nq.attempt_count + 1,
        updated_at = now()
    from picked
    where nq.id = picked.id
    returning nq.*;
end;
$$;

create or replace function platform.complete_notification_delivery(
    p_queue_id uuid,
    p_success boolean,
    p_error jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_row public.notification_queue;
    v_status public.notification_delivery_status;
begin
    select * into v_row
    from public.notification_queue nq
    where nq.id = p_queue_id
    for update;

    if not found then
        raise exception 'notification queue item % not found', p_queue_id;
    end if;

    if p_success then
        v_status := 'sent'::public.notification_delivery_status;
        update public.notification_queue set
            status = v_status,
            last_error = null,
            updated_at = now()
        where id = p_queue_id;

        insert into public.notification_history (
            tenant_id, queue_id, channel, recipient, status, subject, body, payload, error
        )
        values (
            v_row.tenant_id, v_row.id, v_row.channel, v_row.recipient, v_status,
            v_row.subject, v_row.body, v_row.payload, null
        );
    else
        if v_row.attempt_count >= v_row.max_attempts then
            v_status := 'failed'::public.notification_delivery_status;
            update public.notification_queue set
                status = v_status,
                last_error = coalesce(p_error, '{}'::jsonb),
                updated_at = now()
            where id = p_queue_id;

            insert into public.notification_history (
                tenant_id, queue_id, channel, recipient, status, subject, body, payload, error
            )
            values (
                v_row.tenant_id, v_row.id, v_row.channel, v_row.recipient, v_status,
                v_row.subject, v_row.body, v_row.payload, coalesce(p_error, '{}'::jsonb)
            );
        else
            update public.notification_queue set
                status = 'queued'::public.notification_delivery_status,
                last_error = coalesce(p_error, '{}'::jsonb),
                scheduled_at = now() + (interval '1 minute' * v_row.attempt_count),
                updated_at = now()
            where id = p_queue_id;
        end if;
    end if;
end;
$$;

revoke all on function platform.fetch_notification_batch(int) from public, authenticated;
grant execute on function platform.fetch_notification_batch(int) to service_role;

revoke all on function platform.complete_notification_delivery(uuid, boolean, jsonb) from public, authenticated;
grant execute on function platform.complete_notification_delivery(uuid, boolean, jsonb) to service_role;

-- =====================================================
-- END 034 OPERATIONS NOTIFICATIONS
-- =====================================================
