# Auth Edge Function (002 Core SaaS)

Tenant identity, membership, subscription, and service-account orchestration for the Appsmith portal and future Flutter app.

**Business rules live in SQL** (RLS, triggers, `enforce_tenant_owner_invariant`). This function validates JWT, checks access via `has_tenant_access`, and performs RLS-guarded writes.

Deploy name: `auth`

Base URL: `{SUPABASE_URL}/functions/v1/auth/{route}`

## Session & tenant context

| Route | Method | Description | Permissions |
|-------|--------|-------------|-------------|
| `context` | GET | User, active tenant, role, platform admin flag | Authenticated |
| `tenants` | GET | List tenants the user can access | Authenticated |
| `switch-tenant` | POST | Set JWT `app_metadata.tenant_id` | Active membership |

## Tenants (`tenants` table)

| Route | Method | Description | Permissions |
|-------|--------|-------------|-------------|
| `tenant` | GET | Current tenant detail | Tenant member |
| `tenant` | PATCH | Update name / status | Admin or owner |
| `tenant-create` | POST | Create tenant (owner bootstrap via trigger) | Authenticated (RLS) |

## Memberships (`tenant_memberships`)

| Route | Method | Description | Permissions |
|-------|--------|-------------|-------------|
| `memberships` | GET | List members of active tenant | Tenant member |
| `memberships` | POST | Invite / add member by email | Admin or owner |
| `memberships` | PATCH | Update role or deactivate | Admin, or self (`is_active` only) |
| `memberships` | DELETE | Remove membership or self-leave | Admin, or self |

## Subscriptions (`subscriptions`)

| Route | Method | Description | Permissions |
|-------|--------|-------------|-------------|
| `subscription` | GET | Commercial state for tenant | Tenant member |
| `subscription` | PATCH | Update tier / status / period | Admin or owner |

Tier drift rules enforced by 009 SQL triggers on update.

## Service accounts (`service_accounts`)

| Route | Method | Description | Permissions |
|-------|--------|-------------|-------------|
| `service-accounts` | GET | List integration service accounts | Tenant member |
| `service-accounts` | POST | Create service account | Admin or owner |
| `service-accounts` | PATCH | Update service account | Admin or owner |
| `service-accounts` | DELETE | Remove service account | Admin or owner |

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Active tenant operations require `app_metadata.tenant_id` (set via `switch-tenant`).

## Example: invite member

```json
POST /functions/v1/auth/memberships
{
  "email": "manager@example.com",
  "role": "manager"
}
```

Invites via Supabase Auth when the user does not exist; creates `tenant_memberships` row under RLS.

## SQL dependencies

| Object | Usage |
|--------|--------|
| `tenants` | CRUD via RLS |
| `tenant_memberships` | CRUD via RLS; `handle_new_tenant` trigger on tenant create |
| `subscriptions` | Read/update via RLS |
| `service_accounts` | CRUD via RLS |
| `tenant_user_context` | View (not directly exposed; logic mirrored in routes) |
| `public.has_tenant_access(uuid)` | Tenant switch validation |
| `platform.current_tenant_id()` | JWT claim (SQL SSOT) |
| `platform.profiles` | Email lookup for invites (service DB read) |
| `platform.log_audit` | Mutation audit trail |

## Not applicable (002 SQL-only)

| Capability | Owner |
|------------|--------|
| `platform.current_role`, `has_role`, `is_admin`, `has_permission` | SQL RLS / policies |
| `handle_new_tenant` owner bootstrap | DB trigger |
| `enforce_tenant_owner_invariant` | DB trigger |
| Platform auth binding function definitions | Migration 002 |

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes | Project URL |
| `SUPABASE_ANON_KEY` | Yes | Anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Tenant switch, user invite |
| `SUPABASE_DB_URL` | Yes | Profile lookup, platform admin, audit |

## Local development

```bash
supabase functions serve auth --env-file supabase/.env.local
```

## Error codes

| Code | HTTP | Cause |
|------|------|-------|
| `UNAUTHORIZED` | 401 | Missing/invalid JWT |
| `FORBIDDEN` | 403 | RLS / role / tenant policy |
| `VALIDATION_ERROR` | 400 | Invalid body or enum label |
| `NOT_FOUND` | 404 | Unknown route or missing row |
| `SQL_BUSINESS_ERROR` | 422 | Trigger rejection (e.g. last owner) |

## Files

| File | Role |
|------|------|
| `index.ts` | HTTP router |
| `types.ts` | Request/response types |
| `validation.ts` | Input parsing (001 enum labels) |
| `service.ts` | Orchestration only |
