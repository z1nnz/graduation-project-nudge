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
- Before-images are included in the subject account's privacy export and are
  included in formal account-deletion cleanup by `actorUserId`.
- Account deletion refuses to start while the Relationship or Reward cutover
  fence is active, preventing privacy cleanup from deleting rollback evidence.

The isolated Firestore Emulator scenario performs apply, simulates a failed
runner before fence release, rolls the run back, and validates the restored
documents and run counters. It then applies again, tampers with the canonical
Memberships, and verifies rollback refusal:

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
