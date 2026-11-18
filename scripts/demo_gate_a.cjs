#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const {digest} = require('./demo_acceptance.cjs');

function run(options) {
  const source = fs.realpathSync(options.source), output = path.resolve(options.output);
  const project = path.join(source, 'firmware/nudge_competition_demo');
  const lock = JSON.parse(fs.readFileSync(path.join(__dirname, '../docs/competition-demo/package09-10/source-lock.json'), 'utf8'));
  const git = args => {
    const r = spawnSync('git', args, {cwd: source, encoding: 'utf8'});
    if (r.status !== 0) throw Error('Source checkout git verification failed');
    return r.stdout.trim();
  };
  if (git(['status', '--porcelain', '--', 'firmware/nudge_competition_demo'])) throw Error('Firmware source is dirty');
  const sourceCommit = git(['rev-parse', 'HEAD']);
  const tree = git(['rev-parse', 'HEAD:firmware/nudge_competition_demo']);
  if (tree !== lock.firmware_tree) throw Error('Source tree differs from reviewed lock; review/update lock before building');
  const profile = path.join(project, 'include/local_hardware_profile.h');
  const localProfile = fs.existsSync(profile);
  if (localProfile && !options.allowLocalProfile) throw Error('Local hardware profile present; requires explicit --allow-local-profile and later physical review');
  if (fs.existsSync(output)) throw Error('Output already exists; choose a fresh directory to avoid stale evidence');
  fs.mkdirSync(output, {recursive: true});
  const redact = s => s.split(source).join('<source-checkout>').split(output).join('<gate-a-output>').split(os.homedir()).join('<operator-home>');
  const report = {schema_version: 1, scope: 'software-only', passed: false, physical_verified: false,
    source_commit: sourceCommit, firmware_tree: tree, source_dirty: false, local_profile_present: localProfile,
    host_probe: null, environments: [], warnings: [], commands: [], logs: [],
    limitations: ['No USB upload or physical display acceptance.', 'Station default pinmap is unconfigured.',
      'Host replay counts cannot be copied into physical trials.', 'Compiler warnings still require human review.']};
  const command = (label, executable, args, cwd = project) => {
    const r = spawnSync(executable, args, {cwd, encoding: 'utf8', timeout: 600000, maxBuffer: 32 * 1024 * 1024});
    const raw = redact((r.stdout || '') + (r.stderr || '') + (r.error ? '\n' + r.error.message : ''));
    const log = raw.split('\n').map(l => l.trimEnd()).join('\n').trimEnd() + '\n';
    fs.writeFileSync(path.join(output, label + '.txt'), log);
    report.commands.push({label, executable: path.basename(executable), exit_code: r.status});
    report.logs.push({file: label + '.txt', sha256: digest(Buffer.from(log))});
    if (r.status !== 0) throw Error(label + ' failed; full output retained');
    return log;
  };
  try {
    const files = git(['ls-files', '--', 'firmware/nudge_competition_demo']).split('\n');
    const credentials = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AIza[\w-]{35}|gh[pousr]_[A-Za-z0-9]{30,}/;
    for (const file of files) if (credentials.test(fs.readFileSync(path.join(source, file), 'utf8'))) throw Error('Credential pattern found in tracked firmware; do not publish');
    if (localProfile && credentials.test(fs.readFileSync(profile, 'utf8'))) throw Error('Credential pattern found in local profile; do not publish');
    const profileBytes = localProfile ? fs.readFileSync(profile) : Buffer.concat([
      fs.readFileSync(path.join(project, 'include/demo/hardware_profile.h')),
      fs.readFileSync(path.join(project, 'src/hardware_profile.cpp'))]);
    const profileHash = digest(profileBytes);
    const buildId = sourceCommit.slice(0, 12) + (localProfile ? '-hw' + profileHash.slice(0, 8) : '');
    if (!fs.readFileSync(path.join(project, 'scripts/build_stamp.py'), 'utf8').includes('NUDGE_BUILD_ID')) throw Error('Missing source build identity');
    command('native-tests', 'make', ['test']);
    const compiler = options.cxx || process.env.CXX || 'c++';
    command('host-compiler-version', compiler, ['--version']);
    const probe = path.join(output, 'host-probe');
    command('host-probe-compile', compiler, ['-std=c++17', '-Wall', '-Wextra', '-Werror', '-I' + path.join(project, 'include'),
      path.join(project, 'src/core.cpp'), path.join(__dirname, 'demo_rehearsal_probe.cpp'), '-o', probe]);
    report.host_probe = JSON.parse(command('host-probe-run', probe, [], output));
    fs.unlinkSync(probe); // Do not distribute a host-specific executable as firmware.
    if (report.host_probe.scope !== 'host-simulation-only' || report.host_probe.physical_verified !== false ||
        report.host_probe.p0a_replays !== 10 || report.host_probe.p0b_replays !== 10 || report.host_probe.restart_total !== 80) throw Error('Incomplete host probe');
    command('platformio-version', options.platformio, ['--version']);
    const envs = ['orbit_p0a', 'station_p0a', 'orbit_demo', 'station_demo'];
    const envArgs = envs.flatMap(e => ['-e', e]);
    command('platformio-clean', options.platformio, ['run', '-t', 'clean', ...envArgs]);
    const buildLog = command('platformio-build', options.platformio, ['run', ...envArgs]);
    report.warnings = buildLog.split('\n').filter(l => /warning:/i.test(l));
    if (report.warnings.some(l => /out.of.bounds|array.bounds|stringop.overflow|use.after.free|uninitialized|driver.*not found/i.test(l))) throw Error('Potential memory/driver warning requires review');
    for (const environment of envs) {
      const bytes = fs.readFileSync(path.join(project, '.pio/build', environment, 'firmware.bin'));
      if (!bytes.includes(Buffer.from(buildId))) throw Error('Firmware embedded build identity mismatch');
      if (bytes.includes(Buffer.from(os.homedir()))) throw Error('Operator path embedded in binary');
      const device = environment.startsWith('orbit') ? 'orbit' : 'station';
      const file = environment + (device === 'station' && !localProfile ? '_unconfigured' : '') + '.bin';
      fs.writeFileSync(path.join(output, file), bytes);
      report.environments.push({device, environment, clean_build: true, build_id: buildId,
        binary: file, binary_sha256: digest(bytes), bytes: bytes.length, profile_sha256: profileHash,
        configuration: localProfile ? 'local-profile-requires-physical-review' : device === 'station' ? 'unconfigured' : 'board-default',
        physical_verified: false});
    }
    if (git(['rev-parse', 'HEAD']) !== sourceCommit || git(['rev-parse', 'HEAD:firmware/nudge_competition_demo']) !== tree ||
        git(['status', '--porcelain', '--', 'firmware/nudge_competition_demo'])) throw Error('Source changed during verification');
    if (localProfile !== fs.existsSync(profile) || localProfile && digest(fs.readFileSync(profile)) !== profileHash) throw Error('Hardware profile changed during build');
    report.passed = true;
  } catch (e) { report.error = redact(e.message); }
  fs.writeFileSync(path.join(output, 'gate-a.json'), JSON.stringify(report, null, 2) + '\n');
  return report;
}

function main(args) {
  const opt = key => {const i = args.indexOf(key); return i < 0 ? undefined : args[i + 1];};
  const source = opt('--source-checkout'), output = opt('--out'), platformio = opt('--platformio');
  if (!source || !output || !platformio) throw Error('Usage: demo_gate_a.cjs --source-checkout DIR --platformio EXECUTABLE --out NEW_DIR [--cxx EXECUTABLE] [--allow-local-profile]');
  const report = run({source, output, platformio, cxx: opt('--cxx'), allowLocalProfile: args.includes('--allow-local-profile')});
  console.log(JSON.stringify({passed: report.passed, scope: report.scope, physical_verified: false,
    environments: report.environments.length, error: report.error || null}));
  return report.passed ? 0 : 1;
}
if (require.main === module) {try {process.exitCode = main(process.argv.slice(2));} catch (e) {console.error(e.message);process.exitCode = 1;}}
module.exports = {run};
