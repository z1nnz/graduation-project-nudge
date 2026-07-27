# Shared catalog and binding specification

## Required now

### Character operations

- Staff can publish one complete three-stage Character Series from the Web
  Dashboard.
- Every stage has a name, Codex description, full-body image, icon, level,
  experience, and evolution predecessor.
- The Dashboard rejects missing assets and non-increasing unlock requirements.
- Only the Starter Stage appears in the App shop.
- The full chain appears in the App Codex and Evolution Route.
- Draft, archived, expired, or incomplete series do not enter the App catalog.
- Catalog images are stored in Firebase Storage, not inside Firestore documents.
- Staff can archive a listing and the App removes it after Firestore sync.

### Family and group binding

- Guardian requests are visible to both participants, require receiver consent,
  and can be removed by either participant.
- A Group ID must resolve to an active `groups` document before joining.
- Group creation and join update the canonical Group and the user's
  compatibility projection together.
- Invitations are visible and actionable on both Web and App.
- Owners cannot dissolve a Group while other members remain; ownership must be
  transferred or the members removed first.

## Necessary next

- Owner-side member removal and ownership transfer.
- Storage cleanup for assets left behind after a failed metadata publish.
- Server-side uniqueness enforcement for `series_key`.
- Admin draft/preview workflow before publication.
- Audit log recording publisher, archive actor, and relationship transitions.

## Explicitly deferred

- More than three evolution stages.
- Direct purchase of evolved stages.
- Cross-group membership and organization hierarchies.
- Automatic guardian access to all private health details without per-category
  consent.
