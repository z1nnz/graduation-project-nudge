# Nudge production acceptance

This runbook separates deployed production evidence from local/emulator
coverage and from release gates that still require external infrastructure.

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
  projection cleanup.

## Real-account Auth and Rules acceptance

`scripts/production_real_account_e2e.mjs` creates two short-lived Firebase
Auth accounts and exercises production Firestore Rules. It verifies:

1. both accounts can create only their own private profile;
2. a cross-account profile overwrite is denied;
3. a manager atomically creates a group and manager Membership;
4. a non-member cannot perform a manager action;
5. a manager can issue a group invitation;
6. the member atomically accepts the invitation, joins the group, and creates
   the member Membership;
7. the member and manager receive the intended Membership visibility;
8. leaving and group closure update the parent document and Membership
   lifecycle atomically; and
9. test documents and both Auth accounts are deleted and the credentials no
   longer sign in.

Run it only with a short-lived administrator OAuth access token that can clean
up the synthetic documents:

```sh
NUDGE_FIREBASE_PROJECT_ID=nudge-discipline-app \
NUDGE_FIREBASE_WEB_API_KEY='<public Firebase Web API key>' \
NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN='<short-lived OAuth token>' \
npm --prefix scripts run e2e:production:accounts
```

Never commit, print, or persist the administrator token. The script does not
print account email addresses, passwords, ID tokens, or the administrator
token.

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
