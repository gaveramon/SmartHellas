=====================================================

-- REV18.3 PRODUCTION
-- 013 CUSTOMER PROPOSAL & MONETIZATION LAYER
-- APPROVALS + UPSELL + SUBSCRIPTIONS + CHECKOUT + FRONTEND BINDING
-- =====================================================

=====================================================
1. CUSTOMER PROPOSAL CORE
=====================================================

create table customer_proposals (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

source text not null,
-- configurator | ai | manual | onboarding | upsell

title text not null,
description text,

proposal_type text not null,
-- energy_saving_package | security_package | full_service | custom

status text not null default 'draft',
-- draft | presented | accepted | rejected | expired

total_price numeric default 0.0,
currency text default 'EUR',

valid_until timestamptz,

metadata jsonb not null default '{}'::jsonb,

created_at timestamptz default now(),
updated_at timestamptz default now(),
deleted_at timestamptz

);

create index idx_customer_proposals_property on customer_proposals(property_id);
create index idx_customer_proposals_status on customer_proposals(status);

=====================================================
2. PROPOSAL LINE ITEMS (PRODUCT CONFIG ENGINE)
=====================================================

create table customer_proposal_items (
id uuid primary key default gen_random_uuid(),

proposal_id uuid not null references customer_proposals(id) on delete cascade,

product_type text not null,
-- aqara_device | ttlock | shelly | service | subscription

product_code text,
name text not null,

quantity int not null default 1,
unit_price numeric default 0.0,

is_optional boolean default false,
is_selected boolean default true,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);

create index idx_proposal_items_proposal on customer_proposal_items(proposal_id);

=====================================================
3. APPROVAL ENGINE (USER DECISION FLOW)
=====================================================

create table customer_proposal_approvals (
id uuid primary key default gen_random_uuid(),

proposal_id uuid not null references customer_proposals(id) on delete cascade,
user_id uuid references auth.users(id),

decision text not null,
-- approved | rejected | modified

comment text,

created_at timestamptz default now()

);

create index idx_proposal_approvals_proposal on customer_proposal_approvals(proposal_id);

=====================================================
4. SUBSCRIPTION UPSELL ENGINE
=====================================================

create table subscription_offers (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

trigger_source text not null,
-- proposal_accepted | onboarding_step | ai_insight | checkout

name text not null,

plan_type text not null,
-- startup_service | managed_service | premium_service

monthly_price numeric not null,

setup_fee numeric default 0.0,

features jsonb default '{}'::jsonb,

priority int default 1,

is_active boolean default true,

created_at timestamptz default now()

);

create index idx_subscription_offers_property on subscription_offers(property_id);

=====================================================
5. CUSTOMER SUBSCRIPTIONS (SYSTEM OF RECORD)
=====================================================

create table customer_subscriptions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

offer_id uuid references subscription_offers(id),

status text not null default 'trialing',
-- trialing | active | past_due | cancelled | expired

provider text not null,
-- stripe | vivawallet

external_subscription_id text,

current_price numeric default 0.0,
currency text default 'EUR',

started_at timestamptz default now(),
ends_at timestamptz,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now(),
updated_at timestamptz default now()

);

create index idx_customer_subscriptions_property on customer_subscriptions(property_id);
create index idx_customer_subscriptions_status on customer_subscriptions(status);

=====================================================
6. PAYMENT TRANSACTIONS (STRIPE / VIVAWALLET)
=====================================================

create table payment_transactions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

provider text not null,
-- stripe | vivawallet

external_payment_id text,

amount numeric not null,
currency text default 'EUR',

status text not null default 'pending',
-- pending | paid | failed | refunded

source text,
-- checkout | subscription | upsell | invoice

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);

create index idx_payment_transactions_property on payment_transactions(property_id);
create index idx_payment_transactions_status on payment_transactions(status);

=====================================================
7. CHECKOUT SESSION (FLUENT FORMS / WP BINDING)
=====================================================

create table checkout_sessions (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

session_source text not null,
-- fluent_forms | wordpress | api

proposal_id uuid references customer_proposals(id),

status text default 'active',
-- active | completed | abandoned

cart_snapshot jsonb default '{}'::jsonb,

total_amount numeric default 0.0,

currency text default 'EUR',

created_at timestamptz default now(),
updated_at timestamptz default now()

);

create index idx_checkout_sessions_property on checkout_sessions(property_id);

=====================================================
8. CONVERSION EVENTS (ENERGY SAVING PACKAGE ENGINE)
=====================================================

create table conversion_events (
id uuid primary key default gen_random_uuid(),

organization_id uuid not null references organizations(id) on delete cascade,
property_id uuid,

event_type text not null,
-- view_proposal | add_item | remove_item | checkout_start | checkout_complete | upsell_clicked

source text not null,
-- wp | fluent_forms | portal | ai

proposal_id uuid,

metadata jsonb default '{}'::jsonb,

created_at timestamptz default now()

);

create index idx_conversion_events_property on conversion_events(property_id);
create index idx_conversion_events_type on conversion_events(event_type);

=====================================================
9. ROW LEVEL SECURITY
=====================================================

alter table customer_proposals enable row level security;
alter table customer_proposal_items enable row level security;
alter table customer_proposal_approvals enable row level security;
alter table subscription_offers enable row level security;
alter table customer_subscriptions enable row level security;
alter table payment_transactions enable row level security;
alter table checkout_sessions enable row level security;
alter table conversion_events enable row level security;

PROPOSALS POLICY

create policy customer_proposals_access on customer_proposals
for all
using (deleted_at is null and is_org_member(organization_id))
with check (is_org_member(organization_id));

ITEMS POLICY

create policy customer_proposal_items_access on customer_proposal_items
for all
using (true)
with check (true);

APPROVALS POLICY

create policy customer_proposal_approvals_access on customer_proposal_approvals
for all
using (is_org_member((select organization_id from customer_proposals p where p.id = proposal_id)))
with check (is_org_member((select organization_id from customer_proposals p where p.id = proposal_id)));

SUBSCRIPTIONS POLICY

create policy customer_subscriptions_access on customer_subscriptions
for all
using (is_org_member(organization_id))
with check (is_org_member(organization_id));

PAYMENTS POLICY

create policy payment_transactions_access on payment_transactions
for all
using (is_org_member(organization_id))
with check (is_org_member(organization_id));

CHECKOUT POLICY

create policy checkout_sessions_access on checkout_sessions
for all
using (is_org_member(organization_id))
with check (is_org_member(organization_id));

CONVERSION POLICY

create policy conversion_events_access on conversion_events
for all
using (is_org_member(organization_id))
with check (is_org_member(organization_id));