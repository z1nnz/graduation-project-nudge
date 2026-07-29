const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("health ingestion requires versioned Cloud consent", () => {
  const index = read("functions/index.js");
  const ingestion = read(
    "functions/src/ingest-health-snapshots-handler.js",
  );
  const consentService = read("functions/src/privacy-consent-service.js");
  const appState = read("lib/state/app_state.dart");
  const webApp = read("web_dashboard/assets/app.js");
  const rules = read("firestore.rules");

  assert.match(index, /createHealthConsentChecker/);
  assert.match(index, /export const recordPrivacyConsent/);
  assert.match(ingestion, /requireHealthConsent/);
  assert.match(consentService, /audit_events/);
  assert.match(consentService, /privacy_consents/);
  assert.match(appState, /CloudPrivacyConsentGateway/);
  assert.match(webApp, /recordPrivacyConsent/);
  assert.match(rules, /match \/privacy_consents\/\{userId\}/);
  assert.match(rules, /match \/audit_events\/\{auditEventId\}/);
});

test("notification preferences are Cloud audited and shared by App and Web", () => {
  const index = read("functions/index.js");
  const service = read(
    "functions/src/notification-preference-service.js",
  );
  const appState = read("lib/state/app_state.dart");
  const webApp = read("web_dashboard/assets/app.js");
  const rules = read("firestore.rules");

  assert.match(index, /export const updateNotificationPreferences/);
  assert.match(service, /notification_preferences/);
  assert.match(service, /audit_events/);
  assert.match(appState, /CloudNotificationPreferenceGateway/);
  assert.match(webApp, /updateNotificationPreferences/);
  assert.match(
    rules,
    /match \/notification_preferences\/\{userId\}/,
  );
});

test("privacy surfaces do not claim local deletion removes Cloud data", () => {
  const appPrivacy = read("lib/screens/privacy_data_page.dart");
  const webPrivacy = read("web_dashboard/privacy.html");

  assert.match(appPrivacy, /不等於刪除既有 Cloud Ledger 紀錄/);
  assert.match(appPrivacy, /只清除此裝置快取/);
  assert.match(webPrivacy, /清快取不是刪雲端/);
  assert.match(webPrivacy, /不會把既有 Ledger 紀錄或帳號資料假裝成已刪除/);
});

test("staff audit page queries immutable Cloud events without demo rows", () => {
  const admin = read("web_dashboard/admin_dashboard.html");

  assert.match(admin, /id="audit-section"/);
  assert.match(admin, /collection\('audit_events'\)/);
  assert.match(admin, /\.orderBy\('createdAt', 'desc'\)/);
  assert.match(admin, /startAdminAuditLog\(\)/);
  assert.doesNotMatch(admin, /mockAudit|demoAudit|假稽核/);
});
