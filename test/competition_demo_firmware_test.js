const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

test('offline firmware core replay, failure and rendering tests compile and pass', () => {
  const result = spawnSync('make', ['test'], {
    cwd: path.join(__dirname, '../firmware/nudge_competition_demo'), encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /PASS: replay/);
  assert.match(result.stdout, /PASS: station eight scenes/);
  assert.match(result.stdout, /PASS: demo protocol/);
});
