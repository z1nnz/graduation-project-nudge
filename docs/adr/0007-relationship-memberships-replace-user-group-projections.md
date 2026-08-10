# ADR 0007: Relationship Memberships replace single-group user projections

- Status: Accepted
- Date: 2026-07-29

Nudge represents every family and group role with
`relationship_memberships/{scopeType}--{scopeId}--{userId}`. App and Web may
select one active relationship as the current context, but selection does not
overwrite another Membership or change the account into a mutually exclusive
role.

New App and Web relationship mutations no longer write `users.groupId`,
`users.groupName`, `users.isGroupOwner`, or force `users.userRole` to `group`.
Firestore Rules reject clients that try to recreate these fields. The
query-friendly `family_links.participantIds` and `groups.memberIds` arrays
remain during this phase because App/Web collection-group discovery and current
Rules still use them as parent indexes; they are not the role authority.

Before deployment, run the migration from `scripts/`:

```text
npm run migrate:relationships
npm run migrate:relationships:apply
npm run migrate:relationships:rollback
```

The first command is read-only. It reports malformed parent relationships,
planned Membership upserts, and users with legacy projections. The apply
command refuses to continue while issues exist; successful, failed,
rolling-back and rolled-back runs are
recorded in `migration_runs`. It preserves existing Membership
creation/activation audit
timestamps, removes only the retired group and guardian-invite projection
fields, and leaves unrelated `webToolsState` content intact.

Every applied Membership and user cleanup transaction first writes one private,
run-owned `relationship_migration_before_images` record. If a cutover fails and
cannot safely resume, rollback atomically restores pre-existing Memberships,
deletes Memberships created by that run, and restores only the user fields the
migration touched. It verifies the post-apply fingerprint before every restore,
so an operator must resolve later changes instead of overwriting them. The
rollback keeps the fence active on any mismatch and is safe to resume under a
new owner token. Apply resume never replaces an existing before-image: it skips
an already-applied entity only when the current fingerprint still equals the
immutable post-apply fingerprint. Captured and restored before-image counters
are updated in the same transactions as their records, so missing evidence
cannot be mistaken for a completed rollback.

Relationship and Reward cutovers share
`system_state/destructive_operation_guard` with formal account deletion. The
shared document is claimed and checked transactionally in both directions, so
neither a cutover nor deletion can start after the other has acquired the
guard. Relationship before-images carry the explicit retention policy
`until_fresh_install_acceptance`; there is deliberately no time-based TTL that
could destroy rollback evidence before production acceptance. Their audited
purge requires an immutable `production_acceptance_evidence` record bound to
the Firebase project and migration run. The record must carry artifact hashes
for production real-account E2E plus iOS and Android fresh installs and must be
timestamped after migration completion by an authorized release staff account;
each migration run binds exactly one acceptance evidence ID. Purge claims the
shared destructive guard, is resumable by counted progress, and writes one
immutable audit before releasing the guard; it must not run while a cutover
fence is active. Privacy account deletion atomically replaces each removed
before-image with server-only operational evidence and increments the migration
run's privacy-deleted count. Final purge reconciliation requires the canonical
captured total to equal privacy-deleted plus purge-deleted evidence.

Legacy projection reads and lazy repair remain temporarily so an older account
can be recovered before the one-time production migration. They must be removed
only after migration metrics show no unresolved records and the fresh-install
acceptance suite passes against real accounts.
