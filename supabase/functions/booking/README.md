# Booking Edge Function (004 Booking Engine)

Reservations, guest access windows, property schedules, and non-guest access policies.

**Business rules live in SQL.** Edge Functions validate inputs and perform RLS-guarded writes. Door code generation and provider execution are **not** here — see `locks/` and `jobs/`.

Deploy name: `booking`

## Routes

| Route | Methods | Table(s) |
|-------|---------|----------|
| `bookings` | GET, POST | `bookings` |
| `booking` | GET (`?id=`), PATCH, DELETE | `bookings` |
| `access-schedule` | GET (`?property_id=`), PUT/POST | `property_access_schedules` |
| `booking-access` | GET (`?booking_id=`), POST, DELETE | `booking_access` |
| `access-policies` | GET, POST | `access_policies` |
| `access-policy` | PATCH, DELETE | `access_policies` |
| `access-rules` | GET, POST | `access_rules` |
| `access-rule` | PATCH, DELETE | `access_rules` |

## Access model (SQL SSOT)

1. `property_access_schedules` — default check-in/out template
2. `booking_access` — resolved guest window per booking (`valid_from` / `valid_until` required on POST)
3. `access_policies` — non-guest grants
4. `access_rules` — property exceptions (`override`, `emergency_access`)

**Note:** Window composition from dates + schedule should move to a SQL RPC. Until then, `booking-access` POST requires explicit `valid_from` and `valid_until` (no date math in Edge).

## Permissions (RLS)

| Operation | Role |
|-----------|------|
| Read bookings/access | Tenant member |
| Mutate bookings/schedules/policies | `manager`, `admin`, or `owner` |

## SQL triggers

- `enforce_booking_tenant_consistency`
- `enforce_booking_access_consistency`
- `enforce_property_tenant_consistency`

## RPC

None — RLS table access only.

## Not in this function

| Capability | Owner |
|------------|--------|
| `lock_devices`, `access_credentials` | `locks/` |
| `platform.device_commands` | `jobs/device-commands` |
| PIN / code generation | 000 workers + Vault |

## Authentication

`Authorization: Bearer <jwt>` + active tenant via `auth/switch-tenant`.
