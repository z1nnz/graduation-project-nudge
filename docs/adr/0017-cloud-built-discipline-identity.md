# ADR 0017: Cloud-built discipline identity snapshots

## Status

Accepted — 2026-08-15

## Context

Nudge needs a distinctive self-discipline reflection that can be shown
consistently in App and Web. Computing that reflection independently from
local task, focus, health, or room projections would let the two surfaces
disagree and would make local-only or stale data look canonical. Calling the
result a personality assessment would also overstate what recent activity can
support and could turn a recovery feature into a permanent label.

## Decision

Cloud derives one private `discipline_identity_snapshots/{userId}` document
from the authenticated user's completed canonical Activity Sessions. The
snapshot covers the most recent 28 discipline days, where a discipline day
uses the Asia/Taipei 05:00 boundary. App and Web may request a refresh and read
their own snapshot, but cannot write it.

The snapshot is a changeable reflection of recent evidence, not a personality
diagnosis. It exposes the evidence window and aggregate metrics used for the
result. Its recovery state recommends one small next action after a gap; it
does not erase history, impose a make-up burden, or issue a penalty.

The first release keeps every snapshot private. Later optional sharing must be
an explicit, revocable consent decision and must publish a bounded projection
instead of exposing the private snapshot directly.

Discipline identity snapshots participate in the formal privacy lifecycle:
they are included in owner data exports and deleted during account deletion.

## Consequences

- App and Web render the same canonical identity and recovery state.
- A client cannot manufacture a more favorable identity from local data.
- More than 500 matching sessions fails closed rather than publishing a
  silently truncated result.
- Refresh requires the Activity Session composite index and current Cloud
  availability.
- Optional social sharing remains a separate, consented projection and is not
  implied by this private snapshot.
