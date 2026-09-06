# Preconfig Edge Function (007 Preconfig Engine)

Global hardware/installation blueprint catalog — device bundles, onboarding flow specs, preconfig templates, and room installation maps.

**Global catalog only — no tenant data, no runtime state.** Tenant template selection happens in 011 (`onboarding_sessions.preconfig_template_id`).

Deploy name: `preconfig`

Base URL: `{SUPABASE_URL}/functions/v1/preconfig/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Tenant context is **not required** for catalog reads (browse before or during onboarding).

**Writes require platform admin** (`platform.platform_admins`) — matches SQL RLS.

## Device bundles (`device_bundles`)

Versioned hardware BOM catalog.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `bundles` | GET | any | List bundles (`?property_type=` / `?active_only=true`) |
| `bundles` | POST | platform admin | Create bundle |
| `bundle` | GET | any | By `?id=` or `?code=` (+ optional `?version=`) |
| `bundle` | PATCH | platform admin | Update bundle |
| `bundle` | DELETE | platform admin | Delete bundle (`id` in body) |

## Bundle devices (`bundle_devices`)

Hardware components per bundle.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `bundle-devices` | GET | any | List (`?bundle_id=uuid`) |
| `bundle-devices` | POST | platform admin | Add component |
| `bundle-device` | PATCH | platform admin | Update quantity/config |
| `bundle-device` | DELETE | platform admin | Remove component |

## Onboarding blueprints (`onboarding_blueprints`)

Installation flow specification (not runtime onboarding — see 011).

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `blueprints` | GET | any | List blueprints |
| `blueprints` | POST | platform admin | Create blueprint |
| `blueprint` | GET | any | Detail + steps (`?id=` or `?code=`) |
| `blueprint` | PATCH | platform admin | Update |
| `blueprint` | DELETE | platform admin | Delete |

## Blueprint steps (`onboarding_blueprint_steps`)

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `blueprint-steps` | GET | any | List (`?blueprint_id=`) |
| `blueprint-steps` | POST | platform admin | Add step |
| `blueprint-step` | PATCH | platform admin | Update |
| `blueprint-step` | DELETE | platform admin | Delete |

`step_type`: `wifi_setup`, `device_assignment`, `room_mapping`, `integration_link`, `testing`, `finalization`

## Preconfig templates (`preconfig_templates`)

Composite install blueprint linking bundle + optional onboarding blueprint.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `templates` | GET | any | List templates |
| `templates` | POST | platform admin | Create template |
| `template` | GET | any | Template + device map + bundle devices (`?id=`) |
| `template` | PATCH | platform admin | Update |
| `template` | DELETE | platform admin | Delete |

## Device installation map (`preconfig_device_map`)

Category → room placement hints per template.

| Route | Method | Auth | Description |
|-------|--------|------|-------------|
| `device-map` | GET | any | List (`?template_id=`) |
| `device-map` | POST | platform admin | Add mapping |
| `device-map-entry` | PATCH | platform admin | Update |
| `device-map-entry` | DELETE | platform admin | Delete |

## Example: browse templates for apartment

```
GET /functions/v1/preconfig/templates?property_type=apartment&active_only=true
```

## Example: full template detail (onboarding picker)

```
GET /functions/v1/preconfig/template?id=<template-uuid>
```

Returns `template`, `device_map`, and `bundle_devices`.

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Tenant onboarding runtime** (sessions, progress, step state) | 011 Onboarding Engine |
| **Applying preconfig to tenant properties/devices** | 011 + 003 during onboarding execution |
| **Device category catalog** | 003 (`devices/categories`) |
| **Warehouse / fulfilment** | 008 Logistics |
| **Enums** | 001 Core Types |
| **Catalog seed data** | Migrations / platform admin |

## Module layout

```
preconfig/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
