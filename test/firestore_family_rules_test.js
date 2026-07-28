const assert = require("node:assert/strict");

const projectId = "nudge-discipline-app";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

if (!firestoreHost || !authHost) {
  console.log(
    "Firestore family rules integration test skipped: emulators are not enabled.",
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

function updateWrite(path, data) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    updateMask: { fieldPaths: Object.keys(data) },
    currentDocument: { exists: true },
  };
}

function replaceWrite(path, data) {
  return {
    update: { name: documentName(path), fields: fieldsOf(data) },
    currentDocument: { exists: true },
  };
}

function familyMembership(linkId, userId, role, status, now, endedBy) {
  const membershipId = `family--${linkId}--${userId}`;
  return {
    schemaVersion: 1,
    membershipId,
    scopeType: "family",
    scopeId: linkId,
    scopeName: `家庭連結 ${linkId.slice(-8)}`,
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

function groupMembership(groupId, groupName, userId, role, now) {
  const membershipId = `group--${groupId}--${userId}`;
  return {
    schemaVersion: 1,
    membershipId,
    scopeType: "group",
    scopeId: groupId,
    scopeName: groupName,
    userId,
    role,
    status: "active",
    createdAt: now,
    updatedAt: now,
    activeFrom: now,
  };
}

async function run() {
  const guardian = await signUp("guardian");
  const child = await signUp("child");
  const stranger = await signUp("stranger");
  const now = "2026-07-27T00:00:00.000Z";

  for (const [account, role] of [
    [guardian, "guardian"],
    [child, "child"],
    [stranger, "personal"],
  ]) {
    const response = await createDoc(
      `users/${account.localId}`,
      { username: `NDG_${account.localId}`, userRole: role },
      account.idToken,
    );
    assert.equal(response.status, 200, await response.clone().text());
  }

  const requestId = "family-rule-test";
  const requestData = {
    senderId: guardian.localId,
    senderNudgeId: `NDG_${guardian.localId}`,
    senderNickname: "Guardian",
    senderRole: "guardian",
    receiverId: child.localId,
    receiverNudgeId: `NDG_${child.localId}`,
    receiverRole: "child",
    status: "pending",
    createdAt: now,
    updatedAt: now,
  };
  let response = await createDoc(
    `guardian_requests/${requestId}`,
    requestData,
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  const linkData = {
    schemaVersion: 1,
    guardianId: guardian.localId,
    childId: child.localId,
    participantIds: [guardian.localId, child.localId],
    status: "active",
    consentScopes: {
      summary: false,
      weeklyReport: false,
      taskCategories: false,
      healthTrends: false,
    },
    createdAt: now,
    updatedAt: now,
  };
  response = await commit(
    [
      updateWrite(`guardian_requests/${requestId}`, {
        status: "accepted",
        updatedAt: now,
      }),
      createWrite(`family_links/${requestId}`, linkData),
      createWrite(
        `relationship_memberships/family--${requestId}--${guardian.localId}`,
        familyMembership(
          requestId,
          guardian.localId,
          "guardian",
          "active",
          now,
        ),
      ),
      createWrite(
        `relationship_memberships/family--${requestId}--${child.localId}`,
        familyMembership(requestId, child.localId, "child", "active", now),
      ),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(
    `relationship_memberships/family--${requestId}--${child.localId}`,
    guardian.idToken,
  );
  assert.equal(
    response.status,
    200,
    "A family participant can read the other scoped role",
  );

  response = await request(
    `relationship_memberships/family--${requestId}--${child.localId}`,
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A stranger cannot read a private family membership",
  );

  response = await request(
    `family_links/${requestId}`,
    stranger.idToken,
  );
  assert.equal(response.status, 403, "A stranger must not read a family link");

  response = await createDoc(
    `family_links/${requestId}/summaries/current`,
    {
      schemaVersion: 1,
      childId: child.localId,
      summary: {
        disciplineScore: 82,
        completedTasks: 4,
        totalTasks: 5,
        focusMinutes: 45,
      },
      updatedAt: now,
    },
    child.idToken,
  );
  assert.equal(
    response.status,
    403,
    "No summary data is shared before the child explicitly opts in",
  );

  response = await commit(
    [
      updateWrite(`family_links/${requestId}`, {
        consentScopes: {
          summary: true,
          weeklyReport: true,
          taskCategories: false,
          healthTrends: false,
        },
        updatedAt: now,
      }),
    ],
    guardian.idToken,
  );
  assert.equal(response.status, 403, "A guardian must not change child consent");

  response = await commit(
    [
      updateWrite(`family_links/${requestId}`, {
        consentScopes: {
          summary: true,
          weeklyReport: true,
          taskCategories: false,
          healthTrends: false,
        },
        updatedAt: now,
      }),
      createWrite(`family_links/${requestId}/summaries/current`, {
        schemaVersion: 1,
        childId: child.localId,
        summary: {
          disciplineScore: 82,
          completedTasks: 4,
          totalTasks: 5,
          focusMinutes: 45,
        },
        weeklyReport: [],
        updatedAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(`family_links/${requestId}/summaries/current`, {
        summary: {
          disciplineScore: 100,
          completedTasks: 99,
          totalTasks: 99,
          focusMinutes: 999,
        },
        updatedAt: now,
      }),
    ],
    guardian.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A guardian must not forge the child's shared summary",
  );

  const revokedConsent = {
    summary: false,
    weeklyReport: false,
    taskCategories: false,
    healthTrends: false,
  };
  response = await commit(
    [
      updateWrite(`family_links/${requestId}`, {
        consentScopes: revokedConsent,
        updatedAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Consent revocation must also remove the previously shared fields",
  );

  response = await commit(
    [
      updateWrite(`family_links/${requestId}`, {
        consentScopes: revokedConsent,
        updatedAt: now,
      }),
      replaceWrite(`family_links/${requestId}/summaries/current`, {
        schemaVersion: 1,
        childId: child.localId,
        updatedAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(
    `family_links/${requestId}/summaries/current`,
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());
  const revokedSummary = await response.json();
  assert.equal(
    Object.hasOwn(revokedSummary.fields, "summary"),
    false,
    "A guardian must not receive a revoked daily summary",
  );
  assert.equal(
    Object.hasOwn(revokedSummary.fields, "weeklyReport"),
    false,
    "A guardian must not receive a revoked weekly report",
  );

  const cardId = "card-1";
  response = await createDoc(
    `family_links/${requestId}/encouragements/${cardId}`,
    {
      schemaVersion: 1,
      senderId: guardian.localId,
      recipientId: child.localId,
      title: "今天也辛苦了",
      message: "慢慢來就好",
      status: "sent",
      createdAt: now,
    },
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(
        `family_links/${requestId}/encouragements/${cardId}`,
        { status: "acknowledged", acknowledgedAt: now },
      ),
      createWrite(
        `family_links/${requestId}/bond_events/encouragement_${cardId}`,
        {
          schemaVersion: 1,
          type: "acknowledgement",
          sourceId: cardId,
          actorId: child.localId,
          points: 3,
          createdAt: now,
        },
      ),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    `family_links/${requestId}/bond_events/fake`,
    {
      schemaVersion: 1,
      type: "acknowledgement",
      sourceId: cardId,
      actorId: guardian.localId,
      points: 999,
      createdAt: now,
    },
    guardian.idToken,
  );
  assert.equal(response.status, 403, "A guardian must not mint Family Bond XP");

  const goalId = "goal-1";
  response = await createDoc(
    `family_links/${requestId}/goals/${goalId}`,
    {
      schemaVersion: 1,
      title: "每天專注 30 分鐘",
      message: "我們一起慢慢建立節奏",
      status: "proposed",
      proposedBy: guardian.localId,
      decisionBy: child.localId,
      createdAt: now,
      updatedAt: now,
    },
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(`family_links/${requestId}/goals/${goalId}`, {
        status: "accepted",
        acceptedAt: now,
        updatedAt: now,
      }),
    ],
    guardian.idToken,
  );
  assert.equal(response.status, 403, "A guardian must not accept their proposal");

  response = await commit(
    [
      updateWrite(`family_links/${requestId}/goals/${goalId}`, {
        status: "accepted",
        acceptedAt: now,
        updatedAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(`family_links/${requestId}/goals/${goalId}`, {
        status: "completed",
        completedAt: now,
        updatedAt: now,
      }),
      createWrite(`family_links/${requestId}/bond_events/goal_${goalId}`, {
        schemaVersion: 1,
        type: "goalCompleted",
        sourceId: goalId,
        actorId: child.localId,
        points: 10,
        createdAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(`family_links/${requestId}`, {
        status: "ended",
        endedBy: guardian.localId,
        endedAt: now,
        updatedAt: now,
      }),
      updateWrite(`guardian_requests/${requestId}`, {
        status: "ended",
        updatedAt: now,
      }),
      updateWrite(
        `relationship_memberships/family--${requestId}--${guardian.localId}`,
        familyMembership(
          requestId,
          guardian.localId,
          "guardian",
          "ended",
          now,
          guardian.localId,
        ),
      ),
      updateWrite(
        `relationship_memberships/family--${requestId}--${child.localId}`,
        familyMembership(
          requestId,
          child.localId,
          "child",
          "ended",
          now,
          guardian.localId,
        ),
      ),
    ],
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    `family_links/${requestId}/encouragements/card-after-end`,
    {
      schemaVersion: 1,
      senderId: guardian.localId,
      recipientId: child.localId,
      title: "連結已結束",
      message: "",
      status: "sent",
      createdAt: now,
    },
    guardian.idToken,
  );
  assert.equal(
    response.status,
    403,
    "An ended family link must reject new interactions",
  );

  const groupId = "GRP-RULE-TEST";
  const groupData = {
    id: groupId,
    name: "自律同行團",
    ownerId: guardian.localId,
    memberIds: [guardian.localId],
    status: "active",
    createdAt: now,
    updatedAt: now,
  };
  response = await commit(
    [
      createWrite(`groups/${groupId}`, groupData),
      createWrite(
        `relationship_memberships/group--${groupId}--${guardian.localId}`,
        groupMembership(
          groupId,
          groupData.name,
          guardian.localId,
          "manager",
          now,
        ),
      ),
      updateWrite(`users/${guardian.localId}`, {
        groupId,
        groupName: groupData.name,
        isGroupOwner: true,
        userRole: "group",
      }),
    ],
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  const groupRequestId = "group-invite-test";
  response = await createDoc(
    `group_requests/${groupRequestId}`,
    {
      senderId: guardian.localId,
      senderNudgeId: `NDG_${guardian.localId}`,
      senderNickname: "Guardian",
      receiverId: child.localId,
      groupId,
      groupName: groupData.name,
      status: "pending",
      createdAt: now,
    },
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await commit(
    [
      updateWrite(`group_requests/${groupRequestId}`, {
        status: "accepted",
        updatedAt: now,
      }),
      createWrite(
        `relationship_memberships/group--${groupId}--${child.localId}`,
        groupMembership(
          groupId,
          groupData.name,
          child.localId,
          "member",
          now,
        ),
      ),
    ],
    child.idToken,
  );
  assert.equal(
    response.status,
    403,
    "Accepting a group request must atomically create canonical membership",
  );

  response = await commit(
    [
      updateWrite(`groups/${groupId}`, {
        memberIds: [guardian.localId, child.localId],
        updatedAt: now,
      }),
      updateWrite(`users/${child.localId}`, {
        groupId,
        groupName: groupData.name,
        isGroupOwner: false,
        userRole: "group",
      }),
      createWrite(
        `relationship_memberships/group--${groupId}--${child.localId}`,
        groupMembership(
          groupId,
          groupData.name,
          child.localId,
          "member",
          now,
        ),
      ),
      updateWrite(`group_requests/${groupRequestId}`, {
        status: "accepted",
        updatedAt: now,
      }),
    ],
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  const challengeData = {
    schemaVersion: 2,
    challengeId: "challenge-family-role-composition",
    groupId,
    groupName: groupData.name,
    type: "步數挑戰",
    days: 7,
    reward: "限定徽章",
    status: "active",
    publishedBy: guardian.localId,
    updatedAt: now,
  };
  response = await createDoc(
    `groups/${groupId}/challenges/current`,
    challengeData,
    guardian.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await request(
    `groups/${groupId}/challenges/current`,
    child.idToken,
  );
  assert.equal(response.status, 200, await response.clone().text());

  response = await createDoc(
    `groups/${groupId}/study_schedules/member-write`,
    {
      schemaVersion: 1,
      groupId,
      title: "成員不能發布",
      meta: "由自己安排活動",
      status: "scheduled",
      publishedBy: child.localId,
      createdAt: now,
    },
    child.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A group member must not publish manager content",
  );

  response = await request(
    `groups/${groupId}/challenges/current`,
    stranger.idToken,
  );
  assert.equal(
    response.status,
    403,
    "A non-member must not read group publications",
  );
}

run()
  .then(() => {
    console.log("Firestore family rules integration test passed.");
  })
  .catch(error => {
    console.error(error);
    process.exitCode = 1;
  });
