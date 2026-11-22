# Nudge coordinated system optimization

## Product boundary

One autonomous daily action connects App, Web, Cloud and physical companions.
Family and group features remain first-class secondary contexts, not tools for
controlling another member's activity. Device demos never mint real rewards.

## Ordered delivery slices

| Slice | Deliverable | Acceptance gate | Status |
| --- | --- | --- | --- |
| 1 | Admin three-stage catalog, starter-only shop, App Codex and evolution | Stable identity, migration plan, strict parser, timed availability, purchase/equip tests | In development; previous review findings remain open |
| 2 | Shared pending/confirmed/retry synchronization | Offline/restart/replay and account-switch tests; no duplicate rewards | Existing infrastructure; cross-surface acceptance needed |
| 3 | App Living Home and next action | Character, one actionable task, progress, related context and sync status; empty/error states | Planned |
| 4 | Character feedback and recovery | Celebrate Cloud receipt once; supportive return flow without punitive decay | Planned |
| 5 | One seven-day themed journey | Adjustable goals and one coherent story reward; no second reward ledger | Planned |
| 6 | Autonomous activity rooms | Member-controlled lifecycle, bounded encouragement, explicit health sources | Existing core; UX consolidation planned |
| 7 | Family companionship | Child consent, guardian proposals, sharing controls, tree/memories | Existing core; end-to-end review needed |
| 8 | Group participation | Manager publications, member decisions, planet milestones and summaries | Existing core; end-to-end review needed |
| 9 | Web role workspaces | Distinct personal/guardian/child/manager/member content and route guards | Guards merged; workspace improvements planned |
| 10 | Admin content studio | Preview, validation, draft/publish/archive, immutable identity and audit | Partial |
| 11 | PWA quick companion | Install entry, today/focus, offline state, invitation intents with auth checks | Planned; capability-based fallbacks required |
| 12 | Orbit circular firmware | Three visible scenes, countdown, recovery and report preview | PR #65; compile passed, panel unverified |
| 13 | Station desk firmware | Character/focus/rest, optional LED and brightness inputs | Existing teammate PRs require integration review |
| 14 | Device/App/Cloud bridge | Durable evidence before ACK, assignment checks, confirmed result feedback | Existing core; real-device acceptance pending |
| 15 | Report and rehearsal | Honest screenshots, explicit demo labels, reproducible runbook | Software preview available; real-panel photos pending |

## Integration policy

- Small dependent PRs, not one all-system merge.
- Preserve unrelated local changes and teammate branches.
- No production data rewrite without a dry-run, explicit apply gate and rollback.
- No secrets in Git. No generated mockup presented as a device photograph.
- Automated checks, source merge, deployment and real-device acceptance are
  separate statuses. Never mark a slice complete solely because CI is green.
- Real iPhone installation acceptance remains out of scope per user request.

## Immediate work

Fix catalog schedule drift and the missing fallback route display first. Then
finish strict published-document parsing and progress-key migration safeguards
before releasing the character identity change. Continue Orbit/Station source
integration while the physical devices are unavailable; do not guess GPIO maps.
