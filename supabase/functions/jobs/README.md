# Jobs Edge Function (000 Platform Layer)

Platform execution workers and cron fallbacks. **No business rules** — orchestrates `platform.*` RPCs, external HTTP/device APIs, and queue state transitions defined in SQL.

Deploy name: `jobs`

## Not applicable as Edge Functions (000 SQL-only)

These 000 responsibilities stay in PostgreSQL / Supabase platform config:

| Capability | Why not Edge |
|------------|--------------|
| RLS helpers (`platform.rls_allow`, `has_tenant_access`) | JWT context in SQL |
| Triggers (`set_updated_at`, `handle_new_auth_user`) | DB triggers |
| Policy factories (`_apply_tenant_rls`) | Migration / service_role DDL |
| Log immutability triggers | DB triggers |
| `pg_cron` schedules (when extension available) | Runs inside Postgres (014) |
| Storage path helpers | Storage RLS policies |
| Partition create/drop (`ensure_log_partitions`) | Invoked by `daily-maintenance` RPC |
| Realtime DDL (`enable_realtime`) | Admin migration only |
| Schema migration registry | CI / migration runner |

Inbound provider webhooks belong in `webhooks/` (separate module). Portal session APIs belong in `auth/` (002 binding).

## Routes

Base: `{SUPABASE_URL}/functions/v1/jobs/{route}`

All routes: `POST`. Auth: `Authorization: Bearer <SERVICE_ROLE_KEY>` or `X-Job-Secret: <JOB_SECRET>`.

| Route | Purpose | Platform RPC / tables |
|-------|---------|----------------------|
| `cron-tick` | Fallback for `platform.run_platform_cron_tick` | `run_platform_cron_tick`, `log_job_execution` |
| `daily-maintenance` | Partitions, log purge, activation sync | `run_platform_daily_maintenance` |
| `device-commands` | Execute lock/device command queue | `fetch_next_command`, `update_device_command_status`, `move_to_dlq` |
| `integration-queue` | Dispatch integration queue HTTP work | `process_integration_queue`, `integration_queue`, `dispatch_http_request` |
| `retry-tasks` | Execute handler-specific retry work | `process_retry_tasks`, `retry_tasks` |
| `shipment-dispatch` | Carrier label/dispatch HTTP | `process_shipment_dispatch_queue`, `shipment_dispatch_queue` |
| `shipment-tracking` | Idempotent tracking event ingest | `ingest_shipment_tracking_event` |
| `heartbeat` | Edge node liveness | `update_node_heartbeat`, `system_nodes`, `node_heartbeats` |
| `outbound-webhooks` | Deliver outbound HTTP subscriptions | `integration_queue` (http/outbound types) |

### Batch body (optional)

```json
{ "batch_size": 25 }
```

`batch_size` clamped 1–100. Defaults to 25.

### Shipment tracking body

```json
{
  "carrier_source": "dhl",
  "external_event_id": "evt_123",
  "fulfilment_order_id": "uuid",
  "event_type": "in_transit",
  "occurred_at": "2026-06-29T12:00:00Z",
  "tenant_id": "uuid",
  "location": "Athens",
  "payload": {}
}
```

### Heartbeat body

```json
{
  "node_type": "edge_worker",
  "node_identifier": "jobs-eu-1",
  "status": "alive",
  "metadata": { "version": "1.0" }
}
```

## External APIs

| Worker | Providers |
|--------|-----------|
| `device-commands` | TTLock, Aqara, generic HTTP (from payload) |
| `integration-queue` / `outbound-webhooks` | Any URL via `pg_net` / payload |
| `shipment-dispatch` | Carrier APIs via payload URL |

Credentials resolved via `platform.get_vault_secret(credentials_ref)` — never stored in Edge env per tenant.

## Scheduling

| Job | Primary trigger | Edge fallback |
|-----|-----------------|---------------|
| Cron tick | `pg_cron` every minute | Supabase scheduled function → `cron-tick` |
| Daily maintenance | `pg_cron` 02:15 UTC | Supabase scheduled function → `daily-maintenance` |
| Device commands | After cron tick or continuous worker | `device-commands` on schedule |
| Integration queue | After cron tick | `integration-queue` |
| Retry tasks | After cron tick | `retry-tasks` |

## Idempotency

| Component | Mechanism |
|-----------|-----------|
| Device commands | `(tenant_id, idempotency_key)` unique index |
| Shipment tracking | `(carrier_source, external_event_id)` unique |
| External webhooks | `(source, external_event_id)` — use `webhooks/` module |
| Integration queue | Status transitions; redelivery safe at HTTP layer |

## Error handling

- Transient device errors → `retrying` with SQL `calculate_backoff`
- Max retries → `move_to_dlq` / `dead_letter` / `archive_dead_letter`
- Job-level failures → `platform.log_job_execution` with error text
- Per-item failures counted in response `{ processed, succeeded, failed }`

## Logging

- Structured JSON console via `shared/logger.ts`
- `platform.log_event` for item-level traces
- `platform.log_job_execution` for cron/maintenance runs

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Job auth |
| `SUPABASE_DB_URL` | Yes | Platform schema access |
| `JOB_SECRET` | Recommended | Alternative to service role in schedulers |
| `NODE_IDENTIFIER` | Optional | Worker ID in command status |
| `TTLOCK_CLIENT_ID` / `SECRET` | For TTLock commands | Platform-level app credentials |
| `AQARA_APP_ID` / `KEY` | For Aqara commands | Platform-level app credentials |

## Local development

```bash
supabase functions serve jobs --env-file supabase/.env.local
```

```bash
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  http://127.0.0.1:54321/functions/v1/jobs/cron-tick
```

## Files

| File | Role |
|------|------|
| `index.ts` | Router + job auth gate |
| `types.ts` | Worker result types |
| `validation.ts` | Input parsing |
| `service.ts` | Worker orchestration (no business rules) |
