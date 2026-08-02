const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("formal rewards are Cloud-written and client reward projections are protected", () => {
  const service = read("functions/src/activity-ledger-service.js");
  const store = read("functions/src/firestore-activity-ledger-store.js");
  const rules = read("firestore.rules");
  const appState = read("lib/state/app_state.dart");
  const webShop = read("web_dashboard/operations.html");
  const functionsIndex = read("functions/index.js");
  const deletionRepository = read(
    "functions/src/firestore-account-deletion-repository.js",
  );
  const privacyExport = read("functions/src/privacy-data-request-service.js");
  const rewardMigration = read("scripts/migrate_reward_ledger_baselines.js");

  assert.match(service, /REWARD_POLICY_VERSION/);
  assert.match(service, /prepareRewardSettlement/);
  assert.match(service, /existingSession\.lifecycleStarted !== true/);
  assert.match(service, /"1970-01-01"/);
  assert.match(store, /reward_ledger_entries/);
  assert.match(rules, /function changesProtectedRewardFields/);
  assert.match(
    rules,
    /match \/reward_ledger_entries\/\{rewardEntryId\}[\s\S]*allow write: if false/,
  );
  assert.doesNotMatch(
    appState,
    /Future<void> syncDataToFirestore\(\)[\s\S]*?'disciplineCoins': _disciplineCoins[\s\S]*?^  }/m,
  );
  assert.match(functionsIndex, /export const purchaseRewardItem/);
  assert.match(functionsIndex, /export const equipRewardAvatar/);
  assert.match(rules, /'rewardLedgerBaselineVersion'/);
  assert.match(rewardMigration, /entryType: "migration_baseline"/);
  assert.doesNotMatch(
    appState,
    /Future<void> syncDataToFirestore\(\)[\s\S]*?'avatarProfile': _avatarProfile\.toJson\(\)[\s\S]*?^  }/m,
  );
  assert.match(appState, /_rewardAvatarGateway\.equip/);
  assert.match(webShop, /httpsCallable\('purchaseRewardItem'\)/);
  assert.match(webShop, /collection\('shop_items'\)/);
  assert.doesNotMatch(webShop, /mockShopItems|兌換成功！已將/);
  assert.match(deletionRepository, /\["reward_ledger_entries", "actorUserId"\]/);
  assert.match(
    deletionRepository,
    /\["reward_migration_before_images", "actorUserId"\]/,
  );
  assert.match(privacyExport, /reward_ledger_entries/);
  assert.match(privacyExport, /reward_migration_before_images/);
});
