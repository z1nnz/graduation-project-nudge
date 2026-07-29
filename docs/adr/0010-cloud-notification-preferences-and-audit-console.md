# ADR 0010: Cloud notification preferences and audit console

- Status: Accepted
- Date: 2026-07-29

Signed-in App and Web clients share one
`notification_preferences/{userId}` document. The record contains the complete
supported channel set (`tasks`, `sleep`, `rooms`, and `deadline`), an enabled
flag and 24-hour time for each channel, delivery capability flags, schema
version, owner, and update time. A missing record means that the product
defaults apply; the first user change creates the formal Cloud record.

Clients update the complete channel set through the App Check-protected
`updateNotificationPreferences` callable. The callable validates the exact
schema and writes the current preferences plus an immutable `audit_events`
record in one transaction. A stable client request ID makes retries
idempotent. Firestore Rules deny direct client writes and allow only the owner
or authorized staff to read the current record.

The App listens to the Cloud record, keeps an offline cache, and schedules the
enabled channels with the operating system's local notification scheduler.
The Web notification center reads and updates the same Cloud record. Failed
Cloud updates are surfaced and the App restores the previous local settings
instead of claiming cross-device synchronization succeeded.

The delivery flags deliberately distinguish local scheduled reminders and
in-app notifications from remote push. `pushConfigured` remains false until
Firebase Cloud Messaging, APNs credentials, device token lifecycle, permission
handling, and real-device delivery acceptance are complete. The UI must not
label local scheduling as remote push.

Authorized staff can read the latest immutable events in the admin audit
console and filter them by category, action, or actor. The console never
creates or edits audit rows and currently states which actions are formally
covered. Other admin mutations must gain their own Cloud-side audited command
before they are described as audited.
