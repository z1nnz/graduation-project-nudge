# ADR 0012: Web App Check runtime configuration

## Status

Accepted — 2026-07-29.

## Context

Cloud callables enforce Firebase App Check. The shared Web client already
initialized App Check when a site key was present, but no deployed page
provided that key. A deployment could therefore appear healthy while Activity
Ledger, privacy, notification, relationship-outcome, and catalog calls all
failed attestation.

The App Check site key is a public client configuration value. App Check debug
tokens are privileged testing credentials and must remain secret.

## Decision

- GitHub Pages generates `assets/runtime-config.js` during deployment from the
  repository variable `NUDGE_FIREBASE_APP_CHECK_SITE_KEY`.
- The Firebase Web app uses a score-based reCAPTCHA Enterprise provider. Its
  public key is restricted to `z1nnz.github.io`, registered with Firebase App
  Check, and shared by the dashboard and Flutter Web production providers.
- Deployment fails when that variable is missing or still a placeholder.
- The generated file contains only public runtime configuration and is not
  committed.
- The shared Web bundle loads runtime configuration before loading the
  Firebase App Check SDK.
- Local App Check debug mode is opt-in, restricted to localhost, and receives
  its token only from an in-memory global set outside the repository.
- Catalog media upload stops before Storage writes when App Check
  configuration is absent.

## Consequences

The Pages workflow cannot deploy until the repository variable contains the
real public App Check site key. This is intentional: a failed deployment is
more accurate than a green deployment whose protected product flows cannot
reach Cloud.

Debug tokens must be registered in Firebase App Check and stored outside Git.
They must never be placed in the generated static runtime config.
