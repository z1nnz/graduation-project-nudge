# ADR 0016: Canonical Ledger sessions drive room UI

## Status

Accepted — 2026-08-15

Refines ADR 0015 and supersedes its client-observation decision. The
Cloud-atomic room command boundary and member-controlled lifecycle remain in
force.

## Context

ADR 0015 made one `recordActivity` command write the Activity Ledger and the
room command aggregate atomically, but App and Web still rendered
`rooms/{roomId}/activity_sessions/{sessionId}`. That left two readable Session
representations and made a future client capable of silently returning to the
room aggregate instead of the canonical Activity Ledger.

## Decision

The user-visible Activity Session is the actor-owned document at
`activity_sessions/{activitySessionId}`. A room Ledger session carries its
`roomIds`, `roomTargetValue`, `source`, lifecycle timestamps and current metric.
App and Web query these documents by `actorUserId`, validate that the selected
room is present in `roomIds`, and convert the canonical Session to their shared
room presentation contract. Each presentation is keyed by the pair
`(roomId, activitySessionId)`, so one canonical activity may appear in multiple
eligible rooms without one room overwriting another. Health-backed rooms keep
the same Session listener even though their manual controls remain disabled.

Sessions created before this contract may not contain `roomTargetValue` or
`updatedAt`. During cutover, App and Web derive only those missing values from
the canonical Room goal and `startedAt`; an explicitly null or malformed value
still fails closed. The next accepted Cloud transition persists the complete
Session fields, providing lazy repair without reading the room-nested
aggregate.

`rooms/{roomId}/activity_sessions/{sessionId}` remains a Cloud-only
transactional aggregate used to validate room commands and atomically maintain
the Room Membership `activeSessionId`. It is neither a UI read model nor a
client API. Firestore Rules deny all client reads and writes to it.

Room Contributions remain the approved-participant view of verified peer
progress. Room messages, events and memberships keep their existing scoped
read rules.

## Consequences

- App and Web resume the same room activity from the same canonical Ledger
  Session.
- A signed-in client cannot accidentally use the Cloud command aggregate as a
  competing source of truth.
- The top-level actor query does not disclose another member's private Session;
  peers see only the Room Contribution fields allowed by membership rules.
- Cloud account deletion, audit and transactions may still access both
  representations through the Admin SDK.
