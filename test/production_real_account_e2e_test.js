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
  assert.match(script, /NUDGE_FIREBASE_APP_CHECK_TOKEN/);
  assert.match(script, /finally\s*\{/);
  assert.match(script, /adminDeleteDocuments\(documentsToDelete\)/);
  assert.match(script, /adminDeleteAccounts\(accounts\)/);
  assert.match(script, /verifyAccountDeleted\(account\)/);
  assert.doesNotMatch(script, /console\.log\([^)]*(email|password|idToken)/);
});

test("production real-account E2E covers Cloud authority and audit paths", () => {
  for (const functionName of [
    "recordActivity",
    "recordPrivacyConsent",
    "requestPrivacyDataAction",
    "cancelPrivacyDataRequest",
    "updateNotificationPreferences",
    "markNotificationRead",
    "refreshRelationshipOutcome",
  ]) {
    assert.ok(
      script.includes(`\"${functionName}\"`),
      `missing callable: ${functionName}`,
    );
  }
  for (const step of [
    "cloud.activity_ledger_lifecycle",
    "cloud.privacy_consent_audited",
    "cloud.privacy_deletion_request_cancel_audited",
    "cloud.notification_preferences_audited",
    "cloud.relationship_notification_audited",
    "cloud.relationship_notification_outcome",
    "cloud.relationship_outcome_membership_bound",
  ]) {
    assert.ok(script.includes(step), `missing production E2E step: ${step}`);
  }
  assert.match(script, /X-Firebase-AppCheck/);
  assert.match(script, /activity_receipts\//);
  assert.match(script, /audit_events\/notification-read/);
  assert.match(script, /adminCommit/);
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
    "admin.audit_role_boundary",
  ]) {
    assert.ok(script.includes(step), `missing production E2E step: ${step}`);
  }
});

test("production real-account E2E covers family roles and multi-context outcomes", () => {
  for (const step of [
    "family.invitation_create",
    "family.notification_audited",
    "family.child_atomic_accept_with_memberships",
    "membership.family_and_group_coexist",
    "group.member_manager_action_denied",
    "family.child_role_boundary",
    "family.encouragement_acknowledged",
    "family.goal_completed",
    "cloud.family_outcome_and_memories",
    "family.atomic_end_with_membership_end",
  ]) {
    assert.ok(script.includes(step), `missing production E2E step: ${step}`);
  }
  assert.match(script, /relationship_outcomes\/family--/);
  assert.match(script, /family_tree/);
  assert.match(script, /family_companion/);
  assert.match(script, /relationship_memberships\/family--/);
  assert.match(script, /audit_events\/family-request--/);
  assert.match(script, /familyMemory\.memoryId/);
  assert.match(
    script,
    /memories\/encouragement_ack--encouragement_\$\{encouragementId\}/,
  );
  assert.match(
    script,
    /memories\/goal_completed--goal_\$\{familyGoalId\}/,
  );
});
