const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("App and Web expose the same formal privacy data-rights workflow", () => {
  const appPage = read("lib/screens/privacy_data_page.dart");
  const appGateway = read("lib/services/cloud_privacy_data_gateway.dart");
  const webPage = read("web_dashboard/privacy.html");
  const webApp = read("web_dashboard/assets/app.js");
  const admin = read("web_dashboard/admin_dashboard.html");
  const cloud = read("functions/index.js");

  assert.match(appPage, /匯出我的資料/);
  assert.match(appPage, /申請刪除帳號/);
  assert.match(appGateway, /requestPrivacyDataAction/);
  assert.match(appGateway, /getPrivacyExportDownload/);

  assert.match(webPage, /data-privacy-data-rights/);
  assert.match(webPage, /7 天冷靜期/);
  assert.match(webApp, /listenToWebPrivacyDataRequests/);
  assert.match(webApp, /cancelPrivacyDataRequest/);

  assert.match(cloud, /export const requestPrivacyDataAction/);
  assert.match(cloud, /export const managePrivacyDataRequest/);
  assert.match(cloud, /export const executeAccountDeletion/);
  assert.match(cloud, /export const cleanupExpiredAccountDeletionEvidence/);
  assert.match(cloud, /assertAccountNotDeleting/);
  assert.match(cloud, /export const cleanupExpiredPrivacyExports/);
  assert.match(admin, /adminPrivacyRequestTableBody/);
  assert.match(admin, /managePrivacyDataRequest/);
  assert.match(admin, /冷靜期尚未結束/);
  assert.match(admin, /caseId/);
  assert.match(admin, /executeAccountDeletion/);
  assert.match(admin, /deletion_failed/);
});

test("privacy export secrets stay outside client-readable Firestore", () => {
  const service = read("functions/src/privacy-data-request-service.js");
  const deletionRepository = read(
    "functions/src/firestore-account-deletion-repository.js",
  );
  const rules = read("firestore.rules");
  const storageRules = read("storage.rules");

  assert.match(service, /privacy_export_access/);
  assert.match(service, /excludedServerSecrets/);
  assert.match(
    rules,
    /match \/privacy_export_access\/\{requestId\}[\s\S]*allow read, write: if false/,
  );
  assert.match(rules, /account_deletion_fences/);
  assert.match(service, /relationship_migration_before_images/);
  assert.match(
    deletionRepository,
    /\["relationship_migration_before_images", "actorUserId"\]/,
  );
  assert.match(
    rules,
    /match \/relationship_migration_before_images\/\{beforeImageId\}[\s\S]*allow read, write: if false/,
  );
  assert.match(
    rules,
    /match \/production_acceptance_evidence\/\{evidenceId\}[\s\S]*allow read, write: if false/,
  );
  assert.match(
    storageRules,
    /match \/privacy_exports\/\{userId\}\/\{fileName\}[\s\S]*allow read, write: if false/,
  );
});
