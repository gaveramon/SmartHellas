# Operations Edge Function (006 Operations Engine)

Workflow definitions, operation templates, and tenant support cases.

**Definition layer only** — no workflow execution, logging, or runtime state (those live in 000 platform queues and `jobs/`). Advisory optimization rules live in 012.

Deploy name: `operations`

Base URL: `{SUPABASE_URL}/functions/v1/operations/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT (`auth/switch-tenant`). Template/workflow mutations require `manager`, `admin`, or `owner`. Support tickets are available to all tenant members.

## Operation templates (`operation_templates`)

System templates (`is_system = true`) are read-only via RLS. Tenant templates are manager+ writable.

| Route | Method | Description |
|-------|--------|-------------|
| `templates` | GET | List tenant + system templates |
| `templates` | POST | Create tenant template |
| `template` | GET | Get template (`?id=uuid`) |
| `template` | PATCH | Update tenant template (`id` in body) |
| `template` | DELETE | Delete tenant template (`id` in body) |

## Operation workflows (`operation_workflows`)

| Route | Method | Description |
|-------|--------|-------------|
| `workflows` | GET | List tenant workflows |
| `workflows` | POST | Create workflow |
| `workflow` | GET | Workflow + steps + triggers (`?id=uuid`) |
| `workflow` | PATCH | Update workflow |
| `workflow` | DELETE | Delete workflow (cascades steps/triggers) |

### Create workflow example

```json
POST /functions/v1/operations/workflows
{
  "name": "Check-in automation",
  "description": "Notify guest and issue lock code",
  "source_template_id": "template-uuid",
  "is_active": true
}
```

## Workflow steps (`workflow_steps`)

| Route | Method | Description |
|-------|--------|-------------|
| `workflow-steps` | GET | List steps (`?workflow_id=uuid`) |
| `workflow-steps` | POST | Add step |
| `workflow-step` | PATCH | Update step |
| `workflow-step` | DELETE | Delete step (`id` in body) |

`action_type` enum (SQL SSOT): `send_notification`, `update_device`, `generate_code`, `update_booking`, `run_optimization`, `trigger_webhook`.

```json
POST /functions/v1/operations/workflow-steps
{
  "workflow_id": "workflow-uuid",
  "step_order": 1,
  "action_type": "send_notification",
  "config": { "template": "welcome" },
  "delay_seconds": 0
}
```

## Workflow triggers (`workflow_triggers`)

| Route | Method | Description |
|-------|--------|-------------|
| `workflow-triggers` | GET | List triggers (`?workflow_id=uuid`) |
| `workflow-triggers` | POST | Add trigger |
| `workflow-trigger` | PATCH | Update trigger |
| `workflow-trigger` | DELETE | Delete trigger (`id` in body) |

`trigger_type` enum: `booking_created`, `booking_started`, `booking_ended`, `device_added`, `manual_trigger`, `schedule_based`.

`property_id` optional — SQL enforces tenant consistency with workflow and property.

## Support tickets (`support_tickets`)

| Route | Method | Description |
|-------|--------|-------------|
| `support-tickets` | GET | List (`?status=` / `?priority=` optional) |
| `support-tickets` | POST | Open ticket |
| `support-ticket` | GET | Get ticket (`?id=uuid`) |
| `support-ticket` | PATCH | Update status/priority/content |
| `support-ticket` | DELETE | Delete ticket (`id` in body) |

`status`: `open`, `in_progress`, `waiting_customer`, `resolved`, `closed`

`priority`: `low`, `normal`, `high`, `urgent`, `critical`

## Support messages (`support_messages`)

| Route | Method | Description |
|-------|--------|-------------|
| `support-messages` | GET | List messages (`?ticket_id=uuid`) |
| `support-messages` | POST | Post tenant message (`sender_type` defaults to `user`) |

Platform support replies (`sender_type: support`) are not exposed here — use platform admin tooling.

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Workflow execution / runtime state** | 000 platform (`operation_queue`, workers in `jobs/`) |
| **Workflow run logs / audit trail** | 000 platform logging |
| **Manual workflow trigger (fire now)** | 000 execution layer — enqueue via platform, not definition CRUD |
| **Optimization advisory rules** | 012 Intelligence Engine |
| **System template seed / admin writes** | Migrations + platform admin SQL |
| **Enums** | 001 Core Types — validated in Edge for input shape only |

## Module layout

```
operations/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
