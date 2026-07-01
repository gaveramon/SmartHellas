# REV19 Edge Architecture Refactor Report

Migrations **017–023** placed domain business logic inside Edge-oriented SQL.  
This refactor **does not modify 000–016 or 017–023**. New migrations **024–030** establish domain SSOT and thin Edge wrappers.

## Layer model (target)

| Layer | Owns | Examples |
|-------|------|----------|
| **Edge (API)** | Guards, auth context, thin `*_api` dispatch | `edge_require_*`, `devices_api`, `is_platform_admin` |
| **Domain (SSOT)** | Tables, triggers, workflows, `*_domain` | `devices_domain`, `crm_soft_delete_row`, `trg_crm_*` |
| **Platform (000)** | Execution, queues, audit, vault | `platform.enqueue_shipment_dispatch`, `platform.log_audit` |

---

## Object classification (017–023)

### 017 `edge_rpc_foundation_rev19.sql`

| Object | Current (017) | Correct domain | Classification | Action (024–030) |
|--------|---------------|----------------|----------------|------------------|
| `is_platform_admin()` | Edge | Platform wrapper | **Edge infrastructure** | Keep (017); no change |
| `edge_require_tenant()` | Edge | Edge | **Edge infrastructure** | Keep (017) |
| `edge_require_manager()` | Edge | Edge | **Edge infrastructure** | Keep (017) |
| `edge_require_admin()` | Edge | Edge | **Edge infrastructure** | Keep (017) |
| `trg_customer_proposals_status_timestamps` | Edge (017) | **013 Monetization** | Business trigger | **026** `CREATE OR REPLACE` |
| `trg_crm_contacts_consent_timestamps` | Edge (017) | **015 CRM** | Business trigger | **028** `CREATE OR REPLACE` |
| `trg_crm_leads_conversion_timestamp` | Edge (017) | **015 CRM** | Business trigger | **028** `CREATE OR REPLACE` |
| `trg_crm_notes_version_increment` | Edge (017) | **015 CRM** | Business trigger | **028** `CREATE OR REPLACE` |
| `assign_device_to_room()` | Edge (017) | **003 Devices** | Business workflow | **024** `devices_assign_device_to_room`; **030** thin wrapper |
| `change_subscription_plan()` | Edge (017) | **009 Commerce** (+002 subscription) | Business workflow | **026** `commerce_change_subscription_plan`; **030** thin wrapper |
| `dispatch_fulfilment_order()` | Edge (017) | **008 Logistics** | Business workflow | **026** `logistics_dispatch_fulfilment_order`; **030** thin wrapper |
| `edge_soft_delete_row()` | Edge (017) | **015 CRM** | Business helper | **028** `crm_soft_delete_row`; **030** thin wrapper |

### 018 `edge_rpc_devices_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `devices_api()` | 003 Devices | Mixed (guards + CRUD) | **024** `devices_domain`; **029** thin `devices_api` |

### 019 `edge_rpc_booking_locks_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `booking_api()` | 004 Booking | Mixed | **025** `booking_domain`; **029** thin `booking_api` |
| `locks_api()` | 004 Booking/Locks | Mixed | **025** `locks_domain`; **029** thin `locks_api` |

### 020 `edge_rpc_commerce_logistics_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `commerce_api()` | 009 Commerce | Mixed | **026** `commerce_domain`; **029** thin `commerce_api` |
| `logistics_api()` | 008 Logistics | Mixed | **026** `logistics_domain`; **029** thin `logistics_api` |

### 021 `edge_rpc_modules_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `portal_api()` | 010 Portal | Mixed | **027** `portal_domain`; **029** thin wrapper |
| `onboarding_api()` | 011 Onboarding | Mixed | **027** `onboarding_domain`; **029** thin wrapper |
| `optimization_api()` | 012 Intelligence | Mixed | **027** `optimization_domain`; **029** thin wrapper |
| `monetization_api()` | 013 Growth/Monetization | Mixed | **027** `monetization_domain`; **029** thin wrapper |
| `operations_api()` | 006 Operations | Mixed | **027** `operations_domain`; **029** thin wrapper |
| `preconfig_api()` | 007 Preconfig | Mixed | **027** `preconfig_domain`; **029** thin wrapper |
| `integrations_api()` | 005 Integrations | Mixed | **027** `integrations_domain`; **029** thin wrapper |
| `auth_api()` | 002 Core SaaS | Mixed | **027** `auth_domain`; **029** thin wrapper |

### 022 `edge_rpc_crm_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `crm_api()` | 015 CRM | Mixed | **028** `crm_domain`; **029** thin `crm_api` |

### 023 `edge_rpc_oauth_complete_rev19.sql`

| Object | Domain | Classification | Action |
|--------|--------|----------------|--------|
| `integrations_oauth_complete()` | 005 Integrations | Business + Edge entry | **027** `integrations_complete_oauth`; **030** thin wrapper |

---

## New migrations

| File | Owner | Contents |
|------|-------|----------|
| `024_devices_extensions_rev19.sql` | 003 | `devices_domain`, `devices_assign_device_to_room` |
| `025_booking_locks_extensions_rev19.sql` | 004 | `booking_domain`, `locks_domain` |
| `026_commerce_logistics_extensions_rev19.sql` | 009/008/013 | `commerce_domain`, `logistics_domain`, plan change, dispatch, proposal trigger |
| `027_module_extensions_rev19.sql` | 002–007, 010–013 | `portal_domain`, `onboarding_domain`, `optimization_domain`, `monetization_domain`, `operations_domain`, `preconfig_domain`, `integrations_domain`, `auth_domain`, `integrations_complete_oauth` |
| `028_crm_extensions_rev19.sql` | 015 | `crm_domain`, `crm_soft_delete_row`, CRM triggers |
| `029_edge_api_thin_wrappers_rev19.sql` | Edge | Thin `*_api` (guards → `*_domain`) |
| `030_edge_foundation_thin_rev19.sql` | Edge | Thin wrappers for 017 entrypoints + OAuth callback |

---

## Verification checklist

| Check | Status |
|-------|--------|
| 000–016 untouched | ✔ |
| 017–023 untouched | ✔ |
| Business logic in domain `*_domain` / domain helpers | ✔ |
| Edge `*_api` = guards + delegate only | ✔ (029) |
| No duplicated trigger bodies (CREATE OR REPLACE supersedes 017) | ✔ |
| Domain SSOT by owning module, not migration number | ✔ |

---

## Apply order

```
024 → 025 → 026 → 027 → 028 → 029 → 030
```

After apply, Edge TypeScript continues calling `*_api` RPCs; behavior is preserved with correct architectural ownership.
