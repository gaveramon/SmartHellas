# Monetization Edge Function (013 Growth Engine)

Customer proposals, monetization packages, package upsell campaigns, conversion analytics reads, and service activation projection reads.

**Commercial intent and conversion data only — no payment execution, fulfilment dispatch, or worker side effects.** Checkout uses **000** `platform.payment_intents`; hardware dispatch uses **008** `fulfilment_orders`; plan upsells use **009** `upsell_rules`.

Deploy name: `monetization`

Base URL: `{SUPABASE_URL}/functions/v1/monetization/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Tenant-scoped routes require `app_metadata.tenant_id` (call `auth/switch-tenant` first). RLS is the enforcement layer; Edge adds role checks for manager+ writes.

## Customer proposals (`customer_proposals`)

Commercial proposal intent. Payment checkout targets `platform.payment_intents` with `target_type=proposal`.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `proposals` | GET | tenant member | List (`?status=`, `?property_id=`) |
| `proposals` | POST | manager+ | Create draft proposal |
| `proposal` | GET | tenant member | Proposal + items (`?id=`) |
| `proposal` | PATCH | manager+ | Update fields / status |
| `proposal` | DELETE | manager+ | Delete proposal |

`status`: `draft`, `presented`, `accepted`, `rejected`, `expired`

PATCH to `presented` sets `presented_at`; PATCH to `accepted` sets `accepted_at`. Workers in **000** may create payment/fulfilment intents after acceptance.

## Proposal items (`proposal_items`)

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `proposal-items` | GET | tenant member | List (`?proposal_id=`) |
| `proposal-items` | POST | manager+ | Add line item |
| `proposal-item` | PATCH/DELETE | manager+ | Update/delete item |

`item_type`: `device_package`, `subscription`, `service`

- `subscription` requires `plan_id` (009 `product_plans`)
- `device_package` requires `monetization_package_id`
- `service` requires `reference_id`

## Monetization packages (`monetization_packages`)

Commercial wrapper over **007** `device_bundles`. Global catalog.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `packages` | GET | any authenticated | List (`?active_only=true`) |
| `packages` | POST | platform admin | Create package |
| `package` | GET | any authenticated | Get by id (`?id=`) |
| `package` | PATCH/DELETE | platform admin | Update/delete |

`package_type`: `hardware`, `service`, `hybrid`

## Package upsell campaigns (`upsell_campaigns`)

In-product package upsells — distinct from **009** plan `upsell_rules` and **015** CRM campaigns.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `upsell-campaigns` | GET | tenant member | List (`?trigger_event=`, `?active_only=`) |
| `upsell-campaigns` | POST | manager+ or platform admin | Create campaign |
| `upsell-campaign` | GET | tenant member | Get by id (`?id=`) |
| `upsell-campaign` | PATCH/DELETE | manager+ or platform admin | Update/delete |

Platform admins may create global blueprints (`tenant_id` null). Tenant managers create campaigns scoped to their tenant.

`trigger_event`: `onboarding_completed`, `device_added`, `booking_created`, `usage_threshold`, `manual_review`

## Service activation projection (`service_activation_state`)

Worker-maintained read model. SSOT: **002** subscriptions + **009** entitlements.

| Route | Method | Description |
|-------|--------|-------------|
| `activation-state` | GET | List projection (`?property_id=`, `?service_type=`) |

**No tenant writes.** Updates via `platform.sync_service_activation_state()` (service_role / jobs).

## Conversion funnel (`conversion_events`)

Append-only funnel events. **Tenant JWT: read only** (RLS blocks tenant insert).

| Route | Method | Description |
|-------|--------|-------------|
| `conversion-events` | GET | List (`?proposal_id=`, `?event_type=`, `?limit=`) |

Portal funnel tracking inserts require **platform admin** or **jobs** workers — not exposed here.

## Conversion scores (`conversion_scores`)

Analytical scores. **Tenant JWT: read only.**

| Route | Method | Description |
|-------|--------|-------------|
| `conversion-scores` | GET | List (`?property_id=`, `?limit=`) |

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Payment processing / Stripe checkout** | 000 `platform.payment_intents` + `webhooks/` |
| **Fulfilment dispatch** | 008 `logistics/dispatch` |
| **Subscription plan upsell rules** | 009 `commerce/upsell-rules` |
| **CRM marketing campaigns** | 015 CRM |
| **Conversion event inserts (tenant portal)** | jobs workers or platform admin (RLS) |
| **Service activation writes** | 000 `sync_service_activation_state` via service_role |
| **Optimization → proposal conversion** | 012 `optimization` (sets `customer_proposal_id`) |
| **Enums** | 001 Core Types |

## Module layout

```
monetization/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
