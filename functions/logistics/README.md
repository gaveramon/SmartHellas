# Logistics Edge Function (008 Logistics Engine)

Fulfilment definitions and shipment intent — delivery templates, package definitions, carriers, warehouses, shipping rules, and fulfilment orders.

**Definition + business intent only.** Carrier API calls, label generation, tracking ingest, and inventory execution live in **000** (`shipment_dispatch_queue`, `shipment_tracking_events`) and **`jobs/`** workers.

Deploy name: `logistics`

Base URL: `{SUPABASE_URL}/functions/v1/logistics/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Requires active tenant in JWT for tenant-scoped operations. Global catalog reads (carriers, label templates) still require authentication.

Mutations on tenant-owned rows require `manager`, `admin`, or `owner`. Carrier and label template writes require **platform admin**.

## Logistics templates (`logistics_templates`)

| Route | Method | Description |
|-------|--------|-------------|
| `templates` | GET | List tenant + system templates |
| `templates` | POST | Create tenant template |
| `template` | GET | Template + packages (`?id=`) |
| `template` | PATCH | Update tenant template |
| `template` | DELETE | Delete tenant template |

## Package definitions (`package_definitions`)

Links logistics template → 007 `device_bundles` (BOM not duplicated).

| Route | Method | Description |
|-------|--------|-------------|
| `packages` | GET | List (`?template_id=`) |
| `packages` | POST | Create package definition |
| `package` | PATCH | Update |
| `package` | DELETE | Delete |

## Shipping carriers (`shipping_carriers`)

Global catalog — read all authenticated, write platform admin.

| Route | Method | Description |
|-------|--------|-------------|
| `carriers` | GET | List active carriers |
| `carriers` | POST | Platform admin create |
| `carrier` | GET/PATCH/DELETE | Platform admin |

`provider_code` references 005 `integration_providers`.

## Warehouses (`warehouses`)

| Route | Method | Description |
|-------|--------|-------------|
| `warehouses` | GET | List tenant + system warehouses |
| `warehouses` | POST | Create tenant warehouse |
| `warehouse` | GET/PATCH/DELETE | Tenant warehouse CRUD |

## Label templates (`shipping_label_templates`)

Format/service code definitions — not generated labels.

| Route | Method | Description |
|-------|--------|-------------|
| `label-templates` | GET | List (`?carrier_id=` optional) |
| `label-templates` | POST | Platform admin create |
| `label-template` | PATCH/DELETE | Platform admin |

`label_format`: `pdf`, `zpl`, `png`

## Shipping rules (`shipping_rules`)

Routing/pricing definitions — no execution.

| Route | Method | Description |
|-------|--------|-------------|
| `shipping-rules` | GET | List tenant + system rules |
| `shipping-rules` | POST | Create tenant rule |
| `shipping-rule` | PATCH/DELETE | Update/delete tenant rule |

## Fulfilment orders (`fulfilment_orders`)

Shipment intent — no tracking numbers or label URLs in this table.

| Route | Method | Description |
|-------|--------|-------------|
| `fulfilment-orders` | GET | List (`?status=` / `?property_id=`) |
| `fulfilment-orders` | POST | Create order |
| `fulfilment-order` | GET/PATCH/DELETE | Order CRUD |
| `dispatch` | POST | Enqueue carrier dispatch (see below) |

`status`: `draft`, `ready_to_ship`, `dispatched`, `delivered`, `cancelled`

### Create fulfilment order

```json
POST /functions/v1/logistics/fulfilment-orders
{
  "property_id": "uuid",
  "package_definition_id": "uuid",
  "carrier_id": "uuid",
  "warehouse_id": "uuid",
  "label_template_id": "uuid"
}
```

Requires `package_definition_id` or `device_bundle_id`. SQL triggers enforce tenant/property/carrier consistency.

### Dispatch (enqueue only)

```json
POST /functions/v1/logistics/dispatch
{
  "fulfilment_order_id": "uuid",
  "payload": { "url": "https://carrier-api/..." }
}
```

Order must be `ready_to_ship`. Calls `platform.enqueue_shipment_dispatch`; worker in `jobs/shipment-dispatch` performs HTTP/carrier calls.

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Carrier API execution / label PDF generation** | 000 + `jobs/shipment-dispatch` |
| **Tracking event ingest** | 000 + `jobs/shipment-tracking` |
| **Inventory / stock movements** | 000 platform |
| **Hardware BOM contents** | 007 `device_bundles` / `bundle_devices` |
| **Payment / proposal acceptance** | 009 / 013 (optional `customer_proposal_id` link) |
| **Enums** | 001 Core Types |

## Module layout

```
logistics/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
