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
- **Guardian**: The adult participant in a Family Link. A Guardian can send
  encouragement and propose shared goals, but cannot grant consent for the
  Child or write directly to the Child's private user document.
- **Child**: The self-discipline participant in a Family Link. The Child owns
  consent decisions, goal acceptance, and acknowledgement of encouragement.
- **Family Link**: The canonical `family_links/{linkId}` relationship between
  exactly one Guardian and one Child, created from an accepted Guardian
  Request. Either participant can end the relationship.
- **Consent Scope**: One Child-controlled category of summarized data that a
  Guardian may see. Consent is independent from encouragement and shared goals
  and can be withdrawn at any time. A new Family Link starts with every scope
  disabled; the Child must opt in explicitly.
- **Encouragement Card**: A Guardian-to-Child message inside a Family Link.
  Sending does not grant personal rewards; a Child acknowledgement creates one
  idempotent Family Bond Event.
- **Shared Goal**: A Guardian proposal that becomes a Child task only after the
  Child accepts it. The Child may decline or later mark an accepted goal done.
- **Family Bond XP**: Relationship-only progression earned from two-way family
  interactions. It is separate from discipline score, coins, and Character
  evolution and cannot be earned by repeatedly sending messages.
- **Group**: The canonical Firestore record for an organization, its owner,
  members, name, and lifecycle status.
- **Group Membership**: A user's membership in one Group. User-document
  `groupId`, `groupName`, and `isGroupOwner` fields are compatibility
  projections, not the canonical Group record.
- **Group Request**: An owner-issued invitation to join a specific active Group.
- **Group Manager**: The owner named by the canonical Group record. A Group
  Manager can publish shared programs and moderate membership, but cannot
  control an individual Member's Activity Session.
- **Group Member**: An active participant named by the canonical Group record.
  A Group Member can read Group Publications and decide when to perform their
  own activities, but cannot publish or edit manager content.
- **Group Publication**: Manager-authored shared content stored under a Group,
  such as a challenge, suggested self-discipline schedule, or exam template.
  It is not stored in the Manager's private user document.
- **Study Room**: A persistent peer self-discipline space centered on one
  activity type, shared goals, and shared rules. Members control their own
  activity and progress; a Study Room is not a host-controlled session or a
  Group.
- **Room Owner**: The member responsible for a Study Room's configuration,
  admission, and moderation. A Room Owner cannot start, pause, end, or alter
  another member's activity.
- **Activity Session**: One member's bounded attempt toward a Study Room goal.
  The member or their assigned device controls its lifecycle.
- **Synced Progress**: A member's Study Room progress imported from an approved
  source, such as health data or an assigned device, rather than entered by a
  Room Owner.

## Product boundary

The App owns daily action, purchase, Codex, evolution, Child consent, and Child
goal decisions. The Web Dashboard owns long-term analysis, group
administration, Guardian proposals, family consent summaries, and catalog
operations. Both surfaces use the same Firestore records; neither surface
maintains an independent binding or catalog truth. Family relationship growth
does not advance personal Character evolution.
