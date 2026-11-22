# Avatar evolution publishing pipeline

## Goal

Make a character series published from the Web admin behave as one consistent
product across Cloud, the App shop, the Codex, and the evolution route.

## Required behaviour

1. The admin publishes exactly three ordered stages in one command. Every stage
   carries a name, Codex description, full-body image, icon, level requirement,
   experience requirement, and predecessor.
2. Cloud is authoritative for catalog indexes and sale policy. Stage 1 is the
   only purchasable stage; stages 2 and 3 are evolution-only and cost zero.
3. The App reads the same published catalog document. The shop exposes only the
   starter, while the Codex and evolution route expose the complete chain.
4. Character progress uses the immutable `series_key`, not the editable display
   name. Renaming a series must not erase progress, and two series with the same
   display name must not share experience.
5. Built-in character progress remains backward compatible with its existing
   ledger keys.
6. The admin's active catalog table shows the complete three-stage route and
   clearly identifies the starter sold in the shop.
7. Draft, archived, expired, malformed, or index-colliding series never enter
   the App catalog.

## Acceptance evidence

- Web payload and Cloud normalization tests prove the three-stage sale policy.
- Cloud equipment tests prove dynamic evolution reads experience by
  `series_key` and rejects progress recorded under only the display name.
- Flutter catalog and App state tests prove the stable progress key, starter-only
  shop list, full Codex chain, and isolation of duplicate display names.
- The complete repository test suite and Flutter analyzer pass before merge.

## Incremental validation and migration preflight

- Published stage indexes must be explicit, ordered, contiguous, and integral;
  no fallback identity may be synthesized. Level, EXP and price numeric values
  must not be silently truncated. Starter requirements remain level 1 / 0 XP.
- Provide a pure, dry-run-only legacy-name-to-key migration planner. Preserve
  XP and input data; reject ambiguous identities and overlapping old/new keys.
  This slice does not implement production apply or rollback. Keep the PR draft
  until those paths and the documented release gates are complete.
