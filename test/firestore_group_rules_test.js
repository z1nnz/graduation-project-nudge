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

function relationshipMembership({
  scopeType = "group",
  scopeId,
  scopeName,
  userId,
  role,
  status = "active",
  now,
  endedBy,
}) {
  const membershipId = `${scopeType}--${scopeId}--${userId}`;
  return {
    schemaVersion: 1,
    membershipId,
    scopeType,
    scopeId,
    scopeName,
    userId,
    role,
    status,
    createdAt: now,
    updatedAt: now,
    ...(status === "active" ? { activeFrom: now } : {}),
    ...(status === "ended"
      ? { activeUntil: now, endedBy: endedBy || userId }
      : {}),
  };
}

function groupChallenge(groupId, groupName, managerId, challengeId, now) {
  return {
    schemaVersion: 2,
    challengeId,
    groupId,
    groupName,
    type: "步數挑戰",
    days: 3,
    reward: "限定徽章",
    status: "active",
    publishedBy: managerId,
    updatedAt: now,
  };
}

function challengeParticipation(
  groupId,
  challengeId,
  memberId,
  completedDays,
  now,
) {
  return {
    schemaVersion: 1,
    groupId,
    challengeId,
    memberId,
    status: completedDays === 3 ? "completed" : "joined",
    completedDays,
    totalDays: 3,
    joinedAt: now,
    updatedAt: now,
    ...(completedDays === 3 ? { completedAt: now } : {}),
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

  response = await commit(
    [
      updateWrite(`users/${member.localId}`, {
        groupId: "LEGACY-GROUP",
        groupName: "舊版單一團體",
        isGroupOwner: false,
        updatedAt: now,
      }),
    ],
    member.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A client cannot recreate the retired single-group user projection",
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
      createWrite(
        `relationship_memberships/group--${groupId}--${manager.localId}`,
        relationshipMembership({
          scopeId: groupId,
          scopeName: groupName,
          userId: manager.localId,
          role: "manager",
          now,
        }),
      ),
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
        createWrite(
          `relationship_memberships/group--${groupId}--${account.localId}`,
          relationshipMembership({
            scopeId: groupId,
            scopeName: groupName,
            userId: account.localId,
            role: "member",
            now,
          }),
        ),
      ],
      account.idToken,
    );
    assert.equal(response.status, 200, await response.clone().text());
  }

  response = await request(
    `relationship_memberships/group--${groupId}--${member.localId}`,
    manager.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A group manager can inspect a member's scoped role",
  );

  response = await createDoc(
    `relationship_memberships/group--${groupId}--${stranger.localId}`,
    relationshipMembership({
      scopeId: groupId,
      scopeName: groupName,
      userId: stranger.localId,
      role: "member",
      now,
    }),
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A non-member cannot forge an active group membership",
  );

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

  const challengeId = "challenge-20260727";
  const challengePath = `groups/${groupId}/challenges/current`;
  response = await createDoc(
    challengePath,
    groupChallenge(
      groupId,
      groupName,
      manager.localId,
      challengeId,
      now,
    ),
    manager.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  const participationPath =
    `${challengePath}/participants/${member.localId}`;
  response = await createDoc(
    participationPath,
    challengeParticipation(groupId, challengeId, member.localId, 0, now),
    member.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A member can explicitly join the current challenge",
  );

  response = await createDoc(
    `${challengePath}/participants/${candidate.localId}`,
    challengeParticipation(groupId, challengeId, candidate.localId, 0, now),
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A manager cannot opt another member into a challenge",
  );

  response = await createDoc(
    participationPath,
    challengeParticipation(groupId, challengeId, member.localId, 2, now),
    member.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A member can update progress for their own participation",
  );

  const invalidParticipation = challengeParticipation(
    groupId,
    challengeId,
    member.localId,
    2,
    now,
  );
  delete invalidParticipation.updatedAt;
  response = await createDoc(
    participationPath,
    invalidParticipation,
    member.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Participation timestamps are required by the shared contract",
  );

  response = await createDoc(
    participationPath,
    {
      ...challengeParticipation(
        groupId,
        challengeId,
        member.localId,
        3,
        now,
      ),
      memberId: candidate.localId,
    },
    member.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A member cannot publish challenge progress for another account",
  );

  response = await request(
    `${challengePath}/participants`,
    manager.idToken,
  );
  assert.equal(
    response.status,
    200,
    "The manager can read aggregate participation in the active group",
  );

  const nextChallengeId = "challenge-20260728";
  response = await createDoc(
    challengePath,
    groupChallenge(
      groupId,
      groupName,
      manager.localId,
      nextChallengeId,
      "2026-07-28T00:00:00.000Z",
    ),
    manager.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    participationPath,
    challengeParticipation(
      groupId,
      nextChallengeId,
      member.localId,
      0,
      "2026-07-28T00:00:00.000Z",
    ),
    member.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A member can join a newly published challenge after an earlier round",
  );

  response = await createDoc(
    participationPath,
    {
      ...challengeParticipation(
        groupId,
        nextChallengeId,
        member.localId,
        3,
        "2026-07-30T00:00:00.000Z",
      ),
      joinedAt: "2026-07-28T00:00:00.000Z",
    },
    member.idToken,
  );
  assert.equal(response.status, 200, "A member can complete their own round");

  response = await request(participationPath, member.idToken, {
    method: "DELETE",
  });
  assert.equal(
    response.status,
    403,
    "A completed challenge cannot be deleted and restarted",
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
    "Membership cannot change without ending the formal membership",
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
      deleteWrite(summaryPath),
    ],
    manager.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Membership cannot change while challenge participation remains",
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
      deleteWrite(summaryPath),
      deleteWrite(participationPath),
      updateWrite(
        `relationship_memberships/group--${groupId}--${member.localId}`,
        relationshipMembership({
          scopeId: groupId,
          scopeName: groupName,
          userId: member.localId,
          role: "member",
          status: "ended",
          now,
          endedBy: manager.localId,
        }),
      ),
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
    "Ownership cannot change without both formal membership roles",
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
      updateWrite(
        `relationship_memberships/group--${groupId}--${manager.localId}`,
        {
          role: "member",
          status: "active",
          activeFrom: now,
          updatedAt: now,
        },
      ),
      updateWrite(
        `relationship_memberships/group--${groupId}--${candidate.localId}`,
        {
          role: "manager",
          status: "active",
          activeFrom: now,
          updatedAt: now,
        },
      ),
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
