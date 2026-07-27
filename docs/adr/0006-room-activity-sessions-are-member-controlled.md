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

Messages and room events are canonical append-only records at
`rooms/{roomId}/messages/{messageId}` and
`rooms/{roomId}/events/{eventId}`. Approved members may read them and may only
write records whose sender or actor is their own authenticated identity.

The owner controls room configuration, admission, and moderation. The member
controls when their own activity starts, pauses, resumes, completes, or is
cancelled. Health and assigned-device ingestion remain explicit sources and
must still preserve the actor identity.

An owner cannot leave while approved members remain. Ownership must first be
transferred explicitly in one atomic write that changes the room owner and the
old and new owner role projections together.

When the final owner closes a room, the parent is marked `closed` instead of
being deleted by the client. This keeps the interaction and activity audit
trail attached to a canonical parent; physical recursive deletion is reserved
for a trusted server cleanup process.

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
- App and Web use the same append-only room message and event history.
- Owner transfer is deliberate and atomic; the system never chooses a random
  successor when an owner leaves.
- Closing a room hides it from active App/Web surfaces without creating orphan
  subcollections.
