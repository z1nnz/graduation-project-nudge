# ADR 0011: Cloud-audited catalog management

## Status

Accepted — 2026-07-29.

## Context

The Web admin surface previously uploaded media to Firebase Storage and then
wrote `shop_items` and `catalog_counters` directly from the browser. Firestore
Rules checked the staff role, but a staff client could bypass the form's
three-stage evolution-chain validation, publish later evolution stages as shop
items, reuse catalog indexes, or change catalog state without an immutable
operation record.

The App treats `shop_items` as the shared source for its shop and dynamic
character codex. Invalid or conflicting documents therefore affect both the
Web and App experiences.

## Decision

All catalog creates, full updates, and archives go through the App Check
protected `manageCatalogItem` callable:

- the callable authenticates the user and reads the same staff roles used by
  Firestore Rules;
- requests carry a stable `clientRequestId` and are idempotent;
- avatar series must contain exactly three stages with strictly increasing
  level and experience requirements;
- Cloud always makes stage 1 the only shop-eligible stage and makes stages 2
  and 3 evolution-only;
- Cloud allocates collision-free catalog indexes transactionally, considering
  both the counter and existing series;
- catalog mutation and immutable `audit_events` creation happen in one
  transaction;
- removal is represented by `status: archived`, preserving catalog history;
- client writes to `shop_items` and `catalog_counters` are denied.

Storage uploads remain a separate operation because Firebase Storage and
Firestore cannot share a transaction. A failed catalog command can therefore
leave an unreferenced upload; a later maintenance job may safely remove such
objects after a retention window.

## Consequences

The App and Web continue reading the same published catalog documents, but
browser code can no longer create structurally invalid character chains.
Operational changes are attributable and replay-safe. Deploying the callable
and Firestore Rules must be coordinated: deploy the function before the Rules
that disable direct writes.
