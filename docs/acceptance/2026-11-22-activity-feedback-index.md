# Activity feedback index and access acceptance

## Scope

Only the activity_receipts(actorUserId ASC, verifiedAt DESC) production index
is being created. No Rules, Cloud Functions, user documents or reward ledgers
are deployed or mutated by this index operation.

## Verified

- Project: nudge-discipline-app, database: (default).
- Existing indexes were listed read-only before the operation; the receipt
  index did not exist.
- Creation requested with the explicit collection and field order through
  gcloud, not a full firebase index deployment. No index deletion requested.
- Index identifier: CICAgJjmiJEK. Initial response was INITIALIZING.
- Subsequent read-only listing returned CREATING; readiness is not yet accepted.
- Final read-only listing on 2026-11-22 confirmed state READY for CICAgJjmiJEK.
  The index readiness gate is now satisfied; this is not client-release acceptance.
- Emulator query acceptance covers own-account latest receipt ordering,
  foreign-account query denial and Cloud-only mutations. The test is included
  in the existing CI loop `test/firestore_*_rules_test.js`.
- The loopback Auth/Firestore emulator run passed, including unauthenticated
  read denial and owner creation/update/delete rejection.

## Still pending

- Complete final review/CI of the strengthened emulator acceptance test.
- New client build/release and two real-account UI acceptance.
- Physical-device acceptance is unrelated and remains separate.

## Recovery

Revert or withhold the read-only UI if acceptance fails. Retain the unused
index safely; deleting user receipts is neither required nor authorized.
