# CRM Edge Function (015 CRM Engine)

Customer relationship domain: contacts, companies, leads, pipelines, opportunities, tasks, interactions, notes, tags, lists, campaigns, and custom fields.

**CRM data and definitions only — no email/SMS execution, tenant provisioning, or support tickets.** Marketing send orchestration uses **000** queues + `jobs/`; support cases live in **006** `operations/`.

Deploy name: `crm`

Base URL: `{SUPABASE_URL}/functions/v1/crm/{route}`

## Authentication

```
Authorization: Bearer <supabase_jwt>
```

Tenant-scoped routes require `app_metadata.tenant_id`. Reads: any tenant member. Writes: `manager`, `admin`, or `owner` (RLS + Edge role check).

DELETE routes perform **soft delete** (`deleted_at`) except `custom-field-value` (hard delete).

## Pipelines (`crm_pipelines`, `crm_pipeline_stages`)

| Route | Method | Description |
|-------|--------|-------------|
| `pipelines` | GET/POST | List / create pipelines |
| `pipeline` | GET/PATCH/DELETE | Pipeline + stages (`?id=`) |
| `pipeline-stages` | GET/POST | List (`?pipeline_id=`) / create stage |
| `pipeline-stage` | PATCH/DELETE | Update / soft-delete stage |

## Marketing campaigns (`crm_campaigns`)

Distinct from **013** `upsell_campaigns` and **009** `upsell_rules`.

| Route | Method | Description |
|-------|--------|-------------|
| `campaigns` | GET/POST | List (`?status=`) / create |
| `campaign` | GET/PATCH/DELETE | Get / update / soft-delete |

`campaign_type`: `google_ads`, `facebook`, `referral`, `partner`, `email`, `other`

`status`: `draft`, `active`, `paused`, `completed`, `cancelled`

## Tags & assignments

| Route | Method | Description |
|-------|--------|-------------|
| `tags` | GET/POST | List / create tags |
| `tag` | PATCH/DELETE | Update / soft-delete |
| `tag-assignments` | GET/POST | List (`?entity_type=`, `?entity_id=`) / assign |
| `tag-assignment` | DELETE | Soft-delete assignment |

## Companies & contacts

| Route | Method | Description |
|-------|--------|-------------|
| `companies` | GET/POST | List / create |
| `company` | GET/PATCH/DELETE | CRUD |
| `contacts` | GET/POST | List (`?status=`) / create |
| `contact` | GET/PATCH/DELETE | CRUD |

Consent timestamps (`marketing_consent_at`, `gdpr_consent_at`) sync on PATCH.

## Leads (`crm_leads`)

| Route | Method | Description |
|-------|--------|-------------|
| `leads` | GET/POST | List (`?status=`, `?campaign_id=`) / create |
| `lead` | GET/PATCH/DELETE | CRUD |

PATCH `status=converted` sets `converted_at`. **CRM does not create tenants** — set `converted_tenant_id` via app layer after **002** `auth/tenant-create`.

## Relationship tables (M:N)

| Route | Method | Description |
|-------|--------|-------------|
| `contact-companies` | GET/POST | Contact ↔ company (`?contact_id=`, `?company_id=`) |
| `contact-company` | PATCH/DELETE | Update role / soft-delete |
| `company-tenants` | GET/POST | Company ↔ customer tenant (`?company_id=`) |
| `company-tenant` | PATCH/DELETE | Update link |
| `contact-tenants` | GET/POST | Contact ↔ customer tenant (`?contact_id=`) |
| `contact-tenant` | PATCH/DELETE | Update link |

## Opportunities (`crm_opportunities`)

| Route | Method | Description |
|-------|--------|-------------|
| `opportunities` | GET/POST | List (`?pipeline_id=`, `?stage_id=`, `?status=`) / create |
| `opportunity` | GET/PATCH/DELETE | CRUD |

Requires `contact_id`, `company_id`, or `linked_tenant_id` on create (SQL check).

## Tasks (`crm_tasks`)

| Route | Method | Description |
|-------|--------|-------------|
| `tasks` | GET/POST | List (`?target_type=`, `?target_id=`, `?status=`) / create |
| `task` | GET/PATCH/DELETE | CRUD |

`target_type`: `lead`, `opportunity`, `contact`, `company`, `tenant`

## Interactions (`crm_interactions`) — append-only

| Route | Method | Description |
|-------|--------|-------------|
| `interactions` | GET/POST | Timeline (`?contact_id=`, `?lead_id=`, `?opportunity_id=`, `?company_id=`, `?limit=`) / log |
| `interaction` | PATCH | Soft-delete only (`{ "id" }`) |

No hard delete — SQL immutability trigger. Metadata only (no email bodies).

## Notes (`crm_notes`)

| Route | Method | Description |
|-------|--------|-------------|
| `notes` | GET/POST | List (`?entity_type=`, `?entity_id=`) / create |
| `note` | PATCH/DELETE | Edit (increments `version`) / soft-delete |

## Lists (`crm_lists`, `crm_list_members`)

| Route | Method | Description |
|-------|--------|-------------|
| `lists` | GET/POST | List / create |
| `list` | GET/PATCH/DELETE | CRUD |
| `list-members` | GET/POST | Members (`?list_id=`) / add contact |
| `list-member` | DELETE | Remove member (soft) |

`list_type`: `static`, `dynamic` (dynamic requires `filter_config`)

## Custom fields

| Route | Method | Description |
|-------|--------|-------------|
| `custom-fields` | GET/POST | List (`?applies_to=`) / define field |
| `custom-field` | PATCH/DELETE | Update / soft-delete |
| `custom-field-values` | GET/POST | List / upsert value |
| `custom-field-value` | PATCH/DELETE | Update / hard delete |

`entity_type` / `applies_to`: `lead`, `opportunity`, `contact`, `company`, `tenant`

## Not applicable in this function

| Item | Where it lives |
|------|----------------|
| **Email / SMS / WhatsApp send** | 000 queues + `jobs/` + `shared/mail.ts` / `shared/sms.ts` |
| **Tenant creation on lead conversion** | `auth/tenant-create` (002) — CRM stores FK only |
| **Support tickets** | 006 `operations/` |
| **In-product package upsells** | 013 `monetization/upsell-campaigns` |
| **Plan upsell rules** | 009 `commerce/upsell-rules` |
| **Dynamic list evaluation workers** | `jobs/` (if automated refresh needed) |
| **Enums** | 001 Core Types |

## Module layout

```
crm/
  index.ts
  types.ts
  validation.ts
  service.ts
  README.md
```
