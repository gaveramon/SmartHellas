# Locks Edge Function (004 Lock Engine)

Lock device mapping, credential grant metadata, and command enqueue for provider workers.

**No plaintext codes in Edge.** `credential_ref` is a vault secret name. Provider APIs run in `jobs/device-commands`.

Deploy name: `locks`

## Routes

| Route | Methods | Table / action |
|-------|---------|----------------|
| `lock-devices` | GET, POST | `lock_devices` |
| `lock-device` | GET, PATCH, DELETE | `lock_devices` |
| `credentials` | GET (`?booking_id=`) | `access_credentials` (read) |
| `credential` | GET (`?id=`) | `access_credentials` |
| `credential-issue` | POST | Insert credential + enqueue command |
| `credential-revoke` | POST | Revoke + enqueue command |

## Credential issue flow

1. Validate manager+ role
2. Insert `access_credentials` (`status=pending`) via **service role** (RLS: platform admin only for authenticated insert)
3. Enqueue `platform.device_commands` (`issue_credential`) via Postgres
4. Worker (`jobs/device-commands`) calls TTLock/Aqara — **no PIN math in TypeScript**

```json
POST /functions/v1/locks/credential-issue
{
  "booking_id": "uuid",
  "lock_device_id": "uuid",
  "booking_access_id": "uuid",
  "credential_ref": "vault/tenant/booking-lock-ref",
  "idempotency_key": "optional-key"
}
```

## Permissions

| Operation | Role |
|-----------|------|
| Read locks/credentials | Tenant member |
| Link locks, issue/revoke credentials | `manager`, `admin`, or `owner` |

## SQL triggers

- `enforce_lock_device_integrity` (lock category + `device_integration_map` required)
- `enforce_access_credential_consistency` (sets `provider_code`, aligns windows)

## Dependencies

| Object | Module |
|--------|--------|
| `devices`, `device_categories` | 003 |
| `device_integration_map` | 005 |
| `platform.device_commands` | 000 |
| `bookings`, `booking_access` | 004 `booking/` |

## RPC

- Direct insert: `platform.device_commands` (orchestration)
- No public business RPCs

## Not applicable

| Capability | Owner |
|------------|--------|
| TTLock/Aqara API calls | `jobs/device-commands` |
| Vault secret storage | Supabase Vault + workers |
| Guest window composition | Future SQL RPC in 004 |

## Environment

`SUPABASE_SERVICE_ROLE_KEY` required for credential writes. `SUPABASE_DB_URL` for command enqueue.
