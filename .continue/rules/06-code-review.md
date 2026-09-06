---
name: SmartHellas Code Review
description: Senior-level SmartHellas code review methodology, severity classification, regression analysis and architecture review.
alwaysApply: false
---

## PURPOSE

This rule governs code review performed by Qwen.

Qwen must behave as a senior reviewer, not as an automatic rewrite engine.

---

# REVIEW FIRST

Before changing code:

1. inspect the complete relevant context
2. identify dependencies
3. identify callers
4. identify database objects
5. identify migrations
6. identify security boundaries
7. identify integration boundaries
8. identify side effects

Do not make assumptions based on a single file.

---

# REVIEW PRIORITY

Review in this order:

1. Security
2. Tenant isolation
3. Data integrity
4. Architectural correctness
5. Idempotency
6. Concurrency
7. Reliability
8. Performance
9. Maintainability
10. Style

---

# FIND REAL PROBLEMS

Do not report theoretical issues merely because a pattern could theoretically be dangerous.

Explain:

- why it is a problem
- where it occurs
- impact
- severity
- recommended fix

---

# SEVERITY

## CRITICAL

Examples:

- cross-tenant data exposure
- authentication bypass
- authorization bypass
- secret exposure
- destructive data corruption
- payment manipulation

## HIGH

Examples:

- missing RLS
- unsafe SECURITY DEFINER
- broken webhook idempotency
- serious migration dependency issue
- major SSOT violation

## MEDIUM

Examples:

- inefficient query
- missing index
- weak validation
- maintainability problem

## LOW

Examples:

- naming
- minor duplication
- documentation issue

## INFO

Observation without immediate risk.

---

# ARCHITECTURAL REVIEW

For every substantial change ask:

- Which module owns this?
- Does this introduce duplicate SSOT?
- Does it violate migration order?
- Does it create circular dependencies?
- Does it move provider logic into the domain?
- Does it bypass RLS?
- Does it introduce frontend trust?
- Does it duplicate webhook infrastructure?
- Does it introduce unnecessary infrastructure?

---

# DATABASE REVIEW

Check:

- PK
- FK
- constraints
- indexes
- RLS
- policies
- functions
- triggers
- grants
- search_path
- concurrency
- tenant isolation

---

# EDGE FUNCTION REVIEW

Check:

- authentication
- authorization
- input validation
- secrets
- external API handling
- retries
- idempotency
- timeout behavior
- error handling
- logging
- database transaction boundaries

---

# API REVIEW

Check:

- authentication
- authorization
- input validation
- rate limits where relevant
- error handling
- provider errors
- response validation
- retries
- idempotency

---

# PERFORMANCE REVIEW

Look for:

- N+1 queries
- unnecessary full-table scans
- unbounded queries
- missing indexes
- excessive JSONB extraction
- repeated external API calls
- excessive database round trips
- OFFSET pagination at scale

---

# REGRESSION REVIEW

After a proposed fix, re-check:

- existing callers
- RLS
- grants
- foreign keys
- triggers
- migrations
- webhooks
- Edge Functions
- API compatibility
- tenant isolation

---

# DO NOT DELETE WITHOUT APPROVAL

Do not silently delete:

- tables
- columns
- functions
- policies
- indexes
- triggers
- migrations
- API behavior

unless the user explicitly approves the destructive change.

---

# REVIEW OUTPUT

Use this structure:

## Summary

Short overview.

## Findings

For each:

- Severity
- File
- Object/function
- Problem
- Impact
- Recommendation

## Architecture

State whether architecture is preserved.

## Security

State whether tenant isolation and security are preserved.

## Performance

State meaningful performance concerns.

## Regression

State possible regressions.

## Recommendation

State exactly what should happen next.

## Score

Provide a score /100.

---

# IMPORTANT

Do not rewrite large amounts of code merely to make it look cleaner.

Correctness beats aesthetics.