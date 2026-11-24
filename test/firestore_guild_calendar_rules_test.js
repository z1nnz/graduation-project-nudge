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
      body: JSON.stringify({ email: "guild-" + role + "-" + Date.now() + "@example.test",
        password: "integration-password", returnSecureToken: true }),
    });
    assert.equal(response.status, 200);
    return response.json();
  }
  function field(value) {
    if (value === null) return { nullValue: null };
    if (value instanceof Date) return { timestampValue: value.toISOString() };
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
  const roomId = "guild-rules-" + Date.now();
  const roomPath = "rooms/" + roomId;
  const groupId = "group-" + roomId;
  const group = { ownerId: owner.localId, memberIds: [owner.localId, guest.localId], status: "active" };
  const room = {
    schemaVersion: 2, id: roomId, ownerId: owner.localId, ownerName: "Host", name: "Library",
    description: "", memberIds: [owner.localId, guest.localId], visibility: "private", status: "active",
    joinMode: "approval", roomType: "study", goalSourceType: "focusMinutes", dailyGoalValue: 25,
    goalUnitLabel: "minutes", memberLimit: 50, voiceEnabled: true, updatedAt: now,
    guildGroupId: groupId, guildClosesAt: new Date(Date.now() + 60_000),
  };
  const guestMember = { schemaVersion: 1, roomId, memberId: guest.localId, displayName: "Guest",
    role: "member", approvalStatus: "approved", presenceStatus: "offline", sessionSeconds: 0,
    metricValue: 0, metricUnit: "minutes", activeSessionId: null, updatedAt: now };
  const message = roomPath + "/messages/entry";
  const attendance = "guild_event_attendance/" + roomId;
  assert.equal((await commit("owner", update("groups/" + groupId, group), update(roomPath, room),
    update(roomPath + "/members/" + guest.localId, guestMember),
    update(message, { senderId: owner.localId, text: "Welcome", createdAt: now }),
    update(attendance, { userId: guest.localId, groupId, status: "going" }))).status, 200);
  assert.equal((await get(guest.idToken, message)).status, 200);
  assert.equal((await get(outsider.idToken, message)).status, 403);
  assert.equal((await get(owner.idToken, attendance)).status, 403);
  assert.equal((await get(guest.idToken, attendance)).status, 403);
  assert.equal((await commit(guest.idToken, update(attendance, { userId: guest.localId, groupId, status: "going" }))).status, 403);
  assert.equal((await commit(owner.idToken, update(roomPath, { ...room, guildClosesAt: new Date(Date.now() + 600_000) }))).status, 403);
  assert.equal((await commit("owner", update("groups/" + groupId, { ...group, memberIds: [owner.localId] }))).status, 200);
  assert.equal((await get(guest.idToken, message)).status, 403);
  assert.equal((await commit("owner", update("groups/" + groupId, group),
    update(roomPath, { ...room, guildClosesAt: new Date(Date.now() - 60_000) }))).status, 200);
  assert.equal((await get(guest.idToken, message)).status, 403);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
