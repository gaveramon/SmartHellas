---
name: SmartHellas Production Quality
description: Production readiness, reliability, observability, concurrency, error handling and release validation.
alwaysApply: false
---

## PURPOSE

SmartHellas must be production-ready, not merely functional.

---

# PRODUCTION REQUIREMENTS

A feature is not complete merely because:

- the SQL executes
- the API responds
- the frontend displays data

It must also be:

- secure
- tenant-isolated
- idempotent
- observable
- recoverable
- performant
- maintainable

---

# ERROR HANDLING

Errors must be:

- deterministic where possible
- meaningful
- safe
- observable

Never expose:

- secrets
- tokens
- internal stack traces
- database credentials
- sensitive provider data

to end users.

---

# OBSERVABILITY

Important asynchronous workflows should expose sufficient state to diagnose:

- what happened
- when it happened
- which tenant was affected
- which integration was involved
- whether processing succeeded
- whether retry is possible
- what failed

---

# RETRIES

Retries must not create:

- duplicate payments
- duplicate devices
- duplicate orders
- duplicate telemetry
- duplicate webhook effects

Use idempotency.

---

# CONCURRENCY

Always consider concurrent requests.

Examples:

Two requests simultaneously:

- create an order
- process a webhook
- assign a device
- update a payment
- refresh OAuth
- change automation

Database constraints and transactions must protect state.

---

# STATE MACHINES

When an entity has meaningful states:

- define valid states
- define valid transitions
- prevent impossible transitions
- consider concurrent transitions

Do not rely solely on frontend logic.

---

# EXTERNAL PROVIDERS

External APIs are unreliable dependencies.

Expect:

- downtime
- rate limits
- latency
- authentication failures
- API changes
- malformed responses
- duplicate events

SmartHellas must fail safely.

---

# PAYMENTS

Payment state must be authoritative.

Never mark an order paid merely because:

- frontend says so
- redirect occurred
- user returned from provider
- browser callback says success

Use verified provider state.

---

# WEBHOOKS

Production webhook processing must support:

- duplicates
- retries
- delayed events
- reordered events
- invalid events
- provider outages

---

# DATA RETENTION

For large datasets, especially telemetry, consider:

- retention policies
- archival
- deletion strategy
- indexing
- storage growth

Do not delete business-critical records without a defined retention policy.

---

# BACKUPS

Production design should consider:

- database backups
- recovery
- migration rollback strategy
- disaster recovery

---

# MIGRATION SAFETY

Before production migration:

- validate syntax
- validate dependencies
- test clean installation
- test upgrade path
- review destructive changes
- review RLS
- review grants
- review functions/triggers

---

# PERFORMANCE

Assume production scale from day one.

Do not rely on:

- tiny test datasets
- frontend filtering
- full-table scans
- unbounded queries

---

# SECURITY

Production review must include:

- RLS
- grants
- SECURITY DEFINER
- secret handling
- OAuth
- webhooks
- payment flows
- tenant isolation
- API authorization

---

# RELEASE CHECKLIST

Before calling something production-ready:

- [ ] Database migration validated
- [ ] RLS validated
- [ ] Grants validated
- [ ] Tenant isolation validated
- [ ] Functions reviewed
- [ ] SECURITY DEFINER reviewed
- [ ] Webhooks idempotent
- [ ] OAuth secure
- [ ] Secrets protected
- [ ] External API failures handled
- [ ] Retry behavior validated
- [ ] Concurrency reviewed
- [ ] Performance reviewed
- [ ] Logging reviewed
- [ ] No architecture violations
- [ ] No destructive unapproved changes
- [ ] Clean migration execution validated

---

# PRODUCTION SCORE

When requested, score:

Security: /20
Architecture: /20
Data integrity: /15
Scalability: /15
Reliability: /10
Maintainability: /10
Observability: /5
Deployment readiness: /5

Total: /100

---

# FINAL PRINCIPLE

"Works" is not equivalent to "production-ready".

A feature is production-ready only when the complete system behavior has been considered.