# Nudge production cutover acceptance — 2026-08-11

This record separates deployed Cloud acceptance, emulator fresh-install
acceptance, and store or hardware gates that still require real devices. It
does not claim App Attest, Play Integrity, APNs, FCM delivery, HealthKit, or
Health Connect acceptance on physical hardware.

## Deployed production evidence

- Production project: `nudge-discipline-app`.
- Default Storage bucket:
  `nudge-discipline-app.firebasestorage.app` in `ASIA-EAST1`.
- Storage Rules, Firestore Rules and indexes, and 22 Cloud Functions are
  deployed.
- Main CI run `31403740750` passed all required jobs for commit
  `2b59549734bc39eaaf69753801652c18ddc69393`.
- The latest applicable dashboard deployment is GitHub Actions run
  `31371944814` for commit
  `03dc78bc669d5e8158d95f36a1c9e2700cdc18db`. The later accepted changes did
  not change dashboard code.

## Production migration evidence

- Relationship Membership cutover run
  `migration_runs/hvSILhxF5vOUdE8q3LbX` completed at
  `2026-08-10T14:04:31.483Z` with 10 users, zero issues, zero legacy cleanup,
  zero Membership before-images, and zero user before-images.
- Reward Ledger baseline run `migration_runs/dgosJc1Rd5pKe3LExFFc`
  completed at `2026-08-10T14:05:12.421Z` with 10 baseline writes, 10
  projection writes, and zero issues.
- Both cutover fences are inactive and the shared destructive-operation guard
  is inactive.
- Production currently contains zero
  `relationship_migration_before_images` and zero
  `relationship_before_image_privacy_deletions`. The eventual Relationship
  purge is therefore an audited zero-count reconciliation, not a deletion of
  retained subject data.

## Real-account production E2E

- Run ID: `1786371783740-1441585e`.
- Result: 32 of 32 steps passed; document and Auth cleanup completed; the
  temporary App Check debug token was revoked.
- Redacted evidence:
  [`artifacts/2026-08-10-production-real-account-e2e.json`](artifacts/2026-08-10-production-real-account-e2e.json).
- Evidence SHA-256:
  `a8d65c1fb3a53b9f9c5aca0bb20e29f468ddde11bb449a3112fb78c1e22d1192`.

## iOS fresh-install acceptance

- Source commit:
  `2b59549734bc39eaaf69753801652c18ddc69393`.
- Target: iPhone 16 Plus Simulator, iOS 18.6, arm64,
  `69BA4BBE-5E6E-499E-9308-7996F32BD753`.
- The preinstall bundle lookup proved `com.example.nudge` was absent.
- A clean, arm64-only Xcode Debug build succeeded after the earlier universal
  build was proven to have failed from `No space left on device` while merging
  `gRPC-Core`.
- `simctl install` resolved a new application container,
  `simctl launch` returned PID `56306`, and the process remained observable.
- The captured screen shows the first-run role-selection onboarding.
- Evidence:
  [`artifacts/2026-08-11-ios-fresh-install.json`](artifacts/2026-08-11-ios-fresh-install.json)
  and
  [`artifacts/2026-08-11-ios-fresh-install.png`](artifacts/2026-08-11-ios-fresh-install.png).
- Evidence JSON SHA-256:
  `4420db554974a634c6fa0a7109458118e8bc4bc026adc06a33cd5b427ee17969`.

## Android fresh-install acceptance

- Source commit:
  `c7641debdcfaa0e1773ef689708ff9c80552c15c`.
- Target: Android API 36 arm64 emulator, serial `emulator-5554`.
- The build now uses stable Health Connect `1.1.0`, Android min SDK 26,
  core-library desugaring, and `FlutterFragmentActivity` for the Health Connect
  Activity Result contract.
- The arm64 Debug APK built successfully with SHA-256
  `7943ebfa34564a758b0f39c2c968d472b26aafe5c401f318696979ac2cb60e31`.
- The preinstall package lookup proved `com.example.nudge` was absent.
- `adb install` returned `Success`; the cold launch completed; PID `2410`
  remained alive; `MainActivity` was the top resumed activity; and the sampled
  logcat contained no fatal exception for Nudge.
- The captured screen shows the first-run role-selection onboarding.
- Evidence:
  [`artifacts/2026-08-11-android-fresh-install.json`](artifacts/2026-08-11-android-fresh-install.json)
  and
  [`artifacts/2026-08-11-android-fresh-install.png`](artifacts/2026-08-11-android-fresh-install.png).
- Evidence JSON SHA-256:
  `e338422f8b2b2358fe132eaee6dc8264540a9873a643e1ae0cabcdeece45bae1`.

## Formal acceptance and purge gate

The evidence required by the production acceptance manifest is now present,
but the immutable production record has not been written. Firestore contains
two eligible developer profiles, and the release operator must explicitly
select the correct Firebase UID for the audit field `acceptedBy`; assigning an
actor by guess would make the operational audit false.

After that UID is selected, create the versioned manifest, run
`record:production-acceptance`, then run the Relationship before-image purge
bound to `hvSILhxF5vOUdE8q3LbX`. Verify the immutable acceptance document,
acceptance audit, zero-count purge audit, inactive destructive-operation guard,
and replay behavior before closing the retention gate.

## External gates still open

- Replace `com.example.nudge` with final immutable Firebase mobile identifiers
  before store distribution.
- Produce signed release artifacts and complete App Store and Play release
  signing.
- Exercise App Attest, APNs, Apple Health, Play Integrity, FCM, and Health
  Connect on physical devices. Simulator and emulator acceptance do not prove
  these hardware-backed paths.
