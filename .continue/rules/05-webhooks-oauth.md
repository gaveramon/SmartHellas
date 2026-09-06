---
name: SmartHellas Webhooks and OAuth
globs:
  - "**/*.sql"
  - "**/*.ts"
  - "**/*.tsx"
description: Webhook processing, idempotency, OAuth, callback validation, replay protection and external event routing.
alwaysApply: false
---

## PURPOSE

This rule governs inbound webhooks, event processing, idempotency and OAuth.

---

# GENERIC WEBHOOK BOUNDARY

000 owns:

`platform.external_webhooks`

This is the generic inbound boundary.

It may store:

- source
- external_event_id
- event_type
- tenant_id where safely known
- payload
- received_at
- processing_status
- processed_at
- last_error
- retry_count

However:

000 must not trust external tenant claims as authoritative.

---

# WEBHOOK FLOW

The canonical flow is:

External Provider
→ platform.external_webhooks
→ platform.ingest_external_webhook
→ platform.process_external_webhook
→ public.process_integration_webhook
→ 007
→ provider resolution
→ webhook mapping
→ provider device identity
→ SmartHellas device resolution
→ 006 telemetry / appropriate domain

---

# IDEMPOTENCY

Webhook processing MUST be idempotent.

Assume every webhook can be delivered:

- twice
- three times
- many times

Never assume exactly-once delivery.

Use appropriate:

- external event IDs
- unique constraints
- processing state
- deduplication
- transactional updates

---

# EVENT ORDERING

Events can arrive out of order.

Do not assume:

event A always arrives before event B.

Where state transitions depend on ordering, use:

- event timestamps
- provider sequence numbers if available
- version numbers if available
- monotonic state validation

Only use provider ordering guarantees if officially documented.

---

# EVENT VALIDATION

Validate:

- provider/source
- event type
- event ID
- timestamp
- signature where supported
- payload structure
- mapping

Do not blindly process arbitrary JSON.

---

# WEBHOOK SIGNATURES

If a provider supports webhook signing:

verify the signature before trusting the event.

Never disable signature verification merely because testing is easier.

---

# TENANT RESOLUTION

Never trust:

`payload.tenant_id`

as authoritative.

Resolve tenant through trusted mappings where possible.

For device events:

provider identity
→ integration mapping
→ tenant

---

# ERROR HANDLING

Webhook failures must be observable.

Store:

- processing status
- retry count
- timestamp
- safe error information

Never expose secrets in error fields.

---

# RETRY MODEL

Use retryable vs permanent failures.

Retryable examples:

- temporary provider outage
- network timeout
- transient database failure

Permanent examples:

- invalid event
- unknown event type
- invalid signature
- permanently missing mapping

---

# REPLAY PROTECTION

Do not allow an old OAuth callback or webhook to be replayed indefinitely.

Use:

- expiry
- single-use state
- unique event IDs
- timestamps
- signatures
- processing status

---

# OAUTH STATE

OAuth state must include enough server-side information to validate:

- provider
- tenant
- initiating context
- expiration
- single-use status
- redirect URI where required

Do not trust provider/tenant information returned by the browser.

---

# OAUTH CALLBACK

The callback flow must:

1. receive callback
2. validate state
3. check expiration
4. check single-use
5. validate provider
6. validate redirect URI
7. exchange authorization code
8. securely store credentials
9. mark state consumed
10. establish tenant integration
11. return only safe frontend information

---

# AUTHORIZATION CODE

Never log authorization codes.

Never send access tokens to the frontend unless explicitly required and safe.

---

# OAUTH FAILURE

Handle:

- denied consent
- expired code
- reused code
- invalid state
- provider error
- token exchange failure
- revoked credentials

without corrupting tenant integration state.

---

# WEBHOOK SECURITY

Assume attackers can send arbitrary HTTP requests to webhook endpoints.

Never assume:

"the endpoint URL is secret."

Use available provider authentication/signature mechanisms.

---

# WEBHOOK PROCESSING PRINCIPLE

Receiving an event is not the same as trusting the event.

The system must validate before processing.