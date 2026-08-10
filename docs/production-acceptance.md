# Nudge production acceptance

This runbook separates deployed production evidence from local/emulator
coverage and from release gates that still require external infrastructure.

The latest dated execution record is
[`acceptance/2026-08-10-relationship-migration-rollback-status.md`](acceptance/2026-08-10-relationship-migration-rollback-status.md).

## Current verified state

- GitHub Pages publishes `web_dashboard/` through
  `.github/workflows/pages.yml`. The repository Pages source must remain
  `workflow`, not `legacy`.
- The deployed dashboard generates `assets/runtime-config.js` from the public
  `NUDGE_FIREBASE_APP_CHECK_SITE_KEY` repository variable.
- The Web dashboard and Flutter Web use the reCAPTCHA Enterprise App Check
  provider. The reCAPTCHA key is restricted to the deployed GitHub Pages
  domain.
- Flutter initializes Firebase with
  `DefaultFirebaseOptions.currentPlatform` before App Check activation. A
  release Web build is not accepted if it falls back to native-only
  configuration files.
- `firebaseappcheck.googleapis.com` and
  `recaptchaenterprise.googleapis.com` must both be enabled. Registering the
  provider alone is not sufficient.
- The registered Android app has a Play Integrity configuration. The
  registered iOS app has App Attest and DeviceCheck configurations, and its
  Firebase Apple Team ID is `MTKYU5J45P`.
- Firestore Rules and indexes are deployed separately from Functions and
  Storage, so a billing failure cannot hide their release state.
- The relationship cutover is accepted only after a production dry-run reports
  zero issues, the apply completes, and a second dry-run reports zero legacy
  projection cleanup. App and Web authorize relationship context, role-specific
  UI and context switching from active `relationship_memberships`; parent
  participant/member arrays are only the parent-data query bridge.
- App and Web task completion now have local test coverage for actor-bound,
  durable Activity Ledger submission before projection updates. Task receipts
  are non-rewardable, atomically update the canonical task projection, and
  support ordered immutable corrections across clients. Older offline evidence
  is retained as superseded audit data instead of replacing the latest state.
  This is source and test evidence only until the updated Cloud Function is
  deployed and exercised with real accounts.

## Relationship Membership cutover

The migration fails closed on invalid parents and validates the cutover owner,
the current parent fingerprint, the existing Membership fingerprint, and the
legacy user projection in each transaction. A failed partial run keeps its
runner fence active and is safe to resume; a later runner atomically takes
ownership so the earlier process cannot release the fence or continue writing.

```sh
npm --prefix scripts run migrate:relationships
npm --prefix scripts run migrate:relationships:apply
npm --prefix scripts run migrate:relationships
```

The isolated Firestore Emulator acceptance is:

```sh
firebase emulators:exec --project nudge-relationship-migration-test \
  --only firestore 'npm --prefix scripts run test:relationships:emulator'
```

If apply fails and cannot safely resume, keep the active fence in place and
run:

```sh
npm --prefix scripts run migrate:relationships:rollback
```

Rollback accepts only an active cutover run. It claims the run with a new
owner token, verifies every applied Membership or user projection against its
before-image fingerprint, restores only unchanged migration-owned fields, and
releases the fence only after no before-images remain and the atomically
captured/restored counters match. A mismatch records
`rollback_failed` and deliberately leaves the fence active. Relationship
before-images participate in privacy export and account deletion by
`actorUserId`; they are not client-readable application state. Account
deletion and both cutovers transactionally claim the shared
`system_state/destructive_operation_guard`, covering either acquisition order
so privacy cleanup cannot remove evidence required by an in-progress rollback.
Before-images are retained under `until_fresh_install_acceptance`, with no TTL
before acceptance. After the production migration, real-account E2E, and both
fresh-install artifacts are accepted, prepare the versioned manifest described
by
[`acceptance/production-acceptance-evidence.example.json`](acceptance/production-acceptance-evidence.example.json),
then run:

```sh
npm --prefix scripts run record:production-acceptance -- \
  --manifest=/absolute/path/to/production-acceptance.json
npm --prefix scripts run migrate:relationships:purge-before-images -- \
  --run-id=RELATIONSHIP_MIGRATION_RUN_ID \
  --acceptance-evidence-id=ACCEPTANCE_EVIDENCE_ID
```

The first command immutably records a project/run-bound acceptance document and
audit; `acceptedBy` must resolve to an existing Firebase user with
`developerAccess` or the `developer`, `operator`, or `admin` staff role. One
migration run can bind only one acceptance evidence ID, and evidence timestamped
before migration completion or in the future is rejected. The second
claims the shared destructive-operation guard, supports restart after partial
deletion, and verifies `captured = privacyDeleted + purged` before writing one
immutable purge audit and releasing the guard. If an accepted account-deletion
request removes a user's rollback evidence first, that removal and a
non-identifying operational evidence record are committed atomically so the
later purge can reconcile the canonical captured total. Both commands are
locally Emulator-verified but
must still be exercised in production before the retention gate is closed.

- Activity rewards and shop debits now use Cloud-owned
  `reward_ledger_entries`. A normal App/Web timer completion is rewardable only
  after an accepted start event and a plausible Cloud-observed elapsed
  duration. User-submitted steps and sleep are rejected, and normal reward caps
  use the Cloud settlement date rather than a client-backdated date. Shop prices,
  balances, idempotency, and the stage-one-only rule for complete three-stage
  avatar series are transactionally checked by Cloud. Equipping a paid or
  evolved character also requires a Cloud command that verifies ownership and
  series XP. Firestore Rules reject direct client writes to coin, XP, level,
  unlock, and equipped-avatar projections. This remains
  source/test evidence until Functions and Rules are deployed, legacy reward
  projections are baselined, and real accounts exercise both settlement and
  purchase callables.

Before enabling the Cloud-owned reward fields, run the baseline dry-run,
resolve every issue, apply once, and run the dry-run again. Apply creates a
server-side fence checked by reward settlement, purchase, and equipment
callables; every user write has a transaction precondition and a private
before-image. Each apply/rollback runner owns the fence with a unique token;
every transaction rechecks that token before writing or releasing the fence.
The second dry-run must report zero `baselineCreates` and zero issues:

```sh
npm --prefix scripts run migrate:rewards
npm --prefix scripts run migrate:rewards:apply
npm --prefix scripts run migrate:rewards
```

The local apply/rollback acceptance runs against an isolated Firestore
Emulator project:

```sh
firebase emulators:exec --project nudge-reward-migration-test --only firestore \
  'npm --prefix scripts run test:rewards:emulator'
```

If apply fails and cannot safely resume, keep the fence active while running:

```sh
npm --prefix scripts run migrate:rewards:rollback
```

## Real-account Auth and Rules acceptance

`scripts/production_real_account_e2e.mjs` creates two short-lived Firebase
Auth accounts and exercises production Firestore Rules plus the deployed,
App-Check-protected Cloud authority path. It verifies:

1. both accounts can create only their own private profile;
2. a cross-account profile overwrite is denied;
3. privacy consent is written by Cloud with the current policy and an owner-
   readable immutable audit event;
4. the account-deletion privacy workflow enters its cooling period, is safely
   cancelled by the account owner, and produces both immutable audit events;
5. notification preferences are written by Cloud with the complete channel
   contract and an immutable audit event;
6. one zero-reward focus lifecycle is accepted and settled by the formal
   Activity Ledger without minting a reward;
7. a manager atomically creates a group and manager Membership;
8. a non-member cannot perform a manager action;
9. a manager can issue a group invitation, the Cloud trigger creates the
   recipient notification, and marking it read creates an audit event;
10. the member atomically accepts the invitation, joins the group, creates the
   member Membership, and the inviter receives the terminal status
   notification;
11. the member and manager receive the intended Membership visibility;
12. Cloud generates a Membership-bound group planet and character outcome;
13. the same two accounts concurrently hold group manager/member and family
    guardian/child Memberships without either backend role replacing the
    other; App/Web context-selector behavior remains covered by the separate
    surface contract tests until signed-device/browser acceptance can run;
14. a guardian creates a family invitation, the child accepts it atomically
    with both scoped Memberships, and both invitation outcomes are notified and
    audited;
15. child-only acknowledgement and shared-goal decisions reject guardian
    impersonation, then create the validated Family Bond events;
16. Cloud generates a Membership-bound family tree, family companion and both
    deterministic shared-memory projections;
17. ending the family link updates the parent, request and both Membership
    lifecycles atomically;
18. leaving and group closure update the parent document and Membership
    lifecycle atomically;
19. an ordinary account cannot read another user's audit event, while a
    synthetic operator granted through the administrator channel can;
20. all Ledger, privacy, notification, outcome, family, group, Membership,
    shared-memory and audit documents created by the run are deleted through
    de-duplicated atomic commits and verified absent before Auth cleanup; and
21. both Auth accounts are deleted and their credentials no
    longer sign in.

Run it only with a short-lived administrator OAuth access token that can clean
up the synthetic documents and a short-lived App Check JWT issued for this
Firebase project:

```sh
NUDGE_FIREBASE_PROJECT_ID=nudge-discipline-app \
NUDGE_FIREBASE_WEB_API_KEY='<public Firebase Web API key>' \
NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN='<short-lived OAuth token>' \
NUDGE_FIREBASE_APP_CHECK_TOKEN='<short-lived App Check JWT>' \
NUDGE_GOOGLE_QUOTA_PROJECT=nudge-discipline-app \
npm --prefix scripts run e2e:production:accounts
```

On an authorized release workstation with `gcloud` and ADC already configured,
the preferred command creates a UUID4 App Check debug token, exchanges it for
one short-lived JWT, runs the same E2E, and revokes the debug token in `finally`:

```sh
npm --prefix scripts run e2e:production:accounts:ephemeral
```

Set `NUDGE_GCLOUD_BIN=/absolute/path/to/gcloud` only when the CLI is not on
`PATH`. The operator must have permission to create and delete App Check debug
tokens. The wrapper keeps the administrator, App Check, account and password
credentials in process memory and prints only the redacted E2E result plus the
debug-token revocation status.

Never commit, print, or persist either token. The script does not print account
email addresses, passwords, ID tokens, the administrator token, or the App
Check token. A successful source-level test of this script is not production
acceptance; the JSON result from an actual run must report every step as
`passed` and `cleanup` as `completed`.

## External release gates

- Cloud Functions deployment requires the Firebase Blaze plan because the
  deployment must enable Artifact Registry.
- Provisioning a new default Cloud Storage for Firebase bucket also requires
  the Blaze plan. Storage Rules cannot be released until that bucket exists.
- Functions and Storage/App Check enforcement should be enabled only after the
  deployed clients and real-account callable tests pass.
- The Android package name and Apple bundle ID are still
  `com.example.nudge`. A production identifier must be selected before store
  release. Firebase package and bundle identifiers are immutable, so this
  requires registering replacement Firebase mobile apps and regenerating the
  platform configuration rather than editing only the local project.
- Android fresh-install acceptance requires an Android SDK and device or
  emulator.
- Apple App Attest acceptance requires a signed build on a real Apple device;
  a simulator build cannot prove App Attest.
- Push delivery needs a real device token and delivery receipt.

## 2026-07-30 mobile build evidence

- The iOS lockfile initially mixed Firebase Apple SDK 12.12 with FlutterFire
  plugins that require 12.15. CocoaPods successfully re-resolved the local
  dependency graph to Firebase 12.15, including Functions and Messaging.
- A release-mode iOS Simulator build is not supported by Flutter. This is a
  platform limitation and is not release acceptance.
- A clean debug Simulator build passed dependency resolution and entered Xcode
  compilation, but the machine ran out of disk space before producing
  `Runner.app`. The failed build was cleaned with Flutter and Xcode commands;
  no fresh install was accepted from this attempt.
- The App Check provider registrations and Apple Team ID are backend
  configuration evidence only. They do not replace a signed real-device token
  exchange.

Do not describe any of these gates as passed based only on unit tests,
emulators, a Web build, or provider registration.
