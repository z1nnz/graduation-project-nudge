import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const builtInNames = new Set([
  '星辰旅人', '星詠魔導', '焰心鬥士', '玫瑰學院', '月影忍者', '森語女神',
]);
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const fingerprint = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');

// Pure preflight only. It never writes Cloud data or changes immutable receipts.
export function buildAvatarProgressMigrationPlan({ catalogs = [], users = [] }) {
  const issues = [];
  const names = new Map();
  const keys = new Set();
  for (const catalog of catalogs) {
    const data = catalog.data;
    if (data?.type !== 'avatar_series') continue;
    const name = data.series?.name ?? data.series_name;
    const key = data.series?.key ?? data.series_key;
    if (typeof name !== 'string' || !name || typeof key !== 'string' ||
        !/^[a-z0-9][a-z0-9_-]{0,79}$/.test(key) || keys.has(key)) {
      issues.push({ catalogId: catalog.id, reason: 'invalid_or_duplicate_series_identity' });
      continue;
    }
    keys.add(key);
    names.set(name, [...(names.get(name) ?? []), key]);
  }
  const updates = [];
  // An incomplete or ambiguous catalog inventory cannot establish any safe
  // target identity. Do not emit tempting partial migration candidates.
  if (issues.length) {
    return { mode: 'dry-run-only', readyForApply: false, issues, updates };
  }
  for (const user of users) {
    const before = {
      avatarSeries: user.data?.avatarSeries ?? null,
      avatarExperienceLedger: user.data?.avatarExperienceLedger ?? {},
    };
    if (!isRecord(before.avatarExperienceLedger)) {
      issues.push({ userId: user.id, reason: 'invalid_experience_ledger' });
      continue;
    }
    const after = structuredClone(before);
    let invalid = false;
    const resolve = name => {
      if (!names.has(name)) return name;
      const matches = names.get(name);
      if (matches.length !== 1 || builtInNames.has(name) ||
          (keys.has(name) && matches[0] !== name)) {
        issues.push({ userId: user.id, seriesName: name, reason: 'ambiguous_legacy_name' });
        invalid = true;
        return name;
      }
      return matches[0];
    };
    for (const [date, bySeries] of Object.entries(after.avatarExperienceLedger)) {
      if (!isRecord(bySeries) || Object.values(bySeries).some(value => !Number.isSafeInteger(value) || value < 0)) {
        issues.push({ userId: user.id, date, reason: 'invalid_experience_amount' });
        invalid = true;
        continue;
      }
      for (const [name, amount] of Object.entries(bySeries)) {
        const key = resolve(name);
        if (key === name) continue;
        if (Object.hasOwn(bySeries, key)) {
          issues.push({ userId: user.id, date, reason: 'legacy_and_stable_key_overlap' });
          invalid = true;
          continue;
        }
        bySeries[key] = amount;
        delete bySeries[name];
      }
    }
    if (typeof after.avatarSeries === 'string') after.avatarSeries = resolve(after.avatarSeries);
    if (!invalid && JSON.stringify(before) !== JSON.stringify(after)) {
      updates.push({ userId: user.id, beforeFingerprint: fingerprint(before), before, after });
    }
  }
  return { mode: 'dry-run-only', readyForApply: false, issues, updates };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv.length !== 3 || process.argv[2].startsWith('--')) {
    throw new Error('Usage: node scripts/avatar_progress_migration_plan.mjs <private-export.json>; no apply supported');
  }
  process.stdout.write(JSON.stringify(buildAvatarProgressMigrationPlan(
    JSON.parse(readFileSync(process.argv[2], 'utf8')),
  ), null, 2) + '\n');
}
