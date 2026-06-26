-- =====================================================
-- REV18.3 FINAL v4 PRODUCTION
-- 009_COMMERCE_ENGINE.sql
-- SaaS-grade Commerce Engine (WP + Stripe + VivaWallet)
-- =====================================================


-- =====================================================
-- 1. PRODUCT CATEGORIES
-- =====================================================

create table product_categories (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  name text not null,
  ui_type text not null default 'bubble',
  icon text,
  description text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger trg_product_categories_updated_at
before update on product_categories
for each row execute function set_updated_at();


-- =====================================================
-- 2. PRODUCTS
-- =====================================================

create table products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references product_categories(id),

  sku text unique,
  name text not null,
  description text,

  product_type text not null,
  is_active boolean default true,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- =====================================================
-- 3. PRODUCT PRICES (MASTER)
-- =====================================================

create table product_prices (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id),

  currency text default 'EUR',
  price numeric not null,

  valid_from timestamptz default now(),
  valid_to timestamptz,

  created_at timestamptz default now()
);


-- =====================================================
-- 4. PRODUCT DEPENDENCIES
-- =====================================================

create table product_dependencies (
  id uuid primary key default gen_random_uuid(),

  product_id uuid not null references products(id),
  depends_on_product_id uuid not null references products(id),

  dependency_type text not null,
  -- requires | recommends | conflicts

  min_quantity int default 1,
  is_hard_constraint boolean default true,

  created_at timestamptz default now()
);


-- =====================================================
-- 5. TAX RULES (GREECE MVP + EXTENSIBLE)
-- =====================================================

create table tax_rules (
  id uuid primary key default gen_random_uuid(),

  country text default 'GR',
  tax_name text default 'VAT Greece',
  tax_rate numeric default 0.24,

  applies_to text not null,
  -- product | service | subscription | all

  created_at timestamptz default now()
);


-- =====================================================
-- 6. PRICING SNAPSHOT ENGINE (NEW FIX #3)
-- =====================================================

create table pricing_snapshots (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid,
  order_id uuid,

  product_id uuid not null,

  unit_price numeric not null,
  quantity int not null,

  source text not null,
  -- base_price | rule_engine | manual_override

  captured_at timestamptz default now()
);


-- =====================================================
-- 7. CONFIGURATOR SESSION (ORG + PROPERTY FIX #1)
-- =====================================================

create table configurator_sessions (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid,
  property_id uuid,

  step text default 'init',
  metadata jsonb default '{}'::jsonb,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- =====================================================
-- 8. CART (STATE MACHINE FIXED)
-- =====================================================

create table configurator_cart (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid,
  property_id uuid,
  session_id uuid references configurator_sessions(id),

  status text default 'active',
  -- active | locked | converted | abandoned

  currency text default 'EUR',

  subtotal numeric default 0,
  tax_total numeric default 0,
  total numeric default 0,

  price_locked boolean default false,
  locked_at timestamptz,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- =====================================================
-- 9. CART ITEMS (STATE TRACKING FIX #4)
-- =====================================================

create table configurator_cart_items (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid references configurator_cart(id),
  product_id uuid references products(id),

  quantity int default 1,
  unit_price numeric,
  total_price numeric,

  source text default 'user',
  -- user | recommendation | rule_engine

  is_locked boolean default false,
  override_flag boolean default false,
  updated_by_rule_engine boolean default false,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- =====================================================
-- 10. SUBSCRIPTION OPTIONS
-- =====================================================

create table cart_subscription_options (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid references configurator_cart(id),

  plan text not null,
  price_monthly numeric,

  is_selected boolean default false,

  created_at timestamptz default now()
);


-- =====================================================
-- 11. ORDERS (WITH TAX SNAPSHOT FIX #2)
-- =====================================================

create table orders (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid,

  organization_id uuid,
  property_id uuid,

  status text default 'pending',
  -- pending | awaiting_payment | paid | failed | cancelled | refunded

  payment_provider text,
  external_order_id text,
  payment_intent_id text,

  subtotal numeric,
  tax_total numeric,
  total numeric,

  currency text default 'EUR',

  tax_snapshot jsonb,   -- FIX: volledige tax context opgeslagen

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- =====================================================
-- 12. ORDER ITEMS
-- =====================================================

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id),

  product_id uuid,
  quantity int,
  unit_price numeric,
  total_price numeric,

  created_at timestamptz default now()
);


-- =====================================================
-- 13. DISCOUNT ENGINE (FIXED STRUCTURE #5)
-- =====================================================

create table discount_rules (
  id uuid primary key default gen_random_uuid(),

  name text,

  rule_type text not null,
  -- cart | product | subscription

  condition jsonb not null,
  -- structured rule definition

  discount_type text not null,
  -- percentage | fixed

  value numeric not null,

  priority int default 1,

  is_active boolean default true,

  created_at timestamptz default now()
);