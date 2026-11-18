const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {template, assess, freezePolicy, evidenceFile, digest} = require('../scripts/demo_acceptance.cjs');

// These are parser fixtures, never physical evidence or a published acceptance report.
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'nudge-acceptance-test-'));
  t.after(() => fs.rmSync(root, {recursive: true, force: true}));
  const save = (file, body) => {fs.writeFileSync(path.join(root, file), body); return {file, sha256: digest(Buffer.from(body))};};
  const video = save('unit-fixture.mp4', 'UNIT FIXTURE: not a physical video');
  const ref = (i = 0) => ({...video, kind: 'physical_video', continuous: true,
    duration_ms: 1000000, start_ms: i * 40000, end_ms: i * 40000 + 30000});
  const record = template();
  for (const [name, d] of Object.entries(record.devices)) {
    d.hardware = {board: 'fixture board', display: 'fixture display', board_id: name + '-fixture',
      wiring_confirmed: true, independent_controller_confirmed: true};
    const binary = save(name + '_p0a.bin', 'UNIT FIXTURE binary ' + name);
    d.firmware = {source_commit: 'a'.repeat(40), build_id: 'aaaaaaaaaaaa', binary_sha256: binary.sha256,
      environment: name + '_p0a', profile_sha256: 'b'.repeat(64), display_configured: true};
    const logs = ['native-tests', 'platformio-clean', 'platformio-build'].map(label => save(name + '-' + label + '.txt', 'UNIT FIXTURE ' + label));
    const gateA = {schema_version: 1, scope: 'software-only', passed: true, physical_verified: false,
      source_commit: d.firmware.source_commit,
      host_probe: {scope: 'host-simulation-only', physical_verified: false, p0a_replays: 10, p0b_replays: 10, restart_total: 80},
      commands: ['native-tests', 'platformio-clean', 'platformio-build'].map(label => ({label, exit_code: 0})), logs,
      environments: [{...d.firmware, device: name, clean_build: true, binary: binary.file, configuration: 'unit-fixture'}]};
    d.gate_a_report = {...save(name + '-gate-a.json', JSON.stringify(gateA)), kind: 'software_report'};
  }
  function fill(name, id, observations) {
    const d = record.devices[name];
    d.trials[id].forEach((r, i) => Object.assign(r, {status: 'pass', scene: r.scene || 'home', elapsed_ms: i * 40000,
      observed_build_id: d.firmware.build_id, operator: 'unit-fixture', date: '2026-11-19',
      observations: typeof observations === 'function' ? observations(i) : observations, evidence: ref(i)}));
  }
  function minimum(name) {
    fill(name, 'colors', i => ({color: ['red', 'green', 'blue', 'black', 'white'][i], full_screen: true}));
    fill(name, 'orientation', {upright_text: true});
    fill(name, 'full_frame', {no_partial_update_corruption: true});
    fill(name, 'cold_boot', {home_within_10s: true, home_ms: 1500});
    fill(name, 'usb_cycle', {usb_removed_and_reinserted: true, display_recovered: true});
    fill(name, 'p0a', {sequence: 'home,focus,complete', automatic: true, nudge_recognizable: true,
      no_app: true, no_network: true, no_optional: true});
  }
  return {root, record, ref, fill, minimum, save, assess: () => assess(record, root, '2026-11-19')};
}

test('pending template never grants software or physical acceptance', t => {
  const f = fixture(t), r = assess(template(), f.root, '2026-11-19');
  assert.equal(r.minimum_p0a_records_complete, false);
  assert.equal(r.submission_records_complete, false);
  assert.equal(r.physical_acceptance_certified, false);
  assert.equal(r.freeze.allow_new_features, false);
  for (const d of Object.values(r.devices)) assert.equal(d.counts.cold_boot.valid_passes, 0);
});
test('CLI creates pending record, refuses overwrite and exits 2 for missing physical proof', t => {
  const f = fixture(t), cli = path.resolve(__dirname, '../scripts/demo_acceptance.cjs'), file = path.join(f.root, 'record.json');
  const call = args => spawnSync(process.execPath, [cli, ...args], {encoding: 'utf8'});
  assert.equal(call(['init', file]).status, 0);
  assert.equal(call(['init', file]).status, 1);
  const r = call(['assess', file, '--evidence-root', f.root, '--today', '2026-11-19']);
  assert.equal(r.status, 2); assert.equal(JSON.parse(r.stdout).physical_acceptance_certified, false);
});
test('invalid schema, duplicate attempts, missing groups and non-boolean adoption reject', t => {
  const f = fixture(t);
  assert.throws(() => assess({}, f.root), /schema/);
  f.record.devices.orbit.trials.cold_boot[1].attempt = 1;
  assert.throws(f.assess, /duplicate trial/);
  f.record.devices.orbit.trials.cold_boot[1].attempt = 2;
  f.record.devices.orbit.adoption.p1 = 'yes'; assert.throws(f.assess, /invalid device/);
  f.record.devices.orbit.adoption.p1 = false;
  delete f.record.devices.orbit.trials.colors; assert.throws(f.assess, /missing trial/);
});
test('evidence hashes reject missing, empty and changed files', t => {
  const f = fixture(t), r = f.ref(); assert.equal(evidenceFile(r, f.root, true), true);
  assert.equal(evidenceFile({...r, file: 'missing.mp4'}, f.root, true), false);
  fs.writeFileSync(path.join(f.root, r.file), ''); assert.equal(evidenceFile(r, f.root, true), false);
  fs.writeFileSync(path.join(f.root, r.file), 'changed'); assert.equal(evidenceFile(r, f.root, true), false);
});
test('evidence cannot escape root via traversal, absolute path or symlink', t => {
  const f = fixture(t), r = f.ref();
  assert.equal(evidenceFile({...r, file: '../outside.mp4'}, f.root, true), false);
  assert.equal(evidenceFile({...r, file: path.join(f.root, r.file)}, f.root, true), false);
  fs.symlinkSync(__filename, path.join(f.root, 'outside.mp4'));
  assert.equal(evidenceFile({...r, file: 'outside.mp4', sha256: digest(fs.readFileSync(__filename))}, f.root, true), false);
});
test('software screenshot/host trace cannot fill physical trial', t => {
  const f = fixture(t); f.minimum('orbit');
  f.record.devices.orbit.trials.p0a[0].evidence.kind = 'host_simulation';
  const r = f.assess(); assert.equal(r.devices.orbit.counts.p0a.valid_passes, 2);
  assert.equal(r.devices.orbit.p0a_ready_for_review, false);
});
test('Gate A binds source/build/profile/binary and rejects missing binary bytes', t => {
  const f = fixture(t); assert.equal(f.assess().devices.orbit.gates.A, true);
  f.record.devices.orbit.firmware.profile_sha256 = 'c'.repeat(64);
  assert.equal(f.assess().devices.orbit.gates.A, false);
  f.record.devices.orbit.firmware.profile_sha256 = 'b'.repeat(64);
  fs.writeFileSync(path.join(f.root, 'orbit_p0a.bin'), 'changed');
  assert.equal(f.assess().devices.orbit.gates.A, false);
});
test('3/3 minimum P0-A stays independent of later optional and P0-B gates', t => {
  const f = fixture(t); f.minimum('orbit'); f.minimum('station');
  let r = f.assess(); assert.equal(r.minimum_p0a_records_complete, true);
  assert.equal(r.devices.orbit.p0b_ready_for_review, false);
  f.record.devices.orbit.adoption.p0b = true; r = f.assess();
  assert.equal(r.minimum_p0a_records_complete, true);
  assert.equal(r.submission_records_complete, false);
  assert.equal(r.physical_acceptance_certified, false);
});
test('one board ID cannot stand in for both independent controllers', t => {
  const f = fixture(t); f.minimum('orbit'); f.minimum('station');
  f.record.devices.station.hardware.board_id = f.record.devices.orbit.hardware.board_id;
  assert.equal(f.assess().minimum_p0a_records_complete, false);
});
test('Station unconfigured build may pass code Gate A but cannot pass physical identity', t => {
  const f = fixture(t); f.minimum('station');
  const d = f.record.devices.station, a = JSON.parse(fs.readFileSync(path.join(f.root, d.gate_a_report.file)));
  a.environments[0].configuration = 'unconfigured';
  d.gate_a_report = {...f.save(d.gate_a_report.file, JSON.stringify(a)), kind: 'software_report'};
  const r = f.assess(); assert.equal(r.devices.station.gates.A, true);
  assert.equal(r.devices.station.identity_complete, false);
  assert.equal(r.devices.station.p0a_ready_for_review, false);
});
test('duplicating an overlapping clip cannot inflate replay count', t => {
  const f = fixture(t); f.minimum('orbit');
  f.record.devices.orbit.trials.p0a[1].evidence = f.ref(0);
  const r = f.assess(); assert.equal(r.devices.orbit.counts.p0a.valid_passes, 2);
  assert.match(r.issues.join(), /overlapping/);
});
test('P0-B needs ten valid replays and restart coverage of all eight scenes', t => {
  const f = fixture(t), d = f.record.devices.orbit; d.adoption.p0b = true;
  f.fill('orbit', 'p0b', {sequence: 'boot,home,ready,focus,encouragement,complete,growth,summary', complete_seen: true, summary_returns_home: true});
  f.fill('orbit', 'restart', {returned_to_boot: true, no_reflash: true});
  assert.equal(f.assess().devices.orbit.counts.p0b.valid_passes, 10);
  d.trials.p0b[9].status = 'pending'; assert.equal(f.assess().devices.orbit.counts.p0b.valid_passes, 9);
  d.trials.restart.forEach(r => {r.scene = 'boot';});
  assert.equal(f.assess().devices.orbit.gates.D, false);
});
test('each adopted input must trigger once per trial, ten trials each', t => {
  const f = fixture(t), d = f.record.devices.orbit; d.adoption.p1 = true;
  d.adopted_inputs = ['button', 'encoder_rotation'];
  f.fill('orbit', 'input', {no_double_trigger: true, input_counts: {button: 1, encoder_rotation: 1}});
  assert.equal(f.assess().devices.orbit.counts.input.valid_passes, 10);
  d.trials.input[0].observations = {no_double_trigger: true, input_counts: {button: 1}};
  assert.equal(f.assess().devices.orbit.counts.input.valid_passes, 9);
});
test('failed trials require scene, time, version, date and reproducibility', t => {
  const f = fixture(t), r = f.record.devices.orbit.trials.p0a[0]; r.status = 'fail';
  assert.match(f.assess().issues.join(), /incomplete failure record/);
  Object.assign(r, {scene: 'focus', elapsed_ms: 3000, observed_build_id: 'aaaaaaaaaaaa', date: '2026-11-19',
    failure: {description: 'unit fixture failure', reproducible: 'unknown'}});
  assert.equal(f.assess().issues.length, 0);
});
test('ten BLE trials cannot bypass both-device P0-B prerequisites', t => {
  const f = fixture(t); f.minimum('orbit');
  f.record.devices.orbit.adoption.ble = true;
  f.fill('orbit', 'ble', {local_demo_survives_failure: true});
  const r = f.assess(); assert.equal(r.devices.orbit.counts.ble.valid_passes, 10);
  assert.equal(r.devices.orbit.optional_claims_ready_for_review, false);
  assert.equal(r.submission_records_complete, false);
  assert.match(r.issues.join(), /prerequisites/);
});
test('viewer feedback needs two distinct non-developers and all five observations', t => {
  const f = fixture(t);
  f.record.viewer_feedback.forEach(v => Object.assign(v, {non_developer: true, no_prior_code_explanation: true,
    distance_cm: 50, main_info_within_5s: true, device_difference_within_30s: true, readable_at_desk: true,
    completion_noticed: true, demo_understood: true, feedback: 'UNIT FIXTURE feedback', date: '2026-11-19'}));
  assert.equal(f.assess().gate_G_records_complete, true);
  f.record.viewer_feedback[1].viewer_id = 'viewer-1'; assert.equal(f.assess().gate_G_records_complete, false);
});
test('three rehearsals need serial/oral/fault observations, not a status flag', t => {
  const f = fixture(t);
  f.record.rehearsals.forEach(r => Object.assign(r, {status: 'pass', operator: 'unit fixture', date: '2026-11-19',
    duration_ms: 180000, evidence: {...f.ref(), end_ms: 180000}, observations: {serial_checked: true,
      each_scene_checked: true, restart_power_checked: true, no_code_prompt: true,
      no_app: true, network_off: true, p1_removed: true, one_device_unpowered: true, other_device_and_backup_video: true}}));
  assert.equal(f.assess().rehearsals_complete, true);
  f.record.rehearsals[2].observations.one_device_unpowered = false;
  assert.equal(f.assess().rehearsals_complete, false);
});
test('freeze boundaries use calendar days; unknown dates never authorize new features', () => {
  assert.equal(freezePolicy(null, '2026-11-19').allow_new_features, false);
  assert.equal(freezePolicy('2026-11-23', '2026-11-19').status, 'before_freeze');
  assert.equal(freezePolicy('2026-11-22', '2026-11-19').status, 'three_day_freeze');
  assert.equal(freezePolicy('2026-11-20', '2026-11-19').status, 'day_before_or_event');
  assert.equal(freezePolicy('2026-11-19', '2026-11-19').allow_new_features, false);
  assert.equal(freezePolicy('2026-11-18', '2026-11-19').status, 'past_event');
  assert.throws(() => freezePolicy('2026-02-30', '2026-11-19'), /Invalid/);
});
test('known competition date requires an explicit local day, never a silent UTC default', t => {
  const f = fixture(t); f.record.competition_date = '2026-11-22';
  assert.throws(() => assess(f.record, f.root), /explicit competition-local/);
  assert.equal(f.assess().freeze.status, 'three_day_freeze');
});
test('P0-A binary cannot be claimed as an adopted P0-B build', t => {
  const f = fixture(t); f.record.devices.orbit.adoption.p0b = true;
  const r = f.assess(); assert.equal(r.devices.orbit.p0b_ready_for_review, false);
  assert.match(r.issues.join(), /P0-A binary/);
});
