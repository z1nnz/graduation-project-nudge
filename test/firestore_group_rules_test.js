const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore group rules integration test skipped: emulators are not enabled.",
  );
  process.exit(0);
}

const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";
const commitUrl =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents:commit";

function valueOf(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === "number") return { doubleValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(valueOf) } };
  }
  return { mapValue: { fields: fieldsOf(value) } };
}

function fieldsOf(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, valueOf(value)]),
  );
}

function documentName(path) {
  return `projects/${projectId}/databases/(default)/documents/${path}`;
}

async function signUp(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${label}-${Date.now()}@example.test`,
        password: "correct-horse-battery-staple",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

async function request(path, token, options = {}) {
  return fetch(`${firestoreBase}/${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });
}

async function createDoc(path, data, token) {
  return request(path, token, {
    method: "PATCH",
    body: JSON.stringify({ fields: fieldsOf(data) }),
  });
}

async function commit(writes, token) {
  return fetch(commitUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ writes }),
  });
}

function createWrite(path, data) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    currentDocument: { exists: false },
  };
}

function updateWrite(path, data, fieldPaths = Object.keys(data)) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    updateMask: { fieldPaths },
    currentDocument: { exists: true },
  };
}

function deleteWrite(path) {
  return {
    delete: documentName(path),
    currentDocument: { exists: true },
  };
}

function groupSummary(groupId, memberId, displayName, now) {
  return {
    schemaVersion: 1,
    groupId,
    memberId,
    displayName,
    status: "shared",
    summary: {
      disciplineScore: 82,
      completedTasks: 4,
      totalTasks: 5,
      focusMinutes: 60,
      steps: 8000,
      sleepHours: 7.5,
    },
    updatedAt: now,
  };
}

function publicProfile(userId, now) {
  const nudgeId = `NDG_${userId}`;
  return {
    schemaVersion: 1,
    userId,
    username: nudgeId,
    myNudgeId: nudgeId,
    nickname: "測試使用者",
    signature: "公開資料不含任務與健康明細",
    avatarProfile: {
      skinToneIndex: 0,
      faceShapeIndex: 0,
      hairStyleIndex: 0,
      hairColorIndex: 0,
      eyeStyleIndex: 0,
      eyebrowStyleIndex: 0,
      mouthStyleIndex: 0,
      outfitStyleIndex: 0,
      outfitColorIndex: 0,
      accessoryIndex: 0,
      backgroundColorIndex: 0,
      avatarIconIndex: 0,
    },
    accentColor: "purple",
    planetCount: 0,
    familyRole: "personal",
    profileTitleBadgeKey: "",
    unlockedBadgeDates: {},
    updatedAt: now,
  };
}

async function run() {
  const manager = await signUp("group-manager");
  const member = await signUp("group-member");
  const candidate = await signUp("group-candidate");
  const stranger = await signUp("group-stranger");
  const groupId = "GRP-CONSENT-RULE-TEST";
  const groupName = "同意制測試團";
  const now = "2026-07-27T00:00:00.000Z";

  for (const account of [manager, member, candidate, stranger]) {
    const response = await createDoc(
      `users/${account.localId}`,
      { username: `NDG_${account.localId}`, userRole: "individual" },
      account.idToken,
    );
    assert.equal(response.status, 200, await response.clone().text());
    const publicResponse = await createDoc(
      `public_profiles/${account.localId}`,
      publicProfile(account.localId, now),
      account.idToken,
    );
    assert.equal(
      publicResponse.status,
      200,
      await publicResponse.clone().text(),
    );
  }

  let response = await request(`users/${member.localId}`, member.idToken);
  assert.equal(response.status, 200, "A user can read their private record");

  response = await request(`users/${member.localId}`, stranger.idToken);
  assert.equal(
    response.status,
    403,
    "Another signed-in user cannot read raw private user data",
  );

  response = await request(
    `public_profiles/${member.localId}`,
    stranger.idToken,
  );
  assert.equal(
    response.status,
    200,
    "Signed-in users can read the explicit public profile projection",
  );

  response = await commit(
    [
      createWrite(`groups/${groupId}`, {
        id: groupId,
        name: groupName,
        ownerId: manager.localId,
        memberIds: [manager.localId],
        status: "active",
        createdAt: now,
        updatedAt: now,
      }),
      updateWrite(`users/${manager.localId}`, {
        groupId,
        groupName,
        isGroupOwner: true,
        userRole: "group",
        updatedAt: now,
      }),
    ],
    manager.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  for (const account of [member, candidate]) {
    response = await commit(
      [
        updateWrite(`groups/${groupId}`, {
          memberIds: [
            manager.localId,
            ...(account === candidate ? [member.localId] : []),
            account.localId,
          ],
          updatedAt: now,
        }),
        updateWrite(`users/${account.localId}`, {
          groupId,
          groupName,
          isGroupOwner: false,
          userRole: "group",
          updatedAt: now,
        }),
      ],
      account.idToken,
    );
    assert.equal(response.status, 200, await response.clone().text());
  }

  const summaryPath =
    `groups/${groupId}/member_summaries/${member.localId}`;
  response = await createDoc(
    summaryPath,
    groupSummary(groupId, member.localId, "成員小樹", now),
    member.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(summaryPath, manager.idToken);
  assert.equal(response.status, 200, "An active member can read shared results");

  response = await request(
    `groups/${groupId}/member_summaries`,
    manager.idToken,
  );
  assert.equal(
    response.status,
    200,
    "An active member can list consented summaries for the group UI",
  );

  response = await request(summaryPath, stranger.idToken);
  assert.equal(response.status, 403, "A stranger must not read group results");

  response = await createDoc(
    `groups/${groupId}/member_summaries/${candidate.localId}`,
    groupSummary(groupId, candidate.localId, "偽造摘要", now),
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A manager cannot publish a result summary for another member",
  );

  response = await request(summaryPath, manager.idToken, {
    method: "DELETE",
  });
  assert.equal(
    response.status,
    403,
    "A manager cannot revoke consent while the member remains active",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        memberIds: [manager.localId, candidate.localId],
        lastMembershipChange: {
          type: "member_removed",
          memberId: member.localId,
          by: manager.localId,
          at: now,
        },
        updatedAt: now,
      }),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Membership cannot change without clearing the user projection atomically",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        memberIds: [manager.localId, candidate.localId],
        lastMembershipChange: {
          type: "member_removed",
          memberId: member.localId,
          by: manager.localId,
          at: now,
        },
        updatedAt: now,
      }),
      updateWrite(
        `users/${member.localId}`,
        { userRole: "individual", updatedAt: now },
        [
          "groupId",
          "groupName",
          "isGroupOwner",
          "userRole",
          "updatedAt",
        ],
      ),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Membership cannot change while the consent snapshot remains",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        memberIds: [manager.localId, candidate.localId],
        lastMembershipChange: {
          type: "member_removed",
          memberId: member.localId,
          by: manager.localId,
          at: now,
        },
        updatedAt: now,
      }),
      updateWrite(
        `users/${member.localId}`,
        { userRole: "individual", updatedAt: now },
        [
          "groupId",
          "groupName",
          "isGroupOwner",
          "userRole",
          "updatedAt",
        ],
      ),
      deleteWrite(summaryPath),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    200,
    await response.clone().text(),
  );

  response = await request(summaryPath, manager.idToken);
  assert.equal(
    response.status,
    404,
    "The required atomic delete leaves no former-member summary",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        ownerId: candidate.localId,
        lastMembershipChange: {
          type: "ownership_transferred",
          fromMemberId: manager.localId,
          toMemberId: candidate.localId,
          by: manager.localId,
          at: now,
        },
        updatedAt: now,
      }),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Ownership cannot change without both user projections",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        ownerId: candidate.localId,
        lastMembershipChange: {
          type: "ownership_transferred",
          fromMemberId: manager.localId,
          toMemberId: candidate.localId,
          by: manager.localId,
          at: now,
        },
        updatedAt: now,
      }),
      updateWrite(`users/${manager.localId}`, {
        isGroupOwner: false,
        userRole: "group",
        updatedAt: now,
      }),
      updateWrite(`users/${candidate.localId}`, {
        isGroupOwner: true,
        userRole: "group",
        updatedAt: now,
      }),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    200,
    await response.clone().text(),
  );

  console.log("Firestore group rules integration test passed.");
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
