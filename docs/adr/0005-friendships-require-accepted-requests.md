# ADR 0005: Friendships require an accepted request

- Status: Accepted
- Date: 2026-07-27

## Context

App and Web both keep a friend list under
`users/{userId}/friends/{friendId}`. Treating the two list documents as the
source of truth lets one account manufacture both sides of a relationship.
That would also let the account bypass UI-only restrictions on friend messages.

## Decision

The deterministic request document
`friend_requests/req_{senderId}_{receiverId}` is the canonical relationship
record.

- A sender can create only a `pending` request.
- Only its receiver can accept it.
- Moving from `pending` to `accepted` and creating both friend projections is
  one atomic batch.
- A friend message requires both an `accepted` canonical request and both
  projections.
- Either participant can remove the relationship, but moving the canonical
  request to `removed` and deleting both projections is one atomic batch.
- Published messages are immutable and remain readable only by their sender and
  receiver. Removal prevents new messages.

The two friend projection documents are read models for App and Web. Their
existence alone is never proof of friendship.

## Consequences

App and Web must use the same batch protocol for accepting and removing a
friend. A pending request never unlocks the friend-only UI.

Before deploying these rules to existing data, audit legacy friend projections.
Keep a pair only when a matching accepted canonical request exists. Unmatched
or one-sided projections must not be auto-accepted; remove or quarantine them
for user review.
