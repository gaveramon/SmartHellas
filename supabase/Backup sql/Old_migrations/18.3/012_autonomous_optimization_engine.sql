=====================================================

-- REV18.3 PRODUCTION
-- 012 OPTIMIZATION ENGINE (FINAL HARDENED)
-- AI INSIGHT → PROPOSAL → APPROVAL LAYER
-- =====================================================

=====================================================
1. OPTIMIZATION INSIGHTS
=====================================================

create table optimization_insights (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

domain text not null,
-- energy | security | operations | revenue | maintenance

insight_type text not null,
-- anomaly | opportunity | recommendation | alert

title text not null,
description text,

severity int default 1,
confidence numeric default 0.0,

dedup_key text not null,
cooldown_minutes int default 60,

status text not null default 'active',
-- active | suppressed | expired

expires_at timestamptz,

metadata jsonb not null default '{}'::jsonb,

created_at timestamptz not null default now(),
updated_at timestamptz not null default now(),
deleted_at timestamptz,

unique (organization_id, dedup_key)

);

create index idx_optimization_insights_property on optimization_insights(property_id);
create index idx_optimization_insights_status on optimization_insights(status);
create index idx_optimization_insights_domain on optimization_insights(domain);

create trigger trg_optimization_insights_updated_at
before update on optimization_insights
for each row execute function set_updated_at();

=====================================================
2. OPTIMIZATION PROPOSALS
=====================================================

create table optimization_proposals (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,
insight_id uuid references optimization_insights(id) on delete set null,

title text not null,
description text,
domain text not null,

status text not null default 'proposed',
-- new | proposed | approved | rejected | executed | expired

proposal_version int not null default 1,
previous_proposal_id uuid references optimization_proposals(id),

impact_score numeric default 0.0,
estimated_savings numeric default 0.0,

priority int default 1,

metadata jsonb not null default '{}'::jsonb,

created_at timestamptz not null default now(),
updated_at timestamptz not null default now(),
deleted_at timestamptz,

unique (id, organization_id)

);

create index idx_optimization_proposals_property on optimization_proposals(property_id);
create index idx_optimization_proposals_insight on optimization_proposals(insight_id);
create index idx_optimization_proposals_status on optimization_proposals(status);

create trigger trg_optimization_proposals_updated_at
before update on optimization_proposals
for each row execute function set_updated_at();

=====================================================
3. PROPOSAL ACTIONS
=====================================================

create table optimization_proposal_actions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

proposal_id uuid not null references optimization_proposals(id) on delete cascade,
operation_action_id uuid references operation_actions(id) on delete set null,

action_type text not null,
parameters jsonb not null default '{}'::jsonb,

status text not null default 'pending',
-- pending | approved | executed | failed

created_at timestamptz not null default now(),
updated_at timestamptz not null default now(),
deleted_at timestamptz

);

create index idx_proposal_actions_proposal on optimization_proposal_actions(proposal_id);

=====================================================
4. AI RUN LOGS (FULL TRACEABILITY)
=====================================================

create table optimization_ai_runs (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

insight_id uuid references optimization_insights(id) on delete set null,
proposal_id uuid references optimization_proposals(id) on delete set null,

trigger_type text not null,
-- scheduled | insight_trigger | manual | system_event

model_name text,
model_version text,
prompt_version text,

input jsonb,
output jsonb,

token_usage int default 0,
cost_estimate numeric default 0.0,

status text not null default 'completed',
-- running | completed | failed

correlation_id uuid default gen_random_uuid(),

created_at timestamptz not null default now(),
deleted_at timestamptz

);

create index idx_ai_runs_property on optimization_ai_runs(property_id);
create index idx_ai_runs_correlation on optimization_ai_runs(correlation_id);
create index idx_ai_runs_trigger on optimization_ai_runs(trigger_type);

=====================================================
5. PROPOSAL DECISIONS (SECURE)
=====================================================

create table optimization_proposal_decisions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

proposal_id uuid not null references optimization_proposals(id) on delete cascade,
user_id uuid references auth.users(id),

decision text not null,
-- approved | rejected | postponed

reason text,

created_at timestamptz default now(),
deleted_at timestamptz

);

create index idx_proposal_decisions_proposal on optimization_proposal_decisions(proposal_id);

=====================================================
6. RATE LIMITING / COOLDOWN CONTROL
=====================================================

create table optimization_rate_limits (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

domain text not null,

cooldown_minutes int default 60,
last_triggered_at timestamptz,

created_at timestamptz default now(),

unique (organization_id, property_id, domain)

);

create index idx_rate_limits_property on optimization_rate_limits(property_id);

=====================================================
7. ROW LEVEL SECURITY
=====================================================

alter table optimization_insights enable row level security;
alter table optimization_proposals enable row level security;
alter table optimization_proposal_actions enable row level security;
alter table optimization_ai_runs enable row level security;
alter table optimization_proposal_decisions enable row level security;
alter table optimization_rate_limits enable row level security;

INSIGHTS POLICY

create policy optimization_insights_access on optimization_insights
for all
using (deleted_at is null and is_org_member(organization_id))
with check (is_org_member(organization_id));

PROPOSALS POLICY

create policy optimization_proposals_access on optimization_proposals
for all
using (deleted_at is null and is_org_member(organization_id))
with check (is_org_member(organization_id));

ACTIONS POLICY

create policy optimization_actions_access on optimization_proposal_actions
for all
using (deleted_at is null and is_org_member(organization_id))
with check (is_org_member(organization_id));

AI RUNS POLICY

create policy optimization_ai_runs_access on optimization_ai_runs
for select
using (deleted_at is null and is_org_member(organization_id));

DECISIONS POLICY (FIXED SECURITY)

create policy optimization_decisions_access on optimization_proposal_decisions
for all
using (
deleted_at is null
and is_org_member(organization_id)
and exists (
select 1
from optimization_proposals p
where p.id = proposal_id
and p.organization_id = optimization_proposal_decisions.organization_id
)
)
with check (
is_org_member(organization_id)
);

RATE LIMITS POLICY

create policy optimization_rate_limits_access on optimization_rate_limits
for all
using (deleted_at is null and is_org_member(organization_id))
with check (is_org_member(organization_id));