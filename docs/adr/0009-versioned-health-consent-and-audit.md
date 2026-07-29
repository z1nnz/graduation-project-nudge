# ADR 0009: Versioned health consent and audit

- Status: Accepted
- Date: 2026-07-29

Health Connect and Apple Health daily aggregates enter the Cloud Activity
Ledger only when `privacy_consents/{userId}` contains an accepted consent for
the current policy version and the `healthIngestion` scope is true. The
`ingestHealthSnapshots` callable fails closed when that record is missing,
stale, or revoked.

App and Web update consent through the App Check-protected
`recordPrivacyConsent` callable. Every request carries a stable client request
ID, current policy version, action, and source surface. The callable writes the
current consent state and an immutable `audit_events` record in one Firestore
transaction. Replaying the same request ID returns the original result instead
of creating another event. Firestore Rules deny all client writes to both
collections and permit a user to read only their own consent and audit events;
authorized staff may read them for operations.

The accepted scope covers only the daily aggregate evidence contract currently
implemented: sleep, steps, exercise minutes, aggregation period, observation
time, data origins, and relationship room IDs explicitly attached by the user.
It does not authorize arbitrary health categories.

Revocation stops future Cloud health ingestion and clears the App's local
health cache. It does not silently delete immutable historical Ledger receipts
or the Firebase Authentication account. Data export and deletion requests need
a separate auditable data-rights workflow; local cache deletion must never be
presented as Cloud deletion.
