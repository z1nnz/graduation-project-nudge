# Relationship migration rollback acceptance — 2026-08-10

This record covers the local and isolated-emulator evidence for the formal
Family/Group Membership cutover rollback. It does not claim that production
data has been migrated.

## Verified in this slice

- `migrate:relationships:apply` creates private, run-owned before-images for
  each Membership upsert and each legacy user projection cleanup.
- `migrate:relationships:rollback` restores pre-existing Memberships, deletes
  Memberships created by the run, and restores only the user fields changed by
  migration.
- Unrelated user updates made after apply remain intact during rollback.
- A changed post-apply Membership makes rollback fail closed with the cutover
  fence still active and the migration run marked `rollback_failed`.
- Apply resume rejects drift in either an already-applied Membership or the
  touched user projection instead of replacing its immutable after-fingerprint.
- Captured/restored counters prevent a deleted before-image from being treated
  as a successful rollback.
- Before-images are included in the subject account's privacy export and are
  included in formal account-deletion cleanup by `actorUserId`.
- A shared transactional destructive-operation guard covers both acquisition
  orders: deletion cannot start during a cutover, and a Relationship or Reward
  cutover cannot start during an active deletion execution.
- Before-images use the explicit `until_fresh_install_acceptance` retention
  policy. Their audited post-acceptance purge remains an open production gate.

The isolated Firestore Emulator injects failures after deterministic apply and
rollback operation counts, resumes with new owner tokens, and validates the
restored documents and counters. It separately tampers with an applied
Membership and touched user projection, deletes rollback evidence, and starts
with an active deletion guard to verify every path fails closed:

```sh
firebase emulators:exec --project nudge-relationship-migration-test \
  --only firestore 'npm --prefix scripts run test:relationships:emulator'
```

The Cloud privacy export behavior is covered by:

```sh
node --test --test-name-pattern='relationship migration before-images' \
  functions/test/privacy_data_request_service.test.js
```

## Production gate still open

On an authenticated release machine, the operator must still run a production
dry-run, resolve every issue, apply the cutover, and run the dry-run again. The
rollback command is an emergency path for an active failed run, not a substitute
for the second clean dry-run or real-account App/Web context-switch acceptance.
The post-acceptance command is now implemented locally. It requires a
project/run-bound production acceptance manifest with successful real-account
E2E plus both iOS and Android fresh-install artifact hashes. Recording that
manifest and purging are separate, idempotent, audited operations; the purge is
resumable and verifies its atomic
`captured = privacyDeleted + purged` counters before release. Account deletion
records any earlier privacy removal without retaining the subject user ID:

```sh
npm --prefix scripts run record:production-acceptance -- \
  --manifest=/absolute/path/to/production-acceptance.json

npm --prefix scripts run migrate:relationships:purge-before-images -- \
  --run-id=RELATIONSHIP_MIGRATION_RUN_ID \
  --acceptance-evidence-id=ACCEPTANCE_EVIDENCE_ID
```

Use `production-acceptance-evidence.example.json` as the schema reference. The
commands have passed isolated Emulator acceptance but have not been run against
production; the retention gate therefore remains open.
