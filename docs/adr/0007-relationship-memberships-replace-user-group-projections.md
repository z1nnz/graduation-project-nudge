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
new owner token.

Legacy projection reads and lazy repair remain temporarily so an older account
can be recovered before the one-time production migration. They must be removed
only after migration metrics show no unresolved records and the fresh-install
acceptance suite passes against real accounts.
