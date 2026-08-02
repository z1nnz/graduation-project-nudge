const test = require("node:test");
const assert = require("node:assert/strict");

const contract = require(
  "../web_dashboard/assets/relationship_membership_contract.js"
);

function membership(overrides = {}) {
  return {
    schemaVersion: 1,
    membershipId: "group--group-1--user-1",
    scopeType: "group",
    scopeId: "group-1",
    scopeName: "晨光讀書會",
    userId: "user-1",
    role: "member",
    status: "active",
    ...overrides,
  };
}

test("Web formal Membership parser binds document identity and role scope", () => {
  const parsed = contract.parse(
    "group--group-1--user-1",
    membership(),
    "user-1",
  );

  assert.equal(parsed.role, "member");
  assert.throws(
    () => contract.parse(
      "group--group-1--user-1",
      membership({ role: "guardian" }),
      "user-1",
    ),
    /角色不一致/,
  );
  assert.throws(
    () => contract.parse(
      "group--group-1--user-1",
      membership(),
      "another-user",
    ),
    /角色不一致/,
  );
});

test("Web parents are available only through an active formal Membership", () => {
  const active = contract.parse(
    "group--group-1--user-1",
    membership(),
    "user-1",
  );
  const ended = contract.parse(
    "group--group-2--user-1",
    membership({
      membershipId: "group--group-2--user-1",
      scopeId: "group-2",
      scopeName: "舊團體",
      status: "ended",
    }),
    "user-1",
  );

  assert.deepEqual(
    contract.filterParents(
      [{ id: "group-1" }, { id: "group-2" }],
      [active, ended],
      "group",
      "user-1",
    ),
    [{ id: "group-1" }],
  );
});
