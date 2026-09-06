---
name: SmartHellas Integrations
globs:
  - "**/*.sql"
  - "**/*.ts"
  - "**/*.tsx"
description: Aqara, TTLock, Eleksec, Shelly, Stripe, Viva and external integration architecture.
alwaysApply: false
---

## PURPOSE

This rule governs Aqara, TTLock/Eleksec, Shelly and other external providers.

Integrations must remain provider-agnostic at the domain level.

---

# INTEGRATION OWNER

007 Integration Engine owns:

- providers
- tenant integrations
- provider capabilities
- provider device identity
- OAuth
- webhook mappings
- provider reconciliation
- integration routing

---

# PROVIDER LIST

Current important providers include:

- Aqara
- TTLock
- Shelly
- Stripe
- Viva.com

Additional providers may be added.

Do not design the architecture around one provider.

---

# AQARA

The official Aqara API documentation is:

https://opendoc.aqara.com/en/

Use the official Aqara documentation as the authoritative source.

Never invent:

- endpoints
- request formats
- response formats
- event formats
- OAuth behavior
- webhook fields
- device identifiers

If official documentation does not confirm something, mark it:

UNVERIFIED

---

# AQARA OAUTH

OAuth state must be:

- associated with the correct tenant
- associated with the provider
- short-lived
- single-use
- protected against replay
- validated during callback
- associated with the expected redirect URI
- protected against CSRF

Never accept arbitrary tenant/provider values from the callback.

---

# TTLOCK / ELEKSEC

TTLock/Eleksec is an external integration.

Provider-specific identities belong in 007.

Do not put provider identifiers into the core device SSOT in 004.

---

# SHELLY

Shelly is an external integration.

Shelly-specific:

- device IDs
- API identifiers
- webhook identifiers
- provider state

belong in the integration layer.

---

# DEVICE MAPPING

The SmartHellas device is owned by 004.

Provider mapping is owned by 007.

Conceptually:

004 device
↓
007 integration mapping
↓
provider device

---

# DEVICE_INTEGRATION_MAP

`external_id`

= current provider-side identifier.

`hardware_id`

= stable provider-side hardware identity.

Do not confuse these concepts.

---

# RECONCILIATION

Integration reconciliation should handle:

- newly discovered provider devices
- renamed devices
- removed devices
- changed external IDs
- stable hardware identity
- duplicate mappings
- orphaned mappings

Never silently create duplicate SmartHellas devices.

---

# PROVIDER CAPABILITIES

Do not assume all providers support the same capabilities.

Represent capabilities explicitly.

Examples:

- telemetry
- control
- lock/unlock
- temperature
- energy
- smoke detection
- water leak detection

---

# PROVIDER ADAPTERS

Provider-specific API calls belong in integration adapters or Edge Functions.

The domain model should remain provider-neutral.

---

# EXTERNAL API FAILURE

Every integration must expect:

- timeout
- rate limiting
- authentication failure
- revoked credentials
- malformed response
- unavailable provider
- duplicate response
- delayed response
- changed provider API

Failures must not corrupt SmartHellas state.

---

# RETRY

Retries must be:

- bounded
- observable
- idempotent
- safe

Never blindly retry non-idempotent external operations.

---

# API DOCUMENTATION

When implementing provider behavior:

1. check official documentation
2. identify exact endpoint
3. identify authentication method
4. identify request
5. identify response
6. identify error behavior
7. identify rate limits if documented
8. identify webhook behavior if documented

If any item is unknown:

mark it UNVERIFIED.

---

# PROVIDER PRICING RULE

If recommending an external plugin/system/service:

always state price excluding VAT.

If price cannot be verified:

write:

`Price not verified.`

Never invent pricing.