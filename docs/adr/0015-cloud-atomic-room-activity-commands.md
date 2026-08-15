# ADR 0015: Cloud-atomic room activity commands

## Status

Accepted — 2026-08-09

Supersedes the direct App/Web write path described in ADR 0006. The
member-controlled lifecycle defined there remains in force. ADR 0016
supersedes the client-observation part of this decision.

## Context

An Activity Session has two durable representations: immutable Activity Ledger
evidence and the current room projection at
`rooms/{roomId}/activity_sessions/{sessionId}`. App and Web previously wrote
these separately. A network or permission failure between the writes could
leave a Ledger event without its matching room state, or make a client report
failure after the canonical activity had already been accepted.

## Decision

App and Web submit each room start or transition as one authenticated
`recordActivity` Cloud command. The evidence contains the complete versioned
`roomSession` projection. Cloud validates that:

- the caller is the session actor and an approved, active room member;
- the room, actor, session, activity, metric, source, status, and timestamps
  agree with the Activity Ledger evidence;
- the session source remains its original evidence source when another surface
  continues it; the submitting UI is not allowed to rewrite provenance;
- the Activity correlation ID is the room session ID; and
- the transition preserves the member-controlled lifecycle from ADR 0006.

Cloud writes the Activity Ledger event or settlement, the room Activity
Session, and the member's `activeSessionId` in the same Firestore transaction.
App and Web clients cannot write room Activity Sessions or the active-session
pointer directly. They update user-visible local state only after Cloud accepts
the command. The current user-visible Session source is defined by ADR 0016.

Room activity-feed events are non-canonical presentation records. A failure to
append one after an accepted Cloud command is logged but does not turn the
accepted activity into a user-visible failure.

Guest-only local rooms remain local demonstrations and do not claim Cloud
acceptance.

## Consequences

- App, Web, Ledger, and room projections cannot split during a signed-in room
  transition.
- Offline signed-in room transitions wait for Cloud instead of showing an
  unaccepted state.
- Firestore Rules deny direct client writes to canonical Activity Sessions and
  active-session pointers.
- Health and assigned-device room ingestion must use the same trusted Cloud
  boundary before it can project room state.
- Activity-feed delivery may be retried independently because it is not the
  source of activity truth.
