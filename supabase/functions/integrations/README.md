# Integrations Edge Function (005 Integration Engine)

Provider catalog, tenant connections, outbound webhook subscriptions, and device↔provider ID mapping.

**Business rules live in SQL** (RLS, `enforce_device_integration_consistency`, `platform.push_integration_event`). Edge Functions orchestrate JWT + RLS writes, Vault secret storage, OAuth redirects, and queue enqueue.

Deploy name: `integrations`

Base URL: `{SUPABASE_URL}/functions/v1/integrations/{route}`

## Authentication

Most routes:

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT (`auth/switch-tenant`). Mutations require `manager`, `admin`, or `owner`.

`oauth-callback` is unauthenticated (provider redirect); state token binds tenant + provider.

## Provider catalog (global read)

| Route | Method | Description |
|-------|--------|-------------|
| `providers` | GET | List active integration providers |
| `provider` | GET | Provider detail (`?code=stripe`) |
| `capabilities` | GET | List capabilities (`?provider_code=` optional) |

Catalog writes are platform-admin only in SQL — not exposed here.

## Tenant connections (`tenant_integrations`)

| Route | Method | Description |
|-------|--------|-------------|
| `connections` | GET | List tenant integrations |
| `connection` | GET | Single connection (`?code=stripe`) |
| `connection` | PATCH | Update config / credentials_ref / is_enabled |
| `connect` | POST | Connect or upsert integration |
| `disconnect` | POST | Remove tenant integration |

Secrets never go in `config`. Use `credentials_ref` (Vault name) or OAuth flow.

### Connect example

```json
POST /functions/v1/integrations/connect
{
  "provider_code": "beds24",
  "credentials_ref": "integrations/<tenant_id>/beds24",
  "config": { "property_id": "12345" },
  "is_enabled": true
}
```

## Outbound webhook definitions (`webhook_definitions`)

Tenant-defined outbound targets. Inbound provider ingest is `webhooks/` + `platform.ingest_external_webhook` (000).

| Route | Method | Description |
|-------|--------|-------------|
| `webhook-definitions` | GET | List (`?provider_code=` optional) |
| `webhook-definitions` | POST | Create subscription |
| `webhook-definition` | PATCH | Update |
| `webhook-definition` | DELETE | Delete (`id` in body) |

## Device integration map (`device_integration_map`)

| Route | Method | Description |
|-------|--------|-------------|
| `device-maps` | GET | List (`?device_id=` / `?provider_code=` optional) |
| `device-maps` | POST | Map device to provider external ID |
| `device-map` | PATCH | Update external_id / config |
| `device-map` | DELETE | Remove map (`id` in body) |

`tenant_id` is set by SQL trigger from `devices.tenant_id`. `external_id` is required.

## OAuth

| Route | Method | Description |
|-------|--------|-------------|
| `oauth-start` | POST | Returns provider authorize URL + state |
| `oauth-callback` | GET | Provider redirect; exchanges code, stores Vault secret, upserts connection |

### OAuth start example

```json
POST /functions/v1/integrations/oauth-start
{
  "provider_code": "stripe",
  "redirect_uri": "https://app.example.com/oauth/callback"
}
```

Stripe uses `STRIPE_CONNECT_CLIENT_ID` + `STRIPE_SECRET_KEY`. Other providers use env:

- `OAUTH_AUTHORIZE_URL_<PROVIDER>`
- `OAUTH_TOKEN_URL_<PROVIDER>`

Vault secret name: `integrations/{tenant_id}/{provider_code}`.

## Sync (queue)

| Route | Method | Description |
|-------|--------|-------------|
| `sync` | POST | Enqueue `sync_state` via `platform.push_integration_event` |

```json
POST /functions/v1/integrations/sync
{
  "provider_code": "beds24",
  "scope": { "property_id": "12345" }
}
```

Workers in `jobs/integration-queue` execute external API calls.

## Environment variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `SUPABASE_URL` | yes | API base |
| `SUPABASE_ANON_KEY` | yes | User client |
| `SUPABASE_SERVICE_ROLE_KEY` | yes | OAuth callback upsert |
| `SUPABASE_DB_URL` | yes | Platform RPC + Vault |
| `STRIPE_SECRET_KEY` | Stripe OAuth | Token exchange |
| `STRIPE_CONNECT_CLIENT_ID` | Stripe OAuth | Authorize URL |
| `OAUTH_AUTHORIZE_URL_*` | Other OAuth | Authorize base URL |
| `OAUTH_TOKEN_URL_*` | Other OAuth | Token endpoint |

## Not applicable in this function

- **Inbound provider webhooks** → `webhooks/` function
- **Integration queue workers** → `jobs/integration-queue`
- **Provider catalog seed / admin writes** → migrations (`016_Provider_seed_data_rev19.sql`) + platform admin SQL
- **Runtime integration state** → platform queues / events (000)

## Module layout

```
integrations/
  index.ts      # HTTP router
  types.ts      # Request/response shapes
  validation.ts # Input parsing
  service.ts    # RLS orchestration
  README.md
```
