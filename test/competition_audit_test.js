const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../docs/competition-demo/audit00-13');
const tool = path.resolve(__dirname, '../scripts/audit_competition_packages.py');
const run = dir => spawnSync('python3', [tool, '--root', dir], {encoding:'utf8'});

test('all 14 packages have source-bound criteria, explicit pending work and preparation scores', () => {
  const out = run(root);
  assert.equal(out.status, 0, out.stderr);
  const report = JSON.parse(out.stdout);
  assert.equal(report.packages, 14);
  assert.ok(report.criteria_reviewed > 400);
  assert.ok(report.states.physical_deferred > 0);
  assert.ok(report.states.team_pending > 0);
  assert.equal(report.hardware_certified, false);
  assert.equal(report.all_package_criteria_completed, false);
  assert.equal(report.current_head_ci_must_be_checked_separately, true);
});

const mutations = {
  'omitted package': m => m.packages.pop(),
  'omitted acceptance row': m => m.packages.find(p => p.id === '04').criteria.pop(),
  'changed requirement quote': m => m.packages[0].criteria[0].text += ' approved',
  'unreviewed finding': m => m.packages[0].criteria[0].finding = '',
  'unknown evidence': m => m.packages[0].criteria[0].evidence_ids = ['invented'],
  'false hardware success': m => m.packages[0].criteria[0].physical_verified = true,
  'false whole-project completion': m => m.all_package_criteria_completed = true,
  'below threshold': m => m.packages[0].preparation_scores.criteria = 0,
  'wrong canonical source': m => m.requirements_commit = 'a'.repeat(40),
};
for (const [name, change] of Object.entries(mutations)) test('audit rejects ' + name, t => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'nudge-audit-'));
  t.after(() => fs.rmSync(temp, {recursive:true, force:true}));
  fs.cpSync(root, temp, {recursive:true});
  const file = path.join(temp, 'acceptance-matrix.json');
  const matrix = JSON.parse(fs.readFileSync(file));
  change(matrix);
  fs.writeFileSync(file, JSON.stringify(matrix));
  const out = run(temp);
  assert.equal(out.status, 1, out.stdout + out.stderr);
});

test('audit refuses a stale head disguised as its CI success or a missing PR', t => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'nudge-audit-'));
  t.after(() => fs.rmSync(temp, {recursive:true, force:true}));
  fs.cpSync(root, temp, {recursive:true});
  const file = path.join(temp, 'remote-snapshot.json');
  const snapshot = JSON.parse(fs.readFileSync(file));
  snapshot.delivery_prs[0].head = 'a'.repeat(40);
  fs.writeFileSync(file, JSON.stringify(snapshot));
  assert.equal(run(temp).status, 1);
  snapshot.delivery_prs.shift();
  fs.writeFileSync(file, JSON.stringify(snapshot));
  assert.equal(run(temp).status, 1);
});
