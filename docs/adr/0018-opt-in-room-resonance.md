# ADR 0018: Opt-in asynchronous room resonance

## Status

Accepted — 2026-08-15

## Context

Study Rooms already let members act at different times, but chat and progress
do not clearly communicate the product's distinctive promise of mutual support
without surveillance. Sharing detailed health values, exact focus minutes, or
a persistent recovery label would weaken privacy and could turn peers or room
owners into monitors. Free-text emotional disclosure also creates moderation
and safety obligations beyond the first POC.

## Decision

Each approved room member owns a per-room Room Resonance Preference that is
disabled until they explicitly opt in. When enabled, the member may publish
one current Resonance Signal selected from a fixed set of non-diagnostic cues.
The signal is visible only to approved members of that room and expires after
24 hours. Publishing a new signal replaces the member's prior current signal.
Disabling sharing or withdrawing immediately makes the current signal inactive.

Another approved member may send one fixed Support Acknowledgement for the
current signal generation. A member cannot acknowledge their own signal.
Neither a Room Owner nor a Group Manager receives additional authority.

All preference, publish, withdraw, and acknowledgement commands pass through
an App Check protected Cloud transaction with an idempotent client request ID.
Clients have read-only Firestore access according to the preference-owner and
approved-room-member boundaries. Signals contain no free text, Activity Ledger
records, precise health or activity values, personality diagnosis, ranking
fields, or reward effects.

Room Resonance records participate in privacy export and account deletion.

## Consequences

- App and Web expose the same current cue and acknowledgement count.
- A former room member immediately loses read access even if they remember an
  old signal or request ID.
- The feature supports asynchronous companionship without requiring a host to
  start or end an activity.
- The first POC cannot carry free-text emotional disclosures inside a signal;
  ordinary room chat remains a separate moderated interaction surface.
- Expired signals may remain as inactive retained records until lifecycle
  cleanup, but clients never present them as current.
