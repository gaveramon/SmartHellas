# Portal Edge Function (010 Service & Portal Engine)

Tenant portal UI configuration, dashboard layouts, per-user preferences, and UI-only feature flags.

**UI layer only** — no domain truth, logs, events, or support cases. Plan entitlements live in **009** (`commerce/my-entitlements`). Support tickets live in **006** (`operations`).

Deploy name: `portal`

Base URL: `{SUPABASE_URL}/functions/v1/portal/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT (`auth/switch-tenant`).

## Bootstrap (`bootstrap`)

Single call for Appsmith/Flutter portal load.

| Route | Method | Description |
|-------|--------|-------------|
| `bootstrap` | GET | Settings + default dashboard + feature flags |

## Tenant portal settings (`tenant_portal_settings`)

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `settings` | GET | tenant member | Read portal settings |
| `settings` | PUT/PATCH | manager+ | Upsert theme / language |

```json
PUT /functions/v1/portal/settings
{
  "theme": { "primary": "#0066cc", "mode": "dark" },
  "default_language": "en"
}
```

## Dashboard configs (`dashboard_configs`)

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `dashboards` | GET | tenant member | List layouts |
| `dashboards` | POST | manager+ | Create layout |
| `dashboard` | GET | tenant member | Get (`?id=`) |
| `dashboard` | PATCH | manager+ | Update (supports `is_default`) |
| `dashboard` | DELETE | manager+ | Delete (`id` in body) |

Only one `is_default` per tenant — Edge clears other defaults when setting a new default.

## User preferences (`portal_user_preferences`)

Per-user UI state. RLS restricts to `auth.uid()`.

| Route | Method | Description |
|-------|--------|-------------|
| `preferences` | GET | List current user's preferences |
| `preferences` | PUT/POST | Upsert preference |
| `preference` | GET | Single (`?preference_key=`) |
| `preference` | PATCH | Update value |
| `preference` | DELETE | Delete (`preference_key` in body) |

## Portal feature flags (`portal_feature_flags`)

UI visibility only — keys **must** start with `ui_`. Not plan entitlements.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `feature-flags` | GET | tenant member | List flags |
| `feature-flags` | POST | manager+ | Create flag |
| `feature-flag` | PATCH/DELETE | manager+ | Update/delete |

```json
POST /functions/v1/portal/feature-flags
{ "feature_key": "ui_beta_dashboard", "enabled": true }
```

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Plan / commercial entitlements** | 009 `commerce/my-entitlements` |
| **Support tickets / messages** | 006 `operations` |
| **Tenant identity / memberships** | `auth/` (002) |
| **Audit / event / operation logs** | 000 platform |
| **Service activation state** | 013 `service_activation_state` |

## Module layout

```
portal/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
