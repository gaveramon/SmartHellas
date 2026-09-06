---
name: SmartHellas Architecture
alwaysApply: true
description: Mandatory SmartHellas module ownership, migration order, SSOT boundaries, integration architecture and dependency rules.
---

## PURPOSE

This rule governs the structural architecture of SmartHellas.

The architecture is database-centric, multi-tenant, provider-agnostic and modular.

---

# FIXED MIGRATION ORDER

The migration order is:

000_supabase_platform.sql
001_core_types.sql
002_core_saas.sql
003_crm_engine.sql
004_property_device_engine.sql
005_booking_lock_engine.sql
006_device_telemetry.sql
007_integration_engine.sql
008_operations_engine.sql
009_preconfig_engine.sql
010_logistics_engine.sql
011_commerce_engine.sql
012_service_portal_engine.sql
013_onboarding_engine.sql
014_optimization_engine.sql
015_customer_proposal_monetization.sql
016_automation_engine.sql
017_edge_rpc_foundation.sql
018_security_hardening.sql
019_grant_matrix.sql
020_platform_bootstrap.sql
021_production_finalize.sql

This order is authoritative.

---

# MODULE OWNERSHIP

Every table, function, trigger, enum and business concept must have a clear owner.

Before creating an object ask:

> Which module owns this object?

If ownership is unclear, stop and report the ambiguity.

Do not place an object into a module merely because it is convenient.

---

# DEPENDENCY RULE

Earlier migrations must not depend on later migrations.

Bad:

000 → 006

Good:

000 → platform infrastructure

006 → objects from 000–005

007 → objects from 000–006

---

# CROSS-MODULE ACCESS

Cross-module dependencies must be intentional.

A module may consume information from an earlier module where architecturally appropriate.

Avoid circular dependencies.

If a circular dependency is discovered:

1. report it
2. explain why it exists
3. propose alternatives
4. do not silently redesign the system

---

# DOMAIN SSOT

Each business concept must have one authoritative owner.

Do not duplicate the same business state in multiple modules.

Examples:

Device identity:

004 = SmartHellas device
007 = provider identity

Telemetry:

006 = telemetry SSOT

External webhook:

000 = generic inbound boundary

Payment:

011 = payment domain SSOT

---

# PROVIDER ABSTRACTION

The architecture must remain provider-agnostic.

Do not create database structures that assume:

- Aqara is the only provider
- TTLock is the only lock provider
- Shelly is the only energy provider
- Stripe is the only payment provider

Use provider-neutral concepts wherever possible.

Provider-specific behavior belongs at the integration boundary.

---

# DEVICE IDENTITY

There are multiple identities.

SmartHellas device identity:

004.

Provider-side identity:

007.

For integration mapping:

`device_integration_map.external_id`

means the current provider-side identifier.

`device_integration_map.hardware_id`

means the stable provider-side hardware identity.

Do not move these fields into 004 unless explicitly approved.

---

# TELEMETRY BOUNDARY

The conceptual flow is:

External provider
→ 000 generic webhook boundary
→ 007 integration resolution
→ provider identity resolution
→ SmartHellas device resolution
→ 006 telemetry
→ telemetry persistence

000 must not:

- understand Aqara payloads
- understand Shelly payloads
- understand TTLock payloads
- resolve devices
- normalize telemetry
- write telemetry

---

# EDGE FUNCTIONS

Edge Functions are execution/orchestration components.

They must not become an alternative database.

Use PostgreSQL for authoritative state.

Edge Functions should:

- authenticate requests
- validate input
- call RPC/database functions
- communicate with external APIs
- process webhooks
- perform integration operations
- orchestrate asynchronous work

Avoid putting permanent business state only inside Edge Function memory.

---

# FRONTEND

Frontend responsibilities:

- presentation
- user interaction
- client-side validation
- UX state
- initiating approved operations

Frontend must NOT be trusted for:

- tenant isolation
- authorization
- payment state
- device ownership
- security decisions
- final business validation

All security-sensitive decisions must be enforced server-side.

---

# ARCHITECTURAL VIOLATION

Report any violation using:

### CRITICAL
Security/data loss/tenant isolation/SSOT corruption.

### HIGH
Major architecture violation or production reliability issue.

### MEDIUM
Maintainability/performance/design issue.

### LOW
Minor issue.

### INFO
Observation or recommendation.

---

# DO NOT OVERENGINEER

Do not introduce:

- Redis
- Kafka
- RabbitMQ
- Kubernetes
- microservices
- external databases
- unnecessary brokers
- unnecessary caches

unless there is a demonstrated requirement.

The default architecture is:

Supabase PostgreSQL
+
Supabase Edge Functions
+
external provider APIs/webhooks
+
frontend

---

# SCALE

Assume:

- 10,000+ tenants
- millions of telemetry rows
- high webhook volume
- concurrent device events
- concurrent payments
- duplicate webhook delivery
- delayed webhook delivery
- reordered events

Design accordingly.

---

# ARCHITECTURE REVIEW FORMAT

When reviewing architecture provide:

1. Architecture summary
2. Current ownership
3. Dependencies
4. Violations
5. Security concerns
6. Performance concerns
7. Migration-order concerns
8. Recommended changes
9. Risk level
10. Final architecture score /100