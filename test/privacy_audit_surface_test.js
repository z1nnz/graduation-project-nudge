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
  assert.match(index, /export const markNotificationRead/);
  assert.match(index, /notifyGuardianRequestCreated/);
  assert.match(index, /notifyGroupRequestUpdated/);
  assert.match(service, /notification_preferences/);
  assert.match(service, /audit_events/);
  assert.match(appState, /CloudNotificationPreferenceGateway/);
  assert.match(webApp, /updateNotificationPreferences/);
  assert.match(
    rules,
    /match \/notification_preferences\/\{userId\}/,
  );
  assert.match(rules, /match \/user_notifications\/\{notificationId\}/);
  assert.match(webApp, /collection\("user_notifications"\)/);
  assert.match(webApp, /markNotificationRead/);
});

test("remote push uses secret Cloud installations and audited delivery jobs", () => {
  const index = read("functions/index.js");
  const pushService = read("functions/src/push-notification-service.js");
  const notificationService = read(
    "functions/src/user-notification-service.js",
  );
  const appPushService = read("lib/services/push_notification_service.dart");
  const appState = read("lib/state/app_state.dart");
  const rules = read("firestore.rules");

  assert.match(index, /export const updatePushInstallation/);
  assert.match(index, /export const deliverPushNotification/);
  assert.match(index, /enforceAppCheck: true/);
  assert.match(pushService, /push_installations/);
  assert.match(pushService, /push_token_claims/);
  assert.match(pushService, /sendEachForMulticast/);
  assert.match(pushService, /notifications\.push\.deliver/);
  assert.match(notificationService, /buildPushDeliveryJob/);
  assert.match(appPushService, /onTokenRefresh/);
  assert.match(appPushService, /deleteToken/);
  assert.match(appState, /revokeForUser/);
  assert.match(rules, /match \/push_installations\/\{installationId\}/);
  assert.match(
    rules,
    /match \/push_delivery_state\/\{userId\}[\s\S]*allow write: if false/,
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
  assert.match(admin, /裝置推播註冊與投遞/);
  assert.doesNotMatch(admin, /mockAudit|demoAudit|假稽核/);
});
