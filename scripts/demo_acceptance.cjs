#!/usr/bin/env node
'use strict';
// Checks operator records and evidence integrity; cannot certify what a video shows.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const scenes = ['boot', 'home', 'ready', 'focus', 'encouragement', 'complete', 'growth', 'summary'];
const checks = {
  colors: {gate: 'B', count: 5}, orientation: {gate: 'B', count: 1},
  full_frame: {gate: 'B', count: 1}, cold_boot: {gate: 'B', count: 3}, usb_cycle: {gate: 'B', count: 3},
  p0a: {gate: 'C', count: 3},
  p0b: {gate: 'D', count: 10, adoption: 'p0b'},
  restart: {gate: 'D', count: 10, adoption: 'p0b'},
  focus_input: {gate: 'D', count: 1, adoption: 'p0b'},
  encouragement_exit: {gate: 'D', count: 1, adoption: 'p0b'},
  summary_home: {gate: 'D', count: 1, adoption: 'p0b'},
  offline: {gate: 'E', count: 1}, optional_failure: {gate: 'E', count: 1, adoption: 'p1'},
  input: {gate: 'F', count: 10, adoption: 'p1'}, ble: {gate: 'F', count: 10, adoption: 'ble'},
};
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
const text = v => typeof v === 'string' && v.trim().length > 0 && v.length <= 2000;
const sha = v => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v);
const commit = v => typeof v === 'string' && /^[a-f0-9]{40}$/.test(v);

function template() {
  const device = () => ({
    hardware: {board: null, display: null, board_id: null, wiring_confirmed: false,
      independent_controller_confirmed: false},
    firmware: {source_commit: null, build_id: null, binary_sha256: null, environment: null,
      profile_sha256: null, display_configured: false},
    adoption: {p0b: false, p1: false, ble: false},
    adopted_inputs: [],
    gate_a_report: null,
    trials: Object.fromEntries(Object.entries(checks).map(([id, c]) => [id,
      Array.from({length: c.count}, (_, i) => ({attempt: i + 1, status: 'pending',
        scene: id === 'restart' ? scenes[i % 8] : null, elapsed_ms: null,
        observed_build_id: null, operator: null, date: null, observations: {},
        evidence: null, failure: null}))])),
  });
  return {schema_version: 1, scope: 'physical-demo-record', competition_date: null,
    devices: {orbit: device(), station: device()},
    rehearsals: ['engineering', 'oral', 'failure'].map(type => ({type, status: 'pending',
      duration_ms: null, operator: null, date: null, evidence: null, observations: {}})),
    viewer_feedback: [1, 2].map(i => ({viewer_id: 'viewer-' + i, non_developer: false,
      no_prior_code_explanation: false, distance_cm: null,
      main_info_within_5s: null, device_difference_within_30s: null, readable_at_desk: null,
      completion_noticed: null, demo_understood: null, feedback: null, date: null})),
    notes: 'Physical acceptance deferred; empty entries are not passes.'};
}

function evidenceFile(ref, root, video = false, cache) {
  if (!ref || typeof ref !== 'object' || !text(ref.file) || !sha(ref.sha256)) return false;
  // Keep exported records portable and never traverse outside the evidence root.
  if (path.isAbsolute(ref.file) || ref.file.includes('\\') || ref.file.split('/').includes('..')) return false;
  if (video && (ref.kind !== 'physical_video' || ref.continuous !== true ||
      !/\.(mp4|mov|m4v)$/i.test(ref.file) || !Number.isFinite(ref.duration_ms) || ref.duration_ms <= 0 ||
      !Number.isFinite(ref.start_ms) || !Number.isFinite(ref.end_ms) || ref.start_ms < 0 ||
      ref.end_ms <= ref.start_ms || ref.end_ms > ref.duration_ms)) return false;
  if (!video && !['physical_video', 'physical_photo', 'software_report'].includes(ref.kind)) return false;
  try {
    const base = fs.realpathSync(root), file = fs.realpathSync(path.resolve(base, ref.file));
    const stat = fs.statSync(file);
    if (!file.startsWith(base + path.sep) || !stat.isFile() || stat.size === 0) return false;
    const key = [file, stat.size, stat.mtimeMs, stat.ctimeMs].join(':');
    let hash = cache?.get(key);
    if (!hash) {
      const h = crypto.createHash('sha256'), buffer = Buffer.alloc(1024 * 1024), fd = fs.openSync(file, 'r');
      try {let n; while ((n = fs.readSync(fd, buffer, 0, buffer.length, null)) > 0) h.update(buffer.subarray(0, n));}
      finally {fs.closeSync(fd);}
      hash = h.digest('hex'); cache?.set(key, hash);
    }
    return hash === ref.sha256;
  } catch { return false; }
}

function validDate(v) { return typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) &&
  Number.isFinite(Date.parse(v + 'T00:00:00Z')) && new Date(v + 'T00:00:00Z').toISOString().slice(0, 10) === v; }

function freezePolicy(date, today) {
  if (date === null) return {status: 'date_unknown', allow_new_features: false,
    rule: 'Confirm competition date before approving features; do not assume more than three days remain.'};
  if (!validDate(date) || !validDate(today)) throw Error('Invalid competition/today date');
  const days = Math.round((Date.parse(date) - Date.parse(today)) / 86400000);
  if (days < 0) return {status: 'past_event', days, allow_new_features: false};
  if (days <= 1) return {status: 'day_before_or_event', days, allow_new_features: false,
    rule: 'Only upload/power/video/cable checks; no new feature merge.'};
  if (days <= 3) return {status: 'three_day_freeze', days, allow_new_features: false,
    rule: 'Freeze accepted firmware/drivers; only display-blocking bug fixes, no new sensors/refactor/major library update.'};
  return {status: 'before_freeze', days, allow_new_features: true};
}

function assess(record, root, today) {
  const evidenceCache = new Map();
  if (!record || record.schema_version !== 1 || record.scope !== 'physical-demo-record') throw Error('Wrong record schema/scope');
  if (record.competition_date !== null && !validDate(today)) throw Error('Provide explicit competition-local calendar date with --today');
  const report = {schema_version: 1, scope: 'record-completeness-only',
    physical_acceptance_certified: false, human_review_required: true,
    freeze: freezePolicy(record.competition_date, today), devices: {}, issues: []};
  for (const name of ['orbit', 'station']) {
    const d = record.devices?.[name];
    if (!d || !d.trials || !d.adoption || Object.keys(d.adoption).sort().join() !== 'ble,p0b,p1' ||
        Object.values(d.adoption).some(v => typeof v !== 'boolean')) throw Error('Missing/invalid device record: ' + name);
    if (Object.keys(d.trials).sort().join() !== Object.keys(checks).sort().join()) throw Error('Unknown/missing trial group: ' + name);
    if (!Array.isArray(d.adopted_inputs) || new Set(d.adopted_inputs).size !== d.adopted_inputs.length ||
        d.adopted_inputs.some(v => !['button', 'encoder_rotation', 'encoder_press'].includes(v)) ||
        (!d.adoption.p1 && d.adopted_inputs.length)) throw Error('Invalid adopted inputs: ' + name);
    const f = d.firmware, h = d.hardware;
    let identity = f && h && text(h.board) && text(h.display) && text(h.board_id) &&
      h.wiring_confirmed === true && h.independent_controller_confirmed === true &&
      commit(f.source_commit) && text(f.build_id) && sha(f.binary_sha256) && sha(f.profile_sha256) &&
      text(f.environment) && f.environment.startsWith(name + '_') && f.display_configured === true;
    const gateAData = readGateA(d.gate_a_report, root, name, f, evidenceCache);
    const gateA = Boolean(gateAData);
    if (name === 'station' && gateAData?.configuration === 'unconfigured') identity = false;
    const result = {identity_complete: Boolean(identity), gates: {}, counts: {}, p0a_ready_for_review: false,
      p0b_ready_for_review: false, optional_claims_ready_for_review: false};
    result.gates.A = gateA;
    const complete = {};
    for (const [id, def] of Object.entries(checks)) {
      const trials = d.trials[id];
      if (!Array.isArray(trials) || trials.length !== def.count) throw Error('Wrong trial count: ' + name + '/' + id);
      const attempts = new Set();
      const adopted = id === 'input' ? d.adopted_inputs.length > 0 : !def.adoption || d.adoption[def.adoption];
      let passed = 0;
      const usedSegments = new Map();
      for (const t of trials) {
        if (!t || !Number.isInteger(t.attempt) || t.attempt < 1 || t.attempt > def.count || attempts.has(t.attempt) ||
            !['pending', 'pass', 'fail'].includes(t.status)) throw Error('Invalid/duplicate trial: ' + name + '/' + id);
        attempts.add(t.attempt);
        if (t.status === 'fail' && (!text(t.scene) || !text(t.failure?.description) ||
            !['yes', 'no', 'unknown'].includes(t.failure?.reproducible) || !validDate(t.date) ||
            !Number.isFinite(t.elapsed_ms) || t.elapsed_ms < 0 || !text(t.observed_build_id))) {
          report.issues.push(name + '/' + id + '/' + t.attempt + ': incomplete failure record');
        }
        let ok = identity && t.status === 'pass' && text(t.scene) && text(t.operator) && validDate(t.date) &&
          Number.isFinite(t.elapsed_ms) && t.elapsed_ms >= 0 && t.observed_build_id === f.build_id &&
          evidenceFile(t.evidence, root, true, evidenceCache);
        const o = t.observations || {};
        if (id === 'colors') ok = ok && o.color === ['red', 'green', 'blue', 'black', 'white'][t.attempt - 1] && o.full_screen === true;
        if (id === 'orientation') ok = ok && o.upright_text === true;
        if (id === 'full_frame') ok = ok && o.no_partial_update_corruption === true;
        if (id === 'cold_boot') ok = ok && o.home_within_10s === true && Number.isFinite(o.home_ms) && o.home_ms <= 10000 && o.home_ms >= 0;
        if (id === 'usb_cycle') ok = ok && o.usb_removed_and_reinserted === true && o.display_recovered === true;
        if (id === 'p0a') ok = ok && o.sequence === 'home,focus,complete' && o.automatic === true && o.nudge_recognizable === true &&
          o.no_app === true && o.no_network === true && o.no_optional === true && t.evidence.end_ms - t.evidence.start_ms >= 30000;
        if (id === 'p0b') ok = ok && o.sequence === scenes.join(',') && o.complete_seen === true && o.summary_returns_home === true;
        if (id === 'restart') ok = ok && scenes.includes(t.scene) && o.returned_to_boot === true && o.no_reflash === true;
        if (id === 'focus_input') ok = ok && o.nonblocking === true;
        if (id === 'encouragement_exit') ok = ok && o.left_scene === true && o.complete_seen === true;
        if (id === 'summary_home') ok = ok && o.returned_home === true;
        if (id === 'offline') ok = ok && o.no_app === true && o.wifi_off === true && o.phone_bluetooth_off === true &&
          o.completed_story === true && o.no_cloud_loading === true;
        if (id === 'optional_failure') ok = ok && o.error_serial_only === true && o.p0a_still_works === true;
        if (id === 'input') ok = ok && o.no_double_trigger === true &&
          Object.keys(o.input_counts || {}).sort().join() === [...d.adopted_inputs].sort().join() &&
          d.adopted_inputs.every(input => o.input_counts[input] === 1);
        if (id === 'ble') ok = ok && o.local_demo_survives_failure === true;
        if (ok) {
          const e = t.evidence, segments = usedSegments.get(e.sha256) || [];
          if (segments.some(([start, end]) => e.start_ms < end && e.end_ms > start)) {
            ok = false;
            report.issues.push(name + '/' + id + '/' + t.attempt + ': reused overlapping video segment');
          } else { segments.push([e.start_ms, e.end_ms]); usedSegments.set(e.sha256, segments); }
        }
        if (ok) passed++;
      }
      // Restart must cover ALL eight starting scenes, not just ten resets in Boot.
      const coverage = id !== 'restart' || new Set(trials.filter(t => t.status === 'pass').map(t => t.scene)).size === 8;
      complete[id] = adopted ? passed === def.count && coverage : null;
      result.counts[id] = {required: adopted ? def.count : 0, valid_passes: passed, adopted};
    }
    for (const gate of ['B', 'C', 'D', 'E', 'F']) {
      const needed = Object.entries(checks).filter(([, c]) => c.gate === gate).map(([id]) => complete[id]).filter(v => v !== null);
      result.gates[gate] = needed.length ? needed.every(Boolean) : null;
    }
    result.p0a_ready_for_review = Boolean(identity && gateA && result.gates.B && result.gates.C);
    result.p0b_ready_for_review = Boolean(result.p0a_ready_for_review && d.adoption.p0b &&
      !f.environment.endsWith('_p0a') && result.gates.D && result.gates.E);
    if (d.adoption.p0b && f?.environment?.endsWith('_p0a')) report.issues.push(name + ': P0-A binary cannot stand in for P0-B');
    result.optional_claims_ready_for_review = Boolean((d.adoption.p1 || d.adoption.ble) && result.p0a_ready_for_review && result.gates.E && result.gates.F);
    if (d.adoption.ble && !d.adoption.p0b) report.issues.push(name + ': BLE requires accepted P0-B and ten replays before adoption');
    report.devices[name] = result;
  }
  const ids = Object.values(record.devices).map(d => d.hardware?.board_id);
  if (ids.every(text) && ids[0] === ids[1]) {
    report.issues.push('Orbit and Station must use different independent board IDs');
    for (const d of Object.values(report.devices)) {
      d.identity_complete = d.p0a_ready_for_review = d.p0b_ready_for_review = d.optional_claims_ready_for_review = false;
    }
  }
  const feedback = record.viewer_feedback;
  report.gate_G_records_complete = Array.isArray(feedback) && feedback.length >= 2 &&
    new Set(feedback.map(v => v.viewer_id)).size === feedback.length && feedback.every(v =>
      text(v.viewer_id) && v.non_developer === true && v.no_prior_code_explanation === true &&
      Number.isFinite(v.distance_cm) && v.distance_cm >= 30 && v.distance_cm <= 80 && text(v.feedback) && validDate(v.date) &&
      ['main_info_within_5s', 'device_difference_within_30s', 'readable_at_desk', 'completion_noticed', 'demo_understood'].every(k => v[k] === true));
  for (const [name, d] of Object.entries(record.devices)) {
    if (d.adoption.ble && (!Object.values(report.devices).every(v => v.p0b_ready_for_review) || !report.gate_G_records_complete)) {
      report.devices[name].optional_claims_ready_for_review = false;
      report.issues.push(name + ': BLE prerequisites require both P0-B records and viewer/visual review');
    }
  }
  const rehearsals = record.rehearsals;
  report.rehearsals_complete = Array.isArray(rehearsals) && rehearsals.length === 3 &&
    ['engineering', 'oral', 'failure'].every(type => rehearsals.some(r => {
      const o = r.observations || {};
      return r.type === type && r.status === 'pass' && text(r.operator) && validDate(r.date) &&
        Number.isFinite(r.duration_ms) && r.duration_ms > 0 && evidenceFile(r.evidence, root, true, evidenceCache) &&
        (type !== 'engineering' || o.serial_checked === true && o.each_scene_checked === true && o.restart_power_checked === true) &&
        (type !== 'oral' || r.duration_ms >= 165000 && r.duration_ms <= 195000 && r.evidence.end_ms - r.evidence.start_ms >= r.duration_ms && o.no_code_prompt === true) &&
        (type !== 'failure' || ['no_app', 'network_off', 'p1_removed', 'one_device_unpowered', 'other_device_and_backup_video'].every(k => o[k] === true));
    }));
  report.minimum_p0a_records_complete = Object.values(report.devices).every(d => d.p0a_ready_for_review);
  report.submission_records_complete = report.minimum_p0a_records_complete && report.gate_G_records_complete &&
    report.rehearsals_complete && report.issues.length === 0 && Object.values(report.devices).every(d => d.gates.E) &&
    Object.entries(record.devices).every(([n, d]) =>
      (!d.adoption.p0b || report.devices[n].p0b_ready_for_review) &&
      (!(d.adoption.p1 || d.adoption.ble) || report.devices[n].optional_claims_ready_for_review));
  return report;
}

function readGateA(ref, root, device, firmware, cache) {
  if (!evidenceFile(ref, root, false, cache) || ref.kind !== 'software_report') return null;
  try {
    const a = JSON.parse(fs.readFileSync(path.resolve(root, ref.file), 'utf8'));
    const match = a.environments?.find(e => e.environment === firmware?.environment && e.device === device &&
      e.clean_build === true && e.binary_sha256 === firmware.binary_sha256 && e.build_id === firmware.build_id &&
      e.profile_sha256 === firmware.profile_sha256 && /^[a-z0-9_]+\.bin$/.test(e.binary) &&
      evidenceFile({file: path.posix.join(path.posix.dirname(ref.file), e.binary), sha256: e.binary_sha256,
        kind: 'software_report'}, root, false, cache));
    const valid = a.schema_version === 1 && a.scope === 'software-only' && a.passed === true &&
      a.physical_verified === false && a.source_commit === firmware?.source_commit &&
      a.host_probe?.scope === 'host-simulation-only' && a.host_probe.physical_verified === false &&
      a.host_probe.p0a_replays === 10 && a.host_probe.p0b_replays === 10 && a.host_probe.restart_total === 80 &&
      ['native-tests', 'platformio-clean', 'platformio-build'].every(label => a.commands.some(c => c.label === label && c.exit_code === 0)) &&
      a.logs.length >= 3 && a.logs.every(l => evidenceFile({file: path.posix.join(path.posix.dirname(ref.file), l.file),
        sha256: l.sha256, kind: 'software_report'}, root, false, cache)) && match;
    return valid ? {configuration: match.configuration} : null;
  } catch { return null; }
}

function main(args) {
  const [command, file, ...rest] = args;
  const opt = key => {const i = rest.indexOf(key); return i < 0 ? undefined : rest[i + 1];};
  if (command === 'init' && file) {
    fs.writeFileSync(file, JSON.stringify(template(), null, 2) + '\n', {flag: 'wx'});
    console.log('Created pending physical record; no checks passed.'); return 0;
  }
  if (command !== 'assess' || !file || !opt('--evidence-root')) throw Error('Usage: demo_acceptance.cjs init record.json | assess record.json --evidence-root DIR [--today YYYY-MM-DD] [--out report.json]');
  if (fs.statSync(file).size > 1024 * 1024) throw Error('Record exceeds 1 MiB');
  const report = assess(JSON.parse(fs.readFileSync(file, 'utf8')), opt('--evidence-root'), opt('--today'));
  const body = JSON.stringify(report, null, 2) + '\n';
  if (opt('--out')) fs.writeFileSync(opt('--out'), body, {flag: 'wx'});
  process.stdout.write(body);
  return report.submission_records_complete ? 0 : 2;
}
if (require.main === module) {try {process.exitCode = main(process.argv.slice(2));} catch (e) {console.error(e.message);process.exitCode = 1;}}
module.exports = {template, assess, freezePolicy, evidenceFile, digest, checks};
