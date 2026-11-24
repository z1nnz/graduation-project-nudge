const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
if (process.env.FIRESTORE_EMULATOR_HOST) {
  const result = spawnSync(process.execPath, ["--test", "functions/test/i10-town-goals.test.js"], { stdio: "inherit" });
  assert.equal(result.status, 0);
}
