# Nudge productization acceptance status — 2026-08-02

This record distinguishes source/test completion from deployed production
evidence. It must not be used to claim that the full production cutover is
complete.

## Accepted in source and automated tests

- Git commit `5522640182ee27683da21a8ac96365ee326e9395` is present on local
  `main` and `origin/main`.
- App, Web, Health Connect and member-controlled activity-room flows use the
  formal Activity Ledger client contracts and durable outboxes.
- Cloud Activity and Reward Ledger services, Cloud-only reward mutations,
  formal relationship Memberships, multi-relationship switching, role
  capabilities, family tree, group planet, shared memories, relationship
  character outcomes, privacy workflows, notification workflows and staff
  audit surfaces have automated coverage.
- 2026-08-02 regression results:
  - Functions: 112 tests, 91 passed and 21 emulator-gated skips.
  - Root Node/Web contracts: 79 passed, 0 failed.
  - Flutter: 124 passed, 0 failed.
  - Flutter Analyze: no issues.
  - Targeted Firestore Auth/Rules emulator checks passed for Activity Ledger,
    Reward migration, relationship migration, formal outcomes and privacy
    audit boundaries during this implementation sequence.

## Deployed and externally verified

- Firestore Rules compiled and were released to project
  `nudge-discipline-app` on 2026-08-02.
- Firestore indexes from `firestore.indexes.json` were deployed successfully.
- GitHub Pages workflow run `30748435226` completed successfully for commit
  `90aeb287a19065a2984d1cc41fda4af367da135f`.
- The live dashboard at
  `https://z1nnz.github.io/graduation-project-nudge/` serves the formal
  relationship-outcome contract and the matching App bundle.

## iOS fresh-install evidence

- Target: iPhone 16 simulator
  `B02A71DA-959B-49A7-BFB5-0D40666BB2CD`.
- Bundle ID used by the current development build: `com.example.nudge`.
- The old simulator installation was removed before the accepted run.
- The first generic simulator build exposed a HealthKit Swift compile bug.
  Commit `5522640` fixed the missing optional unwrap in both statistics-source
  paths and added a regression test.
- `flutter run -d B02A71DA-959B-49A7-BFB5-0D40666BB2CD --debug
  --no-resident` completed with exit code 0 after the fix.
- `simctl get_app_container` resolved a new `Nudge.app` container;
  `simctl launch --terminate-running-process` returned PID `67718`; and
  `launchctl list` showed the matching UIKit application process.
- A post-launch screenshot showed the first-run Nudge onboarding role-selection
  screen. This accepts a debug Simulator fresh install only. It does not prove
  App Attest, APNs delivery, HealthKit behavior on real hardware or App Store
  release signing.

## Production gates still open

1. **Cloud Functions:** deployment is blocked because the Firebase project is
   not on Blaze. `artifactregistry.googleapis.com` cannot be enabled on the
   current plan.
2. **Cloud Storage:** Storage has not been initialized for the project, so
   `storage.rules` cannot be released. Firebase also requires the relevant
   billing setup for a new default bucket.
3. **Production migrations:** relationship and Reward Ledger dry-runs cannot
   authenticate from the Admin SDK on this Mac because Google Application
   Default Credentials are absent. No production apply was attempted.
4. **Real-account Cloud E2E:** the cleanup-safe script is ready, but it requires
   the deployed Functions plus short-lived administrator OAuth and App Check
   tokens. It has not produced a production `passed` result yet.
5. **Android:** no Android SDK is installed, so an Android build or fresh
   install cannot be accepted.
6. **Real devices:** iOS App Attest, Apple Health, APNs and Android Play
   Integrity/Health Connect still require signed builds on actual devices.
7. **Release identity:** Android and iOS still use `com.example.nudge`.
   Replacement production Firebase apps and regenerated configuration are
   required before store distribution because Firebase app identifiers are
   immutable.

## Required next execution order

1. Upgrade `nudge-discipline-app` to Blaze and initialize the default Storage
   bucket.
2. Install/authenticate Google Cloud Application Default Credentials on the
   release machine.
3. Run relationship and reward migration dry-runs; apply only when both report
   zero issues; then run both dry-runs again.
4. Deploy Functions and Storage Rules, then verify the deployed function list
   and App Check enforcement.
5. Run `npm --prefix scripts run e2e:production:accounts` with short-lived
   credentials and retain only its redacted JSON acceptance result.
6. Register final mobile identifiers, install the Android SDK, build signed
   device artifacts, and complete iOS/Android fresh-install acceptance.
