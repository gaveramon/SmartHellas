---
name: SmartHellas PostgreSQL SQL
alwaysApply: true
description: Mandatory PostgreSQL, SQL migration, database design, indexing, functions, triggers and scalability rules.
---

## PURPOSE

This rule governs PostgreSQL schema design, SQL migrations, functions, triggers, indexes and database performance.

PostgreSQL is the SSOT.

---

# GENERAL SQL RULES

Write production-grade PostgreSQL.

Prefer:

- explicit types
- explicit constraints
- foreign keys
- CHECK constraints
- UNIQUE constraints
- NOT NULL where appropriate
- deterministic functions
- transaction-safe operations
- proper indexes
- clear naming

Avoid:

- unnecessary dynamic SQL
- duplicated logic
- implicit casts
- unbounded queries
- N+1 database access
- redundant tables
- redundant state

---

# NAMING

Use consistent snake_case.

Tables:

plural nouns where appropriate.

Examples:

- tenants
- properties
- devices
- payments
- payment_events

Foreign keys should normally be:

`<entity>_id`

Examples:

tenant_id
property_id
device_id
integration_id

---

# PRIMARY KEYS

Prefer UUID identifiers for distributed SaaS entities unless there is a clear reason otherwise.

Never introduce a second competing identifier without justification.

---

# FOREIGN KEYS

Use foreign keys to enforce integrity.

Do not rely solely on application code to maintain relationships.

Always consider:

- ON DELETE CASCADE
- ON DELETE RESTRICT
- ON DELETE SET NULL

based on domain ownership.

Never blindly use CASCADE.

---

# UNIQUE CONSTRAINTS

Use database uniqueness for true uniqueness requirements.

Do not implement uniqueness only in application code.

Examples:

tenant + external_event_id

tenant + provider + external_id

provider + stable provider hardware identity

---

# CHECK CONSTRAINTS

Use CHECK constraints for invariant values where appropriate.

Examples:

- positive quantities
- valid percentages
- valid state combinations
- non-negative monetary values

---

# NULLABILITY

Do not make everything nullable.

Use NULL only when absence has semantic meaning.

---

# JSONB

JSONB is allowed for:

- provider payloads
- raw webhook payloads
- flexible metadata
- provider-specific attributes

Do not use JSONB to avoid designing relational structures for frequently queried business state.

If a field is:

- frequently filtered
- joined
- constrained
- indexed
- business-critical

consider a proper column.

---

# INDEXING

Every index must have a reason.

Consider indexes for:

- tenant_id
- foreign keys
- lookup keys
- webhook event IDs
- provider identifiers
- timestamps used in range queries
- status columns when selective
- composite access patterns

Do not blindly index every column.

---

# MULTI-TENANT INDEXING

For tenant-scoped large tables, consider composite indexes such as:

`(tenant_id, created_at)`

or:

`(tenant_id, status)`

based on actual query patterns.

---

# TELEMETRY

Telemetry is expected to become one of the largest tables.

Design for millions of rows.

Consider:

- append-oriented storage
- efficient timestamp indexes
- tenant/device access paths
- partitioning only when justified
- retention strategies
- efficient ingestion

Do not prematurely introduce partitioning without evidence.

---

# FUNCTIONS

Database functions must have:

- clear ownership
- clear input/output
- appropriate volatility
- explicit security behavior
- safe search_path where relevant
- deterministic behavior where possible

---

# SECURITY DEFINER

For every SECURITY DEFINER function:

- explicitly define search_path
- minimize privileges
- validate tenant context
- validate authorization
- avoid SQL injection
- avoid unsafe dynamic SQL
- never trust client-supplied ownership
- ensure only intended callers have EXECUTE

Example principle:

```sql
SECURITY DEFINER
SET search_path = public, pg_catalog

The exact search_path must match the actual architecture.

TRIGGERS

Triggers should enforce invariants, not hide complex application workflows.

Avoid triggers that:

perform external API calls
contain large workflows
create surprising side effects
duplicate application business logic
TRANSACTIONS

Operations that must be atomic belong in a transaction.

Especially:

payment state transitions
inventory changes
ownership changes
device assignment
webhook processing state
idempotency records
CONCURRENCY

Always consider concurrent execution.

Potential race conditions include:

duplicate webhook delivery
simultaneous payment updates
simultaneous device provisioning
simultaneous order creation
concurrent state transitions

Use appropriate:

unique constraints
row locking
atomic UPDATE statements
transactions
idempotency keys
MIGRATIONS

Migrations must be:

deterministic
repeatable where appropriate
dependency-safe
production-safe
ordered correctly

Do not depend on objects from later migrations.

CLEAN DATABASE EXECUTION

Every migration sequence must be capable of running from a clean database in the defined order.

Consider:

extensions
schemas
enums
tables
functions
triggers
policies
grants
seed data
SQL REVIEW CHECKLIST

Check:

syntax
dependency order
ownership
primary keys
foreign keys
constraints
indexes
RLS
SECURITY DEFINER
grants
search_path
concurrency
idempotency
performance
tenant isolation
migration compatibility
PERFORMANCE

Never optimize blindly.

For large datasets consider:

EXPLAIN
EXPLAIN ANALYZE
index selectivity
query cardinality
sequential scans
join strategy
row estimates
pagination strategy

Avoid OFFSET pagination for very large datasets where keyset pagination is appropriate.

SQL QUALITY STANDARD

SQL must be understandable by another senior PostgreSQL engineer.

Prefer explicitness over cleverness.