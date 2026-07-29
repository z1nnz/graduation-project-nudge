# ADR 0013: Audited device push delivery

## Status

Accepted — 2026-07-29.

## Context

ADR 0010 intentionally left `pushConfigured` false until Nudge had a real
Firebase Cloud Messaging and APNs lifecycle. A local reminder or Cloud inbox
row is not evidence that an account can receive a remote notification. Tokens
are also credentials: putting them in owner-readable profile documents would
expose them to the App and Web data surfaces.

## Decision

- A user explicitly enables system notifications before the App requests an
  FCM token.
- The App stores a random installation ID that contains no hardware
  identifier. It registers and revokes that installation through the
  App Check-protected `updatePushInstallation` callable.
- Raw tokens exist only in Cloud-written `push_installations`. Firestore Rules
  deny every client read and write. Immutable audit events contain token-free
  outcomes only.
- `push_delivery_state/{userId}` is the owner-readable, non-secret aggregate.
  It is the authority for `delivery.pushConfigured`; App and Web therefore
  report the same account state.
- Token claims prevent one refreshed or reassigned token from remaining active
  under two accounts. Sign-out revokes the installation before Firebase Auth
  sign-out and deletes the local FCM token. Invalid registration tokens are
  revoked after an FCM response.
- Creating a family or group inbox notification atomically creates a
  deterministic `push_delivery_jobs` document. A retried Cloud trigger sends
  notification and route data, records delivered, partial, skipped, or failed
  status, and writes an immutable delivery audit.
- Foreground messages use the same local notification channel. Notification
  taps route to the family center or group management page.
- iOS declares Push Notifications and remote-notification background mode.
  All iOS configurations use the Firebase-registered bundle identifier.

## Consequences

FCM delivery still requires valid Firebase service credentials. iOS delivery
also requires an APNs authentication key or certificate configured in Firebase
and a provisioning profile with Push Notifications. Emulator and unit tests
prove authorization boundaries, idempotency, token secrecy, invalid-token
cleanup, and job construction; real-device acceptance remains a release gate
because simulators do not prove APNs delivery.

Browser push is a separate capability. The Web console reads the shared
delivery state and notification inbox but does not mint browser tokens until a
VAPID key, service worker lifecycle, and browser-specific opt-in flow are
implemented and accepted.
