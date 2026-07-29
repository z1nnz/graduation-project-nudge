const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const script = fs.readFileSync(
  path.join(root, "scripts/production_real_account_e2e.mjs"),
  "utf8",
);
const packageJson = JSON.parse(
  fs.readFileSync(path.join(root, "scripts/package.json"), "utf8"),
);

test("production real-account E2E is explicit and cleanup-safe", () => {
  assert.equal(
    packageJson.scripts["e2e:production:accounts"],
    "node production_real_account_e2e.mjs",
  );
  assert.match(script, /NUDGE_FIREBASE_WEB_API_KEY/);
  assert.match(script, /NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN/);
  assert.match(script, /finally\s*\{/);
  assert.match(script, /adminDeleteDocuments\(documentsToDelete\)/);
  assert.match(script, /adminDeleteAccounts\(accounts\)/);
  assert.match(script, /verifyAccountDeleted\(account\)/);
  assert.doesNotMatch(script, /console\.log\([^)]*(email|password|idToken)/);
});

test("production real-account E2E covers role and membership boundaries", () => {
  for (const step of [
    "firestore.cross_account_profile_write_denied",
    "group.manager_atomic_create_with_membership",
    "group.non_member_manager_action_denied",
    "group.member_atomic_accept_with_membership",
    "membership.member_and_manager_visibility",
    "group.member_atomic_leave_with_membership_end",
    "group.manager_atomic_close_with_membership_end",
  ]) {
    assert.ok(script.includes(step), `missing production E2E step: ${step}`);
  }
});
