# ADR 0006: Room activity sessions are member-controlled

## Status

Accepted — 2026-07-27

## Context

Nudge Study Rooms support focus, sleep, exercise, steps, and custom
self-discipline activities. A room may have an owner who configures rules and
approves members, but participants do not necessarily perform an activity at
the same time. Treating the room owner as a session host would turn a
self-discipline space into a scheduled class and would allow one user to alter
another user's evidence.

The previous App model embedded every member, message, and event in the parent
room document. Member presence updates therefore rewrote shared room state.
The Web Dashboard did not expose a real participant room surface, so App and
Web could not continue the same activity record.

## Decision

The parent `rooms/{roomId}` document is room metadata. It names the owner,
configuration, lifecycle, visibility, and the IDs of participants.

Each participant has a canonical projection at
`rooms/{roomId}/members/{memberId}`. A participant may update their own
presence and progress. The room owner may update admission and role fields but
cannot fabricate that participant's activity.

Each bounded attempt is stored at
`rooms/{roomId}/activity_sessions/{sessionId}` with an actor, activity kind,
metric, source, state, and timestamps. Only the actor may create or transition
an App/Web session. Allowed transitions are:

```text
active -> paused -> active
active|paused -> completed|cancelled
completed|cancelled -> terminal
```

Metric progress cannot decrease. App and Web implement the same versioned
contract and listen to the same Firestore subcollection.

The owner controls room configuration, admission, and moderation. The member
controls when their own activity starts, pauses, resumes, completes, or is
cancelled. Health and assigned-device ingestion remain explicit sources and
must still preserve the actor identity.

## Consequences

- Members can work asynchronously in one room without a host starting or
  ending everyone.
- App and Web show the same active session and cannot overwrite another
  member's session.
- Firestore rules can enforce identity and transition invariants at the write
  boundary.
- Legacy room documents that embed `members`, `messages`, `events`, or a
  plaintext password require a separate migration. New canonical writes do
  not depend on those embedded fields.
- Room chat and event history should be moved to dedicated subcollections
  before they are treated as cross-device canonical data.
