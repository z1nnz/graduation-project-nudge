# ADR 0014: Formal privacy data-rights workflow

- Status: Accepted
- Date: 2026-07-29

## Context

The App and Web previously supported versioned health consent and local cache
clearing, but neither action exported or deleted Cloud data. Treating local
cache deletion as account deletion would be misleading, while an immediate
client-side account deletion would bypass relationship cleanup, retention
obligations, staff review, and immutable evidence.

## Decision

Nudge uses Cloud-owned `privacy_data_requests` as the canonical workflow for
account exports and account deletion requests.

- App and Web call App Check-protected Cloud callables. Clients cannot write
  request state, export secrets, or audit events directly.
- Exports are assembled server-side from account-owned canonical collections.
  Queries paginate by document ID until exhausted; a partial artifact is never
  marked ready. An export above the current 10 MB artifact limit fails
  terminally and revokes its access token instead of silently truncating data.
  Push tokens, token claims, and export access tokens are explicitly excluded.
- Family and group records use requester-scoped DTOs derived from formal
  memberships. They include the requester role, relationship name and status,
  but never expose another participant's identifier or private attributes.
- Each export is stored as a private JSON artifact with a random download token.
  The token lives only in `privacy_export_access`, which is unreadable to
  clients. The client receives the download URL only through an authenticated
  callable and the audit record never contains the token or URL.
- Export artifacts expire after seven days. A scheduled cleanup deletes the
  object, revokes the access record, changes the public request to `expired`,
  and writes a system audit event.
- Account deletion requests have a seven-day cooling period and may be
  cancelled while pending or in review.
- Only staff roles may move deletion requests to review or reject them.
  `managePrivacyDataRequest` cannot mark a case complete. Completion belongs
  exclusively to `executeAccountDeletion`, which requires App Check, the end
  of the cooling period, a structured `caseId`, and an explicit destructive
  confirmation.
- Execution first inventories canonical family, group and room ownership. A
  group or room with other active participants blocks deletion until ownership
  is transferred. An active family link with another participant blocks
  deletion until that relationship is explicitly resolved; an already-ended
  family link is preserved for the other participant but the deleting account
  identifier, membership, consent, shared subcontent and derived outcome are
  removed. The executor never deletes another person's active shared family
  scope as a side effect. Sole-owner scopes are locked and revalidated
  immediately before recursive removal.
- A server-owned `account_deletion_fences/{uid}` record becomes active when the
  execution lease is claimed. The claim transaction refuses a fence owned by a
  different request and verifies the same fence again on failure and
  completion. Firestore rules fail closed for the fenced account, Auth is
  disabled and refresh tokens are revoked before erasure, and relationship
  notification triggers drop work involving a fenced account. Rules that
  create or accept family, group, friendship and formal membership references
  also require every referenced account to still have a user record and no
  deletion fence. Another signed-in account therefore cannot resurrect a
  deleted UID through a new invitation, acceptance or membership write.
- Every user callable holds a short `account_operation_leases/{uid}` lease for
  its complete execution, and every push send holds short leases for its
  recipient and relationship actors. The deletion claim transaction refuses
  active callable or push leases, while lease acquisition reads the deletion
  fence in the same transaction. This removes the check-then-write and
  check-then-send gaps instead of relying on a single early fence read.
- Inventory is run once for non-destructive preflight and again after the
  account-level fence and Auth freeze. The claimed execution stores and uses
  only the post-fence plan. If a relationship appeared between preflight and
  claim, the request becomes `deletion_failed` with a blocker plan instead of
  silently leaving a new scope behind.
- Ordinary group and room memberships are unlinked. Authored messages, events
  and sessions are removed through collection-group queries even when the
  account already left the room. Friendship messages, relationship requests,
  outbound and inbound notifications, push jobs, Ledger records and source
  claims, privacy export access, derived relationship outcomes, profile data
  and export objects are purged. The executor drains these sets twice before
  Auth deletion and once after Auth deletion to catch late background writes.
  Relationship outcome refreshes also re-read the canonical scope and every
  participant fence in their write transaction, preventing another member's
  stale refresh from restoring a deleted participant. The collection-group
  cleanup fields are declared with production `COLLECTION_GROUP` indexes. A
  staff account cannot execute its own deletion.
- The executor is retry-safe: it claims the request as `deleting` with a
  15-minute execution lease. An active lease prevents concurrent execution; an
  expired lease may be safely reclaimed after a worker crash. A partial failure
  moves the request to non-cancellable `deletion_failed`, records a sanitized
  failure code, and requires a safe retry. Mutable lease state is held in the
  private `account_deletion_executions` collection; every attempt, failure,
  blocker and completion is a separate append-only `audit_events` document.
  Completion verifies that the same private execution and attempt still own the
  lease, treats an already-removed Auth user as an idempotent retry, and marks
  `completed` only after Cloud data erasure and Auth removal both finish.
- User-authored relationship and notification audits that identify the subject
  as actor, principal or recipient are removed with the account. Append-only
  staff actions created from `admin_web` for other cases are a security
  retention exception: they remain immutable and are removed only by the
  target case's retention cleanup. Deleting one staff account therefore cannot
  destroy another account-deletion case's evidence.
- Completion replaces the operational request with a minimal staff-only
  evidence tombstone. It retains the case ID, staff assignment, bounded
  resolution note, timestamps, deletion counts and execution audit reference
  for 365 days; reason text, download tokens, account profile data and the
  `userId` field are removed. The request document ID remains a pseudonymous
  case-path identifier during that evidence period. A daily scheduled cleanup
  deletes expired tombstones, append-only request-targeted audits, private
  execution state and the deletion fence.

## Consequences

The user sees the same request status in App and Web before execution, while
the admin Web has a separate staff queue. Once verified deletion starts, login
is intentionally disabled; a failed execution is staff/support-only and is
retried by its case ID rather than reopening a partially erased account. App
and Web disclose this before submission. A `completed` deletion request is now
the result of the Cloud executor, not a free-form operational assertion.
Clients cannot directly erase canonical Ledger or relationship records.

Production acceptance still requires exercising export download and deletion
operations with real accounts, App Check, Storage, and the organization’s
retention procedure.
