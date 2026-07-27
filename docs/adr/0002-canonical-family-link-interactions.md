# ADR 0002: Family interactions live under a canonical Family Link

- Status: Accepted
- Date: 2026-07-27

Nudge stores an accepted one-Guardian/one-Child relationship in
`family_links/{linkId}` and stores encouragements, shared goals, and idempotent
Family Bond events in its subcollections. The Child alone controls consent
scopes and goal decisions; the Guardian can propose and encourage but never
writes the Child's private user document. This avoids App/Web drift and makes
Firestore rules enforce the same responsibility split shown in the interfaces.

Family Bond XP is deliberately separate from discipline score, coins, and
Character evolution. Only two-way actions create Bond XP: acknowledging one
encouragement grants 3 XP and completing one accepted shared goal grants 10 XP.
This prevents a Guardian from creating pressure or progression by sending
repeated messages.

A new Family Link starts with all consent scopes disabled. After the Child opts
in, the App publishes only the selected aggregate fields to the link's
`summaries/current` document; the Web and Guardian App read that projection
instead of the Child's private user document.
