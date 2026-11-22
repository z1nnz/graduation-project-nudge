# Cloud activity feedback

App Home and Web Home show the same latest Cloud-written activity receipt for
the authenticated user, ordered by verifiedAt descending and limited to one.

- Bind receipt document ID and actor to the signed-in account; reject malformed
  activity type, timestamp and non-finite/negative metrics.
- Text identifies the confirmed activity category only. Never infer coin/XP
  amounts from receipt flags: a settled entry can be capped at zero.
- Show loading, empty/error, guest and cached-result states. Clear old feedback
  on account changes and ignore callbacks from cancelled subscriptions.
- Reject pending local-write snapshots as confirmation.
- No reward writes, animations, persisted acknowledgement or once-only
  celebration are implemented in this slice; the card is a status summary.
- Share parser fixtures between Dart and JavaScript.

## Deployment and acceptance

The new composite index for activity_receipts(actorUserId ASC, verifiedAt DESC)
must be deployed and ready before this UI is enabled in production. Existing
Rules already allow only owner/staff reads and prohibit all client writes; they
are intentionally unchanged. No existing documents or projections are migrated.

Local tests and CI are not production acceptance. Verify with two real accounts:
empty receipt state, Cloud activity confirmation, capped-reward wording,
offline cache, permission failure and rapid account switching. Real iPhone
installation is outside the requested acceptance scope.

Rollback: revert the read-only UI and index declaration. Do not delete receipts
or rewrite reward ledgers. An already-deployed unused index may remain safely.
