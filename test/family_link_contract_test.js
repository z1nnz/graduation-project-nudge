const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  FamilyBondPolicy,
  buildEncouragementPayload,
  buildFamilyLinkPayload,
  buildSharedGoalPayload,
} = require("../web_dashboard/assets/family_link_contract.js");

const cases = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, "fixtures/family_link_contract_cases.json"),
    "utf8",
  ),
);

for (const testCase of cases) {
  test(testCase.name, () => {
    const build = () =>
      buildFamilyLinkPayload({
        senderId: testCase.senderId,
        senderRole: testCase.senderRole,
        receiverId: testCase.receiverId,
        receiverRole: testCase.receiverRole,
        now: "2026-07-27T00:00:00.000Z",
      });

    if (!testCase.valid) {
      assert.throws(build, /guardian and one child/);
      return;
    }

    const payload = build();
    assert.equal(payload.guardianId, testCase.guardianId);
    assert.equal(payload.childId, testCase.childId);
    assert.deepEqual(payload.participantIds.sort(), [
      testCase.childId,
      testCase.guardianId,
    ].sort());
    assert.equal(payload.status, "active");
    assert.equal(payload.consentScopes.summary, false);
    assert.equal(payload.consentScopes.healthTrends, false);
  });
}

test("encouragement targets the child without personal rewards", () => {
  const payload = buildEncouragementPayload({
    guardianId: "guardian-1",
    childId: "child-1",
    title: "今天也辛苦了",
    message: "先休息也沒關係",
    now: "2026-07-27T12:00:00.000Z",
  });

  assert.equal(payload.senderId, "guardian-1");
  assert.equal(payload.recipientId, "child-1");
  assert.equal(payload.status, "sent");
  assert.equal("disciplineCoins" in payload, false);
  assert.equal("avatarExperience" in payload, false);
});

test("shared goals need a child decision", () => {
  const payload = buildSharedGoalPayload({
    guardianId: "guardian-1",
    childId: "child-1",
    title: "每天專注 30 分鐘",
    message: "我們一起慢慢建立節奏",
    now: "2026-07-27T12:00:00.000Z",
  });

  assert.equal(payload.status, "proposed");
  assert.equal(payload.proposedBy, "guardian-1");
  assert.equal(payload.decisionBy, "child-1");
});

test("bond growth rewards two-way interaction", () => {
  assert.equal(FamilyBondPolicy.pointsFor("acknowledgement"), 3);
  assert.equal(FamilyBondPolicy.pointsFor("goalCompleted"), 10);
  assert.equal(FamilyBondPolicy.levelForXp(0), 1);
  assert.equal(FamilyBondPolicy.levelForXp(12), 2);
  assert.equal(FamilyBondPolicy.levelForXp(30), 3);
});
