# ADR 0001: Firestore is the shared catalog and relationship authority

- Status: Accepted
- Date: 2026-07-27

## Context

Nudge has a Flutter App and a Web Dashboard. Character assets were previously
embedded as Base64 strings in `shop_items`, character-stage rules were inferred
independently by each surface, and group membership existed only as duplicated
fields on user documents. This made document-size failures, invalid group IDs,
and App/Web drift likely.

## Decision

1. A published Character Series is one `shop_items` document containing exactly
   three ordered stage records and explicit Codex, evolution, unlock, and shop
   eligibility fields.
2. Only Stage 1 is shop eligible. Stage 2 and Stage 3 have no direct coin price
   and reference their preceding stage.
3. Binary catalog assets live in Firebase Storage. Firestore stores download
   URLs and metadata only.
4. `groups/{groupId}` is the canonical Group record. The legacy user fields
   remain compatibility projections so existing App and Web views continue to
   work while both surfaces migrate.
5. Family Link and Group Request decisions are stored in their shared request
   collections and are readable and actionable by both participating accounts.

## Consequences

- Admin publication is atomic at the metadata level and rejected unless the
  full chain is valid.
- App catalog, shop, Codex, and evolution views derive from one contract.
- Existing group owners are migrated lazily into canonical Group records.
- Firebase Storage and Firestore rules must be deployed together with the code.
- Removing uploaded but unpublished assets after a failed publish remains an
  operational cleanup task and can later be automated with a server function.
