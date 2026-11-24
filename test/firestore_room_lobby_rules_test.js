const assert = require("node:assert/strict");
const project = "nudge-discipline-app";

async function main() {
  const auth = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestore = process.env.FIRESTORE_EMULATOR_HOST;
  if (!auth || !firestore) return;
  const root = "projects/" + project + "/databases/(default)/documents";
  const base = "http://" + firestore + "/v1/" + root;

  async function user(role) {
    const response = await fetch("http://" + auth + "/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "lobby-" + role + "-" + Date.now() + "@example.test",
        password: "integration-password", returnSecureToken: true }),
    });
    assert.equal(response.status, 200);
    return response.json();
  }
  function field(value) {
    if (value === null) return { nullValue: null };
    if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
    if (typeof value === "number") return { integerValue: String(value) };
    if (typeof value === "boolean") return { booleanValue: value };
    return { stringValue: value };
  }
  function update(path, data) {
    return { update: { name: root + "/" + path,
      fields: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, field(value)])) } };
  }
  function commit(token, ...writes) {
    return fetch(base + ":commit", { method: "POST",
      headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" },
      body: JSON.stringify({ writes }) });
  }
  function get(token, path) {
    return fetch(base + "/" + path, { headers: { Authorization: "Bearer " + token } });
  }

  const [owner, guest, outsider] = await Promise.all([user("owner"), user("guest"), user("outsider")]);
  const now = new Date().toISOString();
  const roomId = "lobby-rules-" + Date.now();
  const roomPath = "rooms/" + roomId;
  const room = {
    schemaVersion: 2, id: roomId, ownerId: owner.localId, ownerName: "Host", name: "Library",
    description: "", memberIds: [owner.localId], visibility: "public", status: "active",
    joinMode: "approval", roomType: "study", goalSourceType: "focusMinutes", dailyGoalValue: 25,
    goalUnitLabel: "minutes", memberLimit: 8, voiceEnabled: false, updatedAt: now,
    lobbyManaged: true, joinQuestion: "When?", theme: "library", tags: ["study"],
  };
  const guestMember = { schemaVersion: 1, roomId, memberId: guest.localId, displayName: "Guest",
    role: "member", approvalStatus: "pending", presenceStatus: "offline", sessionSeconds: 0,
    metricValue: 0, metricUnit: "minutes", activeSessionId: null, updatedAt: now };
  const answerPath = "room_lobby_answers/" + roomId;
  const invitePath = "room_lobby_codes/" + roomId;
  assert.equal((await commit("owner", update(roomPath, room),
    update(answerPath, { roomId, memberId: guest.localId, answer: "Evening" }),
    update(invitePath, { roomId, ownerId: owner.localId, expiresAt: now }))).status, 200);
  assert.equal((await commit(guest.idToken, update(roomPath, { ...room, memberIds: [...room.memberIds, guest.localId] }),
    update(roomPath + "/members/" + guest.localId, guestMember))).status, 403);
  assert.equal((await commit(owner.idToken, update(roomPath, { ...room, memberLimit: 9 }))).status, 403);
  assert.equal((await commit(owner.idToken, update(roomPath, { ...room, joinQuestion: "" }))).status, 403);
  assert.equal((await get(owner.idToken, answerPath)).status, 200);
  assert.equal((await get(guest.idToken, answerPath)).status, 200);
  assert.equal((await get(outsider.idToken, answerPath)).status, 403);
  assert.equal((await get(owner.idToken, invitePath)).status, 403);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
