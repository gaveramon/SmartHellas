# Optimization Edge Function (012 Intelligence Engine)

Advisory intelligence layer — scoring rules, insights, recommendations, device usage scores, and energy profiles.

**Advisory only — no execution.** Workers (`jobs/`) insert insights/recommendations via `service_role`. Applying changes requires explicit approval and runs through **000** `operation_contexts`.

Deploy name: `optimization`

Base URL: `{SUPABASE_URL}/functions/v1/optimization/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT. Rule and recommendation mutations require `manager`, `admin`, or `owner`.

## Optimization rules (`optimization_rules`)

Tenant-scoped scoring/threshold definitions — defines what to evaluate, not actions.

| Route | Method | Description |
|-------|--------|-------------|
| `rules` | GET | List tenant rules |
| `rules` | POST | Create rule |
| `rule` | GET/PATCH/DELETE | Rule CRUD |

`category`: `energy`, `security`, `cost`, `efficiency`, `performance`, `user_experience`

## Insight events (`insight_events`)

**Read-only** for tenant JWT (inserts are `service_role` only).

| Route | Method | Description |
|-------|--------|-------------|
| `insights` | GET | List (`?property_id=` / `?insight_type=`) |
| `insight` | GET | Detail (`?id=`) |

## Recommendations (`optimization_recommendations`)

Advisory outputs — `suggested_changes` are non-executable hints.

| Route | Method | Description |
|-------|--------|-------------|
| `recommendations` | GET | List (`?status=` / `?property_id=`) |
| `recommendation` | GET | Detail |
| `recommendation` | PATCH | Update `status` (acknowledge/dismiss) |
| `recommendation` | DELETE | Remove (`id` in body) |

`status`: `open`, `acknowledged`, `dismissed`, `converted_to_proposal`, `implemented`

Tenant cannot create recommendations — workers insert via `service_role`.

```json
PATCH /functions/v1/optimization/recommendation
{ "id": "uuid", "status": "acknowledged" }
```

## Device usage scores (`device_usage_scores`)

Analytics snapshots — **read-only** for tenants (writes platform admin / workers).

| Route | Method | Description |
|-------|--------|-------------|
| `usage-scores` | GET | List (`?device_id=` optional) |

## Energy profiles (`energy_profiles`)

Property energy baselines — **read-only** for tenants.

| Route | Method | Description |
|-------|--------|-------------|
| `energy-profiles` | GET | List (`?property_id=` optional) |
| `energy-profile` | GET | Detail (`?id=`) |

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Insight/recommendation generation (AI workers)** | `jobs/` with `service_role` |
| **Executing `suggested_changes` / device commands** | 000 after explicit approval |
| **Operational workflow definitions** | 006 `operations/` |
| **Customer proposals from recommendations** | 013 monetization |
| **Enums** | 001 Core Types |

## Module layout

```
optimization/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
