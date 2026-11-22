# Avatar progress key migration — preflight only

## Current status

The planner is implemented and unit-tested. Production has NOT been read,
modified, migrated or accepted. `readyForApply` is deliberately always false.
PR #66 must remain draft until the execution and recovery gates below exist.

## Dry run

Use a privately stored export with `catalogs` and `users` arrays. Each element
has `{id, data}`. Include archived catalog series too; they can own old progress.
Do not commit exports or output: both may contain private account history.

```sh
node scripts/avatar_progress_migration_plan.mjs /absolute/private/export.json
```

The result records issues, exact before/after projections and a before-image
fingerprint. Ambiguous names, collisions with built-ins, mixed old/new keys and
invalid amounts fail closed for that user. No XP is added, awarded or copied to
multiple series. Immutable historical receipts remain untouched.

## Required apply gate (not yet implemented)

1. Inventory all users and all historical catalog identities; resolve each issue
   explicitly. A renamed legacy series requires an evidenced mapping; do not
   infer it from the current name or avatar image.
2. Pause reward/equipment writes using the owned cutover protocol and coordinate
   account-deletion fences. Re-read each user inside a transaction.
3. Verify before-image fingerprints; store private recovery evidence and update
   only the targeted progress fields. Preserve absent-field state.
4. Ensure replay does not migrate twice. Do not rewrite immutable receipts;
   preserve an auditable mapping for historical reconciliation.
5. Re-run inventory and compare per-user/per-day XP totals before unpausing.

## Required rollback (not yet implemented)

While the cutover remains fenced, restore only stored before-images whose
post-apply fingerprints still match. Preserve unrelated user fields. Fail closed
if data or recovery evidence changed; never use a blind whole-document restore.
Do not deploy the new progress-key semantics before this apply/rollback path is
tested against the emulator and the production dry-run is reviewed.
