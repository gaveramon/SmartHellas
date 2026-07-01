-- =====================================================
-- REV18.1.1 PRODUCTION MASTER
-- DEEL 5 - OPERATIONS ENGINE
-- =====================================================

-- =====================================================
-- ENUMS
-- =====================================================

create type ticket_status as enum (
  'open',
  'in_progress',
  'waiting_customer',
  'resolved',
  'closed'
);

create type notification_status as enum (
  'pending',
  'sent',
  'delivered',
  'failed'
);

create type notification_channel as enum (
  'email',
  'sms',
  'push',
  'system'
);

create type onboarding_step_status as enum (
  'pending',
  'active',
  'completed',
  'skipped'
);

-- =====================================================
-- SUPPORT TICKETS
-- =====================================================

create table support_tickets (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references auth.users(id),

  subject text not null,
  description text,

  status ticket_status not null default 'open',
  priority int not null default 3,

  assigned_to uuid references auth.users(id),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  deleted_at timestamptz,
  deleted_by uuid
);

create index idx_tickets_org on support_tickets(organization_id);
create index idx_tickets_status on support_tickets(status);

create trigger trg_tickets_updated_at
before update on support_tickets
for each row execute function set_updated_at();

-- =====================================================
-- TICKET MESSAGES
-- =====================================================

create table ticket_messages (
  id uuid primary key default gen_random_uuid(),

  ticket_id uuid not null references support_tickets(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  sender_user_id uuid references auth.users(id),
  message text not null,

  is_internal boolean not null default false,

  created_at timestamptz not null default now()
);

create index idx_ticket_messages_ticket on ticket_messages(ticket_id);

-- =====================================================
-- NOTIFICATIONS ENGINE
-- =====================================================

create table notifications (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  user_id uuid references auth.users(id),

  channel notification_channel not null,

  type text not null, -- welcome, checkin, checkout, alarm, support

  title text,
  message text not null,

  status notification_status not null default 'pending',

  scheduled_at timestamptz,
  sent_at timestamptz,

  error_message text,

  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index idx_notifications_org on notifications(organization_id);
create index idx_notifications_status on notifications(status);

-- =====================================================
-- ONBOARDING FLOW (APP-SMITH READY)
-- =====================================================

create table onboarding_flows (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  current_step text,
  completed boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_onboarding_org on onboarding_flows(organization_id);

create trigger trg_onboarding_updated_at
before update on onboarding_flows
for each row execute function set_updated_at();

-- =====================================================
-- ONBOARDING STEPS
-- =====================================================

create table onboarding_steps (
  id uuid primary key default gen_random_uuid(),

  onboarding_flow_id uuid not null references onboarding_flows(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  step_key text not null,
  status onboarding_step_status not null default 'pending',

  data jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),

  unique (onboarding_flow_id, step_key)
);

create index idx_onboarding_steps_flow on onboarding_steps(onboarding_flow_id);

-- =====================================================
-- SLA TRACKING
-- =====================================================

create table sla_metrics (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  metric_type text not null, -- uptime, response_time, sync_success_rate

  value numeric not null,

  recorded_at timestamptz not null default now()
);

create index idx_sla_org on sla_metrics(organization_id);

-- =====================================================
-- SYSTEM DIAGNOSTICS
-- =====================================================

create table system_diagnostics (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references organizations(id) on delete cascade,

  component text not null, -- integration, device, automation, billing

  status text not null, -- ok, warning, critical

  message text,

  metadata jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index idx_diagnostics_org on system_diagnostics(organization_id);

-- =====================================================
-- BILLING RECONCILIATION
-- =====================================================

create table billing_reconciliation (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid not null references organizations(id) on delete cascade,

  stripe_subscription_id text,

  expected_amount numeric,
  actual_amount numeric,

  currency text default 'EUR',

  status text not null, -- matched, mismatch, pending

  period_start timestamptz,
  period_end timestamptz,

  created_at timestamptz not null default now()
);

create index idx_billing_org on billing_reconciliation(organization_id);

-- =====================================================
-- ADMIN ACTION LOGS (SUPER ADMIN TOOLING)
-- =====================================================

create table admin_actions (
  id uuid primary key default gen_random_uuid(),

  admin_user_id uuid references auth.users(id),

  organization_id uuid references organizations(id) on delete cascade,

  action text not null,

  target_table text,
  target_id uuid,

  payload jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

create index idx_admin_actions_org on admin_actions(organization_id);

-- =====================================================
-- FEATURE FLAGS AUDIT HISTORY
-- =====================================================

create table feature_flag_history (
  id uuid primary key default gen_random_uuid(),

  feature_flag_id uuid not null references feature_flags(id) on delete cascade,

  organization_id uuid not null references organizations(id) on delete cascade,

  key text not null,
  old_value boolean,
  new_value boolean,

  changed_by uuid references auth.users(id),

  created_at timestamptz not null default now()
);

create index idx_feature_flag_history_org on feature_flag_history(organization_id);

-- =====================================================
-- NOTIFICATION DELIVERY LOG
-- =====================================================

create table notification_delivery_logs (
  id uuid primary key default gen_random_uuid(),

  notification_id uuid not null references notifications(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,

  channel notification_channel not null,

  status notification_status not null,

  provider_response jsonb,

  error_message text,

  delivered_at timestamptz,

  created_at timestamptz not null default now()
);

create index idx_notification_logs_org on notification_delivery_logs(organization_id);

-- =====================================================
-- RLS ENABLEMENT
-- =====================================================

alter table support_tickets enable row level security;
alter table ticket_messages enable row level security;
alter table notifications enable row level security;
alter table onboarding_flows enable row level security;
alter table onboarding_steps enable row level security;
alter table sla_metrics enable row level security;
alter table system_diagnostics enable row level security;
alter table billing_reconciliation enable row level security;
alter table admin_actions enable row level security;
alter table feature_flag_history enable row level security;
alter table notification_delivery_logs enable row level security;

-- =====================================================
-- RLS: SUPPORT TICKETS
-- =====================================================

create policy "tickets_org"
on support_tickets
for all
using (
  deleted_at is null
  and exists (
    select 1 from memberships m
    where m.organization_id = support_tickets.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: TICKET MESSAGES
-- =====================================================

create policy "ticket_messages_org"
on ticket_messages
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = ticket_messages.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: NOTIFICATIONS
-- =====================================================

create policy "notifications_org"
on notifications
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = notifications.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: ONBOARDING
-- =====================================================

create policy "onboarding_org"
on onboarding_flows
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = onboarding_flows.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: ONBOARDING STEPS
-- =====================================================

create policy "onboarding_steps_org"
on onboarding_steps
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = onboarding_steps.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- RLS: SLA + DIAGNOSTICS + BILLING
-- =====================================================

create policy "sla_org"
on sla_metrics
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = sla_metrics.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "diagnostics_org"
on system_diagnostics
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = system_diagnostics.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "billing_org"
on billing_reconciliation
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = billing_reconciliation.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

-- =====================================================
-- ADMIN ONLY TABLES
-- =====================================================

create policy "admin_actions_service_only"
on admin_actions
for all
using (false);

create policy "feature_flag_history_org"
on feature_flag_history
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = feature_flag_history.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);

create policy "notification_logs_org"
on notification_delivery_logs
for all
using (
  exists (
    select 1 from memberships m
    where m.organization_id = notification_delivery_logs.organization_id
    and m.user_id = auth.uid()
    and m.deleted_at is null
  )
);