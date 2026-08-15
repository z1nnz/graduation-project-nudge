const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const contract = require(
  "../web_dashboard/assets/discipline_identity_contract.js"
);

function snapshot(overrides = {}) {
  return {
    schemaVersion: 1,
    snapshotId: "user-1",
    userId: "user-1",
    visibility: "private",
    window: {
      days: 28,
      startedAt: "2026-07-18T21:00:00.000Z",
      endedAt: "2026-08-15T10:00:00.000Z",
    },
    persona: {
      key: "comeback_builder",
      title: "復原建築師",
      description: "中斷後仍願意重新開始。",
    },
    recovery: {
      state: "returning",
      recommendedFocusMinutes: 15,
      message: "今天再完成一個小段落就足夠。",
    },
    metrics: {
      activeDays: 4,
      completedSessions: 7,
      focusMinutes: 120,
      exerciseMinutes: 30,
      activityKinds: ["exercise", "focus"],
      lastActiveDay: "2026-08-15",
    },
    updatedAt: "2026-08-15T10:00:00.000Z",
    ...overrides,
  };
}

test("Web parses the same private Cloud discipline identity", () => {
  const parsed = contract.parseDisciplineIdentity("user-1", snapshot());
  assert.equal(parsed.persona.key, "comeback_builder");
  assert.equal(parsed.recovery.recommendedFocusMinutes, 15);
});

test("Web rejects cross-account or non-private identity snapshots", () => {
  assert.throws(
    () => contract.parseDisciplineIdentity("other-user", snapshot()),
    /格式或帳號不一致/,
  );
  assert.throws(
    () => contract.parseDisciplineIdentity(
      "user-1",
      snapshot({ visibility: "summary" }),
    ),
    /格式或帳號不一致/,
  );
});

test("Web rejects impossible recovery and metric values", () => {
  assert.throws(
    () => contract.parseDisciplineIdentity(
      "user-1",
      snapshot({
        recovery: {
          state: "returning",
          recommendedFocusMinutes: 0,
          message: "",
        },
      }),
    ),
    /格式或帳號不一致/,
  );
  assert.throws(
    () => contract.parseDisciplineIdentity(
      "user-1",
      snapshot({
        metrics: {
          activeDays: 29,
          completedSessions: 7,
          focusMinutes: 120,
          exerciseMinutes: 30,
          activityKinds: ["focus"],
          lastActiveDay: "2026-08-15",
        },
      }),
    ),
    /格式或帳號不一致/,
  );
});

test("Web identity page uses the Cloud snapshot and canonical focus flow", () => {
  const root = path.resolve(__dirname, "..");
  const app = fs.readFileSync(
    path.join(root, "web_dashboard/assets/app.js"),
    "utf8",
  );
  const page = fs.readFileSync(
    path.join(root, "web_dashboard/personal-identity.html"),
    "utf8",
  );
  const hub = fs.readFileSync(
    path.join(root, "web_dashboard/personal.html"),
    "utf8",
  );

  assert.match(app, /collection\("discipline_identity_snapshots"\)/);
  assert.match(app, /httpsCallable\("refreshDisciplineIdentity"\)/);
  assert.match(app, /personal-focus\.html\?focus=/);
  assert.match(page, /data-page="personal-identity"/);
  assert.match(page, /canonical Activity Ledger/);
  assert.match(hub, /href="personal-identity\.html"/);
});
