# Avatar progress key migration — preflight only

## Current status

The planner is implemented and unit-tested. Production has NOT been read,
modified, migrated or accepted. `readyForApply` is deliberately always false.
PR #66 must remain draft until the execution and recovery gates below exist.

## Dry run

Use a privately stored export with `catalogs` and `users` arrays. Each element
has `{id, data}`. Include archived catalog series too; they can own old progress.
Do not commit exports or output: both may contain private account history.

```sh
node scripts/avatar_progress_migration_plan.mjs /absolute/private/export.json
```

The result records issues, exact before/after projections and a before-image
fingerprint. Ambiguous names, collisions with built-ins, mixed old/new keys and
invalid amounts fail closed for that user. No XP is added, awarded or copied to
multiple series. Immutable historical receipts remain untouched.

Unknown ledger keys or equipped series are also rejected for that user; they
may represent renamed or omitted historical catalogs. Existing built-in names
and catalog stable keys are accepted unchanged. An operator must supply the
missing historical catalog identity or a separately reviewed, evidenced
mapping before planning a migration. The planner never guesses from an image
or a current display name.

## Unknown-identity preflight slice (2026-11-23)

The planner now emits `unknown_series_identity` and omits that user's update
when a ledger key or equipped series is absent from the historical catalog,
stable keys, and built-in names. The unit test covers an unknown ledger key,
an unknown equipped series, a mixed known/unknown ledger, and unchanged known
keys. It remains a pure dry run; apply and rollback are still unavailable.

On Windows 11 with Flutter 3.41.7, Node 22.23.3 and Java 17: targeted planner
tests 3/3 passed; targeted Flutter avatar tests 14/14 passed; targeted admin
catalog and planner Node tests 7/7 passed. `flutter analyze` found no issues;
`node --test test/*.js` passed 119/119 with 0 skipped;
`npm --prefix functions test` passed 122 with
25 skipped (not a complete pass). `flutter test --reporter expanded` exited 1:
209 passed and 4 failed: study-room message persistence, weekly/monthly coin
caps, durable task mutation, and Firebase-bootstrap source matching. The
changed slice is JavaScript planner code and its test; these Flutter
failures are outside its changed files. At this first run, Java 17 was below
CI's Java 21 Rules gate, so no local emulator pass was claimed. No production
data was read or written.

## Java 21 emulator follow-up (2026-11-23)

This Windows terminal still defaulted to Java 17. For this run, `JAVA_HOME`
and `PATH` were set for the process to `D:/DevTools/jdk-21`; `java -version`
reported Temurin 21.0.13.1. Firebase CLI 15.18.0 was invoked through
`npm exec --yes --package=firebase-tools@15.18.0 -- firebase`, matching the
CI pin. `gh` 2.105.0 was available; the previous PR head `e54b0eb` had all
six GitHub check runs completed successfully.

The `.github/workflows/ci.yml` Rules/transaction command was run locally with
`firebase emulators:exec --only auth,firestore --project nudge-discipline-app`.
It executed all five `test/firestore_*_rules_test.js` files, both named Cloud
transaction test files, and the relationship and reward migration emulator
scripts. The command exited 0. The four Node TAP groups reported 5/5, 6/6,
5/5 and 1/1 passed, each with 0 failures and 0 skipped; each of the five
individual Rules scripts exited 0. These are local emulator results, not a
production migration or a real-account acceptance test.

The full `npm --prefix functions test` suite was also run under Auth, Firestore
and Storage emulators: 147 total, 142 passed, 0 failed, 5 skipped. The five
skipped tests require real authenticated accounts and App Check for catalog,
privacy, push and relationship flows; they remain unverified. The original
25-skipped run outside emulators is retained above as its actual result.

## Required apply gate (not yet implemented)

1. Inventory all users and all historical catalog identities; resolve each issue
   explicitly. A renamed legacy series requires an evidenced mapping; do not
   infer it from the current name or avatar image.
2. Pause reward/equipment writes using the owned cutover protocol and coordinate
   account-deletion fences. Re-read each user inside a transaction.
3. Verify before-image fingerprints; store private recovery evidence and update
   only the targeted progress fields. Preserve absent-field state.
4. Ensure replay does not migrate twice. Do not rewrite immutable receipts;
   preserve an auditable mapping for historical reconciliation.
5. Re-run inventory and compare per-user/per-day XP totals before unpausing.

## Required rollback (not yet implemented)

While the cutover remains fenced, restore only stored before-images whose
post-apply fingerprints still match. Preserve unrelated user fields. Fail closed
if data or recovery evidence changed; never use a blind whole-document restore.
Do not deploy the new progress-key semantics before this apply/rollback path is
tested against the emulator and the production dry-run is reviewed.
