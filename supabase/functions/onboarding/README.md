# Onboarding Edge Function (011 Onboarding Engine)

Wizard state, progress tracking, room/device mapping input, checklist, and notes per property.

**State tracking only** — no step execution, automation side effects, or QR token minting. Flow definitions live in **007** (`preconfig/`). QR pairing orchestration lives in **000** / app layer.

Deploy name: `onboarding`

Base URL: `{SUPABASE_URL}/functions/v1/onboarding/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT. Mutations require `manager`, `admin`, or `owner`.

## Onboarding sessions (`onboarding_sessions`)

One active session per property (`not_started`, `in_progress`, `waiting_user`).

| Route | Method | Description |
|-------|--------|-------------|
| `sessions` | GET | List (`?property_id=` optional) |
| `sessions` | POST | Start session (initializes steps from 007 blueprint) |
| `session` | GET | Full wizard state (`?id=`) |
| `session` | PATCH | Update status / current step / template link |
| `session` | DELETE | Delete session (`id` in body) |

### Start session

```json
POST /functions/v1/onboarding/sessions
{
  "property_id": "uuid",
  "preconfig_template_id": "uuid"
}
```

Resolves `onboarding_blueprint_id` from the preconfig template and seeds `onboarding_step_state` from `onboarding_blueprint_steps`.

`status`: `not_started`, `in_progress`, `waiting_user`, `completed`, `blocked`

## Step progress (`onboarding_step_state`)

| Route | Method | Description |
|-------|--------|-------------|
| `step-states` | GET | List (`?session_id=`) |
| `step-state` | PATCH | Update status / `completed_at` |

## Room mapping input (`onboarding_room_mapping`)

Draft room structure before promotion to 003 `rooms`.

| Route | Method | Description |
|-------|--------|-------------|
| `room-mappings` | GET/POST | List / add draft room |
| `room-mapping` | PATCH/DELETE | Update (`promoted_room_id`) / delete |

## Device placement + QR outcome (`onboarding_device_mapping`)

Records pairing outcome — does not mint QR tokens.

| Route | Method | Description |
|-------|--------|-------------|
| `device-mappings` | GET/POST | List / add placement row |
| `device-mapping` | PATCH/DELETE | Pair device (`device_id`), update `scan_status` |

Setting `device_id` auto-stamps `scanned_at`.

## Checklist (`onboarding_checklist`)

| Route | Method | Description |
|-------|--------|-------------|
| `checklist` | GET | List (`?session_id=`) |
| `checklist` | PUT/POST | Upsert by `checklist_key` |
| `checklist-item` | PATCH/DELETE | Update / delete |

Example keys: `wifi_connected`, `devices_received`, `app_installed`

## Notes (`onboarding_notes`)

| Route | Method | Description |
|-------|--------|-------------|
| `notes` | GET/POST | List / add note (`author_user_id` = caller) |
| `note` | DELETE | Delete note (`id` in body) |

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Blueprint / preconfig catalog** | 007 `preconfig/` |
| **QR token generation** | 000 / mobile app |
| **Promoting rooms/devices into 003** | `devices/` (or future promote workers) |
| **Onboarding automation / workflows** | 006 definitions + 000 execution |
| **Onboarding document uploads** | Supabase Storage `onboarding-docs` bucket |
| **Enums** | 001 Core Types |

## Module layout

```
onboarding/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
