---
name: SmartHellas Complete SQL Output
alwaysApply: true
description: Whenever SQL is modified, always return the complete migration instead of a diff or partial SQL.
---

## PURPOSE

This is a strict output rule for all SQL migration work.

---

# COMPLETE SQL ONLY

Whenever SQL is updated, changed, corrected or regenerated:

ALWAYS output the ENTIRE SQL migration again.

Never output only:

- a diff
- a patch
- changed lines
- ALTER statements without context
- "replace this section"
- "add the following"

The complete migration must be returned.

---

# EXAMPLE

If changing:

`007_integration_engine.sql`

the output must be the complete:

`007_integration_engine.sql`

from first line to last line.

---

# DO NOT OUTPUT

Do not say:

"Keep the rest unchanged."

Do not say:

"Replace section X."

Do not provide only:

ALTER TABLE ...
when the requested artifact is the full migration.

SQL FILE HEADER

When generating a migration, clearly identify:

-- ============================================================
-- SmartHellas
-- Migration: XXX
-- Module: ...
-- Purpose: ...
-- ============================================================
MIGRATION ORDER

Respect:

000
001
002
003
004
005
006
007
008
009
010
011
012
013
014
015
016
017
018
019
020
021

CLEAN EXECUTION

The complete SQL must work against the expected clean migration state.

Check:

referenced schemas
referenced tables
referenced columns
referenced functions
referenced enums
grants
policies
triggers
dependencies
NO LATER DEPENDENCIES

Do not reference objects from a later migration.

If unavoidable, stop and report the dependency problem rather than silently changing migration order.

IDEMPOTENCY

Where appropriate use safe migration patterns such as:

CREATE TABLE IF NOT EXISTS

or:

CREATE INDEX IF NOT EXISTS

But do not blindly use IF NOT EXISTS everywhere.

Migration semantics must remain clear.

DESTRUCTIVE CHANGES

Before generating destructive SQL involving:

DROP TABLE
DROP COLUMN
DROP FUNCTION
data deletion
constraint removal

ensure explicit approval exists.

RLS

If tables are tenant-scoped, inspect:

ENABLE ROW LEVEL SECURITY
policies
USING
WITH CHECK
grants

Do not assume RLS exists merely because the table is tenant-scoped.

SECURITY DEFINER

Every SECURITY DEFINER function must be reviewed for:

search_path
authorization
tenant isolation
EXECUTE privileges
SQL injection
INDEXES

Every new index must have a purpose.

Explain why it exists when presenting the migration.

SQL VALIDATION

Before presenting final SQL, mentally validate:

syntax
dependencies
object names
migration order
foreign keys
constraints
functions
triggers
policies
grants
RLS
security
concurrency
performance
OUTPUT FORMAT

When asked for SQL:

Brief explanation
Complete SQL migration
Short validation checklist

Never provide a partial migration when a complete migration is requested.