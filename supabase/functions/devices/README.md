# Devices Edge Function (003 Property & Device Engine)

Property, room, device registry, assignments, and static configuration orchestration.

**Business rules live in SQL** (`enforce_device_hierarchy`, `enforce_device_assignment_tenant_consistency`, RLS). Edge Functions validate input enums and perform RLS-guarded writes.

Deploy name: `devices`

Base URL: `{SUPABASE_URL}/functions/v1/devices/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT (`auth/switch-tenant`). All tenant-scoped rows use `tenant_id` from JWT context via RLS.

## Properties (`properties`)

| Route | Method | Description |
|-------|--------|-------------|
| `properties` | GET | List tenant properties |
| `properties` | POST | Create property |
| `property` | GET | Get property (`?id=uuid`) |
| `property` | PATCH | Update property (`id` in body) |
| `property` | DELETE | Delete property (`id` in body) |

## Rooms (`rooms`)

| Route | Method | Description |
|-------|--------|-------------|
| `rooms` | GET | List rooms (`?property_id=` optional) |
| `rooms` | POST | Create room |
| `room` | GET | Get room (`?id=uuid`) |
| `room` | PATCH | Update room |
| `room` | DELETE | Delete room |

## Device catalog (`device_categories`)

| Route | Method | Description |
|-------|--------|-------------|
| `categories` | GET | List active hardware categories (global catalog) |

## Devices (`devices`)

| Route | Method | Description |
|-------|--------|-------------|
| `devices` | GET | List devices (`?property_id=` or `?room_id=` optional) |
| `devices` | POST | Register device |
| `device` | GET | Device detail + assignment + config (`?id=uuid`) |
| `device` | PATCH | Update device metadata |
| `device` | DELETE | Delete device (blocked if `platform.device_commands` exist) |

## Assignments (`device_assignments`)

| Route | Method | Description |
|-------|--------|-------------|
| `assign` | POST | Assign or reassign device to room |
| `unassign` | POST | Remove room assignment |

## Configuration (`device_configurations`)

| Route | Method | Description |
|-------|--------|-------------|
| `device-config` | GET | Read static config (`?device_id=uuid`) |
| `device-config` | PUT/PATCH | Upsert static config JSON |

Static config only — no runtime telemetry or live state.

## Example: create device

```json
POST /functions/v1/devices/devices
{
  "device_name": "Front door lock",
  "category_code": "lock",
  "protocol": "zigbee",
  "parent_device_id": "gateway-uuid",
  "manufacturer": "Aqara"
}
```

## SQL dependencies

| Table / object | Usage |
|----------------|--------|
| `properties` | CRUD via RLS |
| `rooms` | CRUD via property-scoped RLS |
| `devices` | CRUD via RLS |
| `device_categories` | Read catalog |
| `device_assignments` | Assign / unassign |
| `device_configurations` | Static config upsert |
| `platform.device_commands` | FK on device delete (restrict) |
| `public.has_tenant_access` | RLS helper |

## RPC

No public business RPCs in 003. All operations use RLS-protected table access.

## Not applicable as Edge Functions

| 003 capability | Owner |
|----------------|--------|
| `enforce_device_hierarchy` | DB trigger |
| `enforce_device_assignment_tenant_consistency` | DB trigger |
| `platform.device_commands` execution | `jobs/device-commands` (000) |
| `device_integration_map` | `integrations/` (005) |
| Lock credentials / access | `booking/` + `locks/` (004) |
| Category seed data | Migrations 003 / 016 |

## External APIs

None at registration layer. Provider pairing and commands are 005 + `jobs/`.

## Error handling

| Code | Cause |
|------|--------|
| `VALIDATION_ERROR` | Invalid enum label or UUID |
| `FORBIDDEN` | Missing tenant context or RLS denial |
| `SQL_BUSINESS_ERROR` | Hierarchy trigger (gateway parent rules) |
| `NOT_FOUND` | Missing row or route |

## Environment variables

Same as `auth`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL` (audit logging).

## Local development

```bash
supabase functions serve devices --env-file supabase/.env.local
```

## Files

| File | Role |
|------|------|
| `index.ts` | HTTP router |
| `types.ts` | DTO types |
| `validation.ts` | 001 enum label validation |
| `service.ts` | RLS orchestration |
