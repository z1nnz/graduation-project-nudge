# Nudge Domain Context

## Core terms

- **Character Series**: One publishable character family with a stable key,
  theme, Codex description, and exactly three ordered Evolution Stages.
- **Evolution Stage**: One visual and progression state in a Character Series.
  It has its own name, description, full-body asset, icon, level requirement,
  experience requirement, and predecessor.
- **Starter Stage**: Stage 1 of a Character Series. It is the only stage that
  can become a Shop Listing.
- **Codex Entry**: The App presentation of a Character Series, including its
  story, owned state, three stages, and Evolution Route.
- **Evolution Route**: The ordered Stage 1 → Stage 2 → Stage 3 progression.
  Stages 2 and 3 are earned by level and experience, never purchased directly.
- **Shop Listing**: A currently published and active item that can be purchased.
  A character Shop Listing always references a Starter Stage.
- **Family Link**: A consent-based relationship between two accounts created
  from a Guardian Request. Either participant can remove the relationship.
- **Group**: The canonical Firestore record for an organization, its owner,
  members, name, and lifecycle status.
- **Group Membership**: A user's membership in one Group. User-document
  `groupId`, `groupName`, and `isGroupOwner` fields are compatibility
  projections, not the canonical Group record.
- **Group Request**: An owner-issued invitation to join a specific active Group.
- **Study Room**: A time-bound collaboration space. A Study Room is not a Group;
  Group membership may grant context, but room participation remains explicit.

## Product boundary

The App owns daily action, purchase, Codex, evolution, and consent decisions.
The Web Dashboard owns long-term analysis, group administration, family
oversight, and catalog operations. Both surfaces use the same Firestore records;
neither surface maintains an independent binding or catalog truth.
