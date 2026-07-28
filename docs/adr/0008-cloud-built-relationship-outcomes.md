# ADR 0008: Cloud-built relationship outcomes

- Status: Accepted
- Date: 2026-07-29

Nudge represents relationship growth separately from personal rewards:

- `relationship_outcomes/family--{familyLinkId}` is the selected relationship's
  family tree and companion state.
- `relationship_outcomes/group--{groupId}` is the selected group's planet and
  companion state.
- Family shared memories are deterministic children under
  `relationship_outcomes/family--{familyLinkId}/memories`.

The `refreshRelationshipOutcome` callable is the only writer. It authenticates
the caller, verifies that they belong to the requested relationship, reads
canonical family or group data, then writes the derived outcome. Firestore
Rules deny every client write. Clients may read an exact outcome only when a
deterministic formal Membership for that relationship is `active` or `ended`;
this preserves a family's completed memories after a link ends.

Family growth uses validated immutable `bond_events`. Goal and encouragement
collections provide supporting counts, while every shared memory is projected
from a bond event rather than arbitrary client text. Group growth uses only the
current canonical member list, member-owned shared summaries, and the current
challenge's member-owned participation records. Stale records from removed
members are excluded.

App and Web both listen to the same exact outcome document for the currently
selected relationship. The family surface renders different guardian and child
interfaces; the group surface renders different manager and member interfaces.
Relationship XP advances only the relationship tree or planet and its companion
character. It never mints personal avatar XP, coins, shop rewards, or challenge
settlements.

This ADR does not claim a historical group-performance archive. The group
metrics intentionally describe the current membership and current challenge.
Historical rollups require a later immutable aggregation contract.
