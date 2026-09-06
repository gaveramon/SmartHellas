---
name: SmartHellas Security and RLS
globs:
  - "**/*.sql"
  - "**/*.ts"
  - "**/*.tsx"
description: Security, RLS, tenant isolation, authorization, SECURITY DEFINER, secrets and privilege escalation rules.
alwaysApply: false
---

## PURPOSE

Security is a first-class architectural concern.

The system must be secure even if the frontend is completely compromised.

---

# ZERO TRUST FRONTEND

Never trust:

- tenant_id from the client
- user_id from the client
- property_id from the client
- device_id from the client
- payment state from the client
- role claims without validation
- provider ownership supplied by the client

Every sensitive relationship must be resolved or verified server-side.

---

# TENANT ISOLATION

Every tenant-scoped table must have a clear tenant isolation strategy.

Ask:

1. Does this table contain tenant-owned data?
2. How is tenant ownership determined?
3. Can RLS enforce it?
4. Can a user access another tenant through joins?
5. Can SECURITY DEFINER bypass RLS?
6. Can an RPC expose cross-tenant data?

---

# RLS

RLS must be enabled on all relevant tenant-owned tables.

Policies must enforce actual authorization.

Do not use policies that effectively mean:

```sql
tenant_id = auth.uid()

unless auth.uid() is actually the tenant identifier.

Use the established membership/tenant model.

RLS POLICY REVIEW

For every policy inspect:

SELECT
INSERT
UPDATE
DELETE

Check both:

USING

and:

WITH CHECK

Do not assume SELECT protection automatically protects INSERT/UPDATE.

AUTHORIZATION

Authentication answers:

Who are you?

Authorization answers:

What are you allowed to do?

Both must be implemented.

Roles must not automatically imply unrestricted tenant access.

PRIVILEGE ESCALATION

Look for:

SECURITY DEFINER functions
unrestricted EXECUTE grants
service-role assumptions
overly broad policies
public functions
writable security tables
tenant_id manipulation
SECURITY DEFINER

Every SECURITY DEFINER function requires special review.

Check:

search_path
ownership
EXECUTE grants
input validation
tenant authorization
object references
dynamic SQL
privilege escalation
SEARCH_PATH SECURITY

Do not rely on a caller-controlled search_path inside SECURITY DEFINER functions.

Use an explicit safe search_path.

SECRETS

Never store:

OAuth client secrets
API keys
access tokens
refresh tokens
payment secrets

in frontend-visible tables unless they are deliberately encrypted and inaccessible to normal clients.

Prefer Supabase secrets/environment variables or an appropriate secure secret mechanism.

TOKEN SECURITY

OAuth/access tokens must:

never be exposed to the frontend unnecessarily
never be logged
never appear in error messages
never be returned by public RPCs
be protected from unauthorized tenant access
LOGGING

Never log:

access tokens
refresh tokens
passwords
payment secrets
API secrets
sensitive authentication data

Payload logging must be reviewed for accidental secret leakage.

WEBHOOK SECURITY

Do not trust webhook payload claims such as:

tenant_id
user_id
ownership
authorization

Resolve ownership using trusted integration mappings.

PAYMENT SECURITY

Never trust payment status from the browser.

Payment state must come from:

verified provider webhook
verified provider API
trusted backend operation
INPUT VALIDATION

Validate:

UUIDs
enums
identifiers
timestamps
numeric values
strings
external IDs
provider codes
tenant ownership
SQL INJECTION

Avoid dynamic SQL.

If dynamic SQL is unavoidable:

use format()
quote identifiers correctly
use parameterized values
validate all dynamic identifiers
SECURITY AUDIT SEVERITY

CRITICAL:

cross-tenant access
leaked secrets
authentication bypass
authorization bypass
payment manipulation

HIGH:

unsafe SECURITY DEFINER
missing RLS
privilege escalation possibility

MEDIUM:

weak validation
excessive permissions
insufficient auditability

LOW:

hardening opportunity
SECURITY PRINCIPLE

Assume:

malicious tenant
malicious authenticated user
compromised frontend
duplicate requests
manipulated request body
forged client state
concurrent requests

The database and backend must remain authoritative.