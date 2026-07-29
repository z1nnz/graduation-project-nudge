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
- Only staff roles may move deletion requests to review, reject them, or mark
  them complete. Completion is blocked until the cooling period ends and the
  staff must provide both a resolution note and a structured `caseId` that
  identifies the real deletion case or evidence.

## Consequences

The user sees the same request status in App and Web, while the admin Web has a
separate staff queue. A `completed` deletion request is an audited operational
assertion that the real deletion and retention checks were performed; it is not
permission for the client to erase canonical Ledger or relationship records.

Production acceptance still requires exercising export download and deletion
operations with real accounts, App Check, Storage, and the organization’s
retention procedure.
