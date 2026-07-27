# ADR 0003: Group publications belong to the canonical Group

- Status: Accepted
- Date: 2026-07-27

Nudge stores challenges, suggested self-discipline schedules, and exam
templates beneath `groups/{groupId}` instead of the Group Manager's private
user document. App and Web derive Manager and Member capabilities from the
canonical Group owner and member list; user-document group fields remain
compatibility projections used only to locate and migrate the relationship.
This prevents App/Web drift, permits Firestore rules to enforce manager-only
publishing and member-only reading, and keeps a Manager from becoming the
controller of each Member's activity lifecycle.
