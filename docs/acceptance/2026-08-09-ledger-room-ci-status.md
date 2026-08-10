# Nudge Ledger, room and CI acceptance status — 2026-08-09

This record covers the current source branch only. It does not claim that Cloud
Functions, migrations, store builds, or real-device acceptance have been
completed in production.

## Accepted in source and local automated tests

- Signed-in Health ingestion updates App projections only after every supplied
  canonical snapshot is accepted by Cloud. Rejected or retry-blocked batches
  preserve the previous user-visible state.
- Focus start, pause, completion, reset, and early-finish actions await their
  required Activity Ledger guarantee before projecting progress.
- Signed-in App and Web room starts and transitions use one Cloud Activity
  command. Cloud atomically writes Ledger evidence, the canonical room Activity
  Session, and the member active-session pointer.
- Firestore Rules deny direct client writes to canonical room Activity Sessions
  and active-session pointers. Approved members still control their own
  lifecycle through Cloud; room managers cannot fabricate member evidence.
- Cloud rejects a second concurrent active session, invalid lifecycle changes,
  immutable-field replacement, non-advancing timestamps, and decreasing room
  progress before it writes any projection.
- A session retains its original evidence source when a member continues it on
  another App/Web surface. A rejected room command restores the live timer and
  does not project resting/completed state.
- Health sync timestamps advance only after the full Cloud Ledger batch is
  accepted.
- Pull requests now have shared Flutter, Web, Cloud, and Firestore emulator
  checks, a CODEOWNERS default reviewer, and a contributor/PR checklist.
- Privacy export expiry tests generate a bounded future expiry instead of using
  a calendar date that eventually breaks CI.

## Local verification evidence

- Flutter Analyze: no issues.
- Flutter tests: 136 passed, 0 failed.
- Root Node/Web tests: 81 passed, 0 failed.
- Cloud Functions unit suite: 94 passed, 0 failed, 22 emulator-gated skips.
- Exact CI Firestore/Auth emulator suite passed all family, friend, group, and
  room Rules integrations plus 5 Activity Ledger transaction tests.
- `git diff --check` and CI workflow YAML parsing passed.

## Production gates still open

1. Upgrade the Firebase project to Blaze and deploy the changed Cloud Functions
   before releasing the Cloud-only room write rules to users.
2. Initialize Cloud Storage and deploy its rules.
3. Authenticate the release machine, run relationship and reward migration
   dry-runs, apply only clean migrations, then repeat the dry-runs.
4. Run the cleanup-safe real-account production E2E with short-lived Admin and
   App Check credentials.
5. Replace development bundle identifiers, create signed iOS and Android
   builds, and complete fresh-install tests on real devices.
6. Configure and activate the GitHub `main` ruleset after this CI workflow has
   produced its first successful pull-request run; require the four stable job
   names documented in `CONTRIBUTING.md`.

## Required release order

Deploy Cloud Functions first, verify `recordActivity`, run the real-account room
lifecycle check, then release Firestore Rules. Reversing that order would block
older App/Web clients before the only authorized room command is available.
