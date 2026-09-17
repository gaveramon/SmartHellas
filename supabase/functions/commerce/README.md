# Commerce Edge Function (009 Commerce Engine)

Product plans, static pricing, feature entitlements, and plan upsell rule definitions.

**Commercial catalog only — no payment execution, webhooks, or transactions.** Package upsells and proposals live in **013**; subscription lifecycle fields (status, period) remain in **`auth/subscription`**.

Deploy name: `commerce`

Base URL: `{SUPABASE_URL}/functions/v1/commerce/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Catalog reads require authentication only. Plan/pricing/entitlement catalog writes require **platform admin**. Tenant upsell rules require `manager`, `admin`, or `owner`. Plan changes require **admin or owner**.

## Product plans (`product_plans`)

Platform commercial offering catalog. `tier` is SSOT; `subscriptions.tier` is derived via SQL trigger when `plan_id` is set.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `plans` | GET | any | List active plans |
| `plans` | POST | platform admin | Create plan |
| `plan` | GET | any | Plan + pricing + entitlements (`?id=`) |
| `plan` | PATCH/DELETE | platform admin | Update/delete plan |

`tier`: `basic`, `pro`, `enterprise`

## Plan pricing (`plan_pricing`)

Static pricing — not live billing.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `plan-pricing` | GET | any | List (`?plan_id=`) |
| `plan-pricing` | POST | platform admin | Add currency row |
| `plan-pricing-entry` | PATCH/DELETE | platform admin | Update/delete |

## Feature entitlements (`feature_entitlements`)

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `entitlements` | GET | any | List for plan (`?plan_id=`) |
| `entitlements` | POST | platform admin | Add entitlement |
| `entitlement` | PATCH/DELETE | platform admin | Update/delete |

## Tenant entitlements (resolved)

| Route | Method | Description |
|-------|--------|-------------|
| `my-entitlements` | GET | Enabled features for tenant's active `subscriptions.plan_id` |

## Plan upsell rules (`upsell_rules`)

Subscription/plan upgrade definitions — no automatic execution.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `upsell-rules` | GET | tenant member | List tenant + platform rules (`?trigger_event=`) |
| `upsell-rules` | POST | manager+ | Create tenant rule |
| `upsell-rule` | PATCH/DELETE | manager+ | Update/delete tenant rule |

`trigger_event`: `onboarding_completed`, `device_added`, `booking_created`, `usage_threshold`, `manual_review`

## Change subscription plan (`subscriptions.plan_id`)

Updates **002** subscription via `plan_id` — tier syncs from SQL, do not PATCH `tier` directly.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `change-plan` | POST | admin/owner | Set tenant subscription `plan_id` |

```json
POST /functions/v1/commerce/change-plan
{ "plan_id": "uuid" }
```

For subscription **status** and billing period, use `auth/subscription` PATCH.

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Payment processing / Stripe charges** | 000 platform + `webhooks/` |
| **Invoices / payment transactions** | 000 platform |
| **Customer proposals / package upsells** | 013 Growth Engine |
| **CRM marketing campaigns** | 015 CRM |
| **Subscription status / period dates** | `auth/subscription` (002 SSOT) |
| **Service activation projection** | 013 `service_activation_state` |
| **Enums** | 001 Core Types |

## Module layout

```
commerce/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
