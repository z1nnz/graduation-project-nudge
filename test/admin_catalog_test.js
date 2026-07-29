const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  buildAvatarSeriesPayload,
  validateAvatarSeriesDraft,
} = require("../web_dashboard/assets/admin_catalog.js");

test("admin payload publishes a complete codex chain and sells only stage one", () => {
  const draft = {
    name: "夜影學院",
    seriesKey: "night-shadow",
    theme: "深度專注",
    codexDescription: "在安靜專注中逐步成長的夜影角色。",
    price: 120,
    type: "event_character",
    status: "published",
    startTime: 100,
    endTime: 200,
    catalogIndexBase: 18,
    createdAt: 99,
    createdBy: "admin-1",
    stages: [
      {
        name: "夜影見習生",
        description: "系列起點。",
        requiredLevel: 1,
        requiredExperience: 0,
        characterAsset: "https://cdn.example.com/night-1.png",
        iconAsset: "https://cdn.example.com/night-1-icon.png",
      },
      {
        name: "夜輪行者",
        description: "第二階段。",
        requiredLevel: 30,
        requiredExperience: 10000,
        characterAsset: "https://cdn.example.com/night-2.png",
        iconAsset: "https://cdn.example.com/night-2-icon.png",
      },
      {
        name: "夜曜守護者",
        description: "最終階段。",
        requiredLevel: 60,
        requiredExperience: 30000,
        characterAsset: "https://cdn.example.com/night-3.png",
        iconAsset: "https://cdn.example.com/night-3-icon.png",
      },
    ],
  };

  assert.deepEqual(validateAvatarSeriesDraft(draft), []);

  const payload = buildAvatarSeriesPayload(draft);
  assert.equal(payload.schema_version, 1);
  assert.equal(payload.series_key, "night-shadow");
  assert.equal(payload.series_theme, "深度專注");
  assert.equal(payload.character_stages.length, 3);
  assert.deepEqual(
    payload.character_stages.map((stage) => stage.shop_eligible),
    [true, false, false],
  );
  assert.deepEqual(
    payload.character_stages.map((stage) => stage.coin_price),
    [120, 0, 0],
  );
  assert.deepEqual(
    payload.character_stages.map((stage) => stage.evolves_from_stage),
    [null, 1, 2],
  );
});

test("admin validation rejects incomplete or non-increasing evolution chains", () => {
  const errors = validateAvatarSeriesDraft({
    name: "錯誤角色",
    seriesKey: "broken",
    price: 50,
    stages: [
      {
        name: "初始型",
        requiredLevel: 1,
        requiredExperience: 0,
        characterAsset: "one",
        iconAsset: "one-icon",
      },
      {
        name: "第二階",
        requiredLevel: 1,
        requiredExperience: 0,
        characterAsset: "two",
        iconAsset: "two-icon",
      },
    ],
  });

  assert.ok(errors.some((message) => message.includes("3 階")));
  assert.ok(errors.some((message) => message.includes("遞增")));
  assert.ok(errors.some((message) => message.includes("圖鑑")));
});

test("admin catalog mutations use the audited Cloud command only", () => {
  const adminPage = fs.readFileSync(
    path.resolve(__dirname, "../web_dashboard/admin_dashboard.html"),
    "utf8",
  );
  const rules = fs.readFileSync(
    path.resolve(__dirname, "../firestore.rules"),
    "utf8",
  );

  assert.match(adminPage, /httpsCallable\('manageCatalogItem'\)/);
  assert.match(adminPage, /action: 'publish'/);
  assert.match(adminPage, /action: 'archive'/);
  assert.doesNotMatch(
    adminPage,
    /collection\(['"]shop_items['"]\)\.(?:add|doc\([^)]*\)\.update)/,
  );
  assert.doesNotMatch(
    adminPage,
    /collection\(['"]catalog_counters['"]\)[\s\S]{0,200}runTransaction/,
  );
  assert.match(
    rules,
    /match \/shop_items\/\{itemId\}[\s\S]*allow create, update, delete: if false;/,
  );
});
