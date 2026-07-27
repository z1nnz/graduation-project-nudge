# ADR 0004: Group results are Member-controlled summaries

- Status: Accepted
- Date: 2026-07-27

Nudge stores a Member's shareable outcomes in
`groups/{groupId}/member_summaries/{memberId}` instead of letting Group
Managers query private `users` documents. The Member creates and refreshes this
compact snapshot, and revokes consent by deleting it; removal from the Group
deletes it atomically. Signed-in social lookup reads only the explicit
`public_profiles/{userId}` projection; `/users/{userId}` remains owner-readable
and contains the private task, health, family, and compatibility state. This
trades unrestricted administrative analytics for a verifiable consent boundary
shared by App and Web.

Before deploying the owner-only `/users` read rule to an existing environment,
run `node scripts/backfill_public_profiles.js` to inspect the migration count,
then run `node scripts/backfill_public_profiles.js --apply`. The first command
is deliberately read-only. New App and Web sessions maintain their own public
projection after the one-time backfill.
