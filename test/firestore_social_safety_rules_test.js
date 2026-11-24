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
      body: JSON.stringify({ email: "safety-" + role + "-" + Date.now() + "@example.test",
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

  const [owner, child, peer, outsider] = await Promise.all(["owner", "child", "peer", "outsider"].map(user));
  const now = new Date().toISOString();
  const roomId = "safety-rules-" + Date.now();
  const room = "rooms/" + roomId;
  const pathFor = actor => "social_safety/" + actor.localId;
  const member = actor => update(room + "/members/" + actor.localId, {
    roomId, memberId: actor.localId, displayName: actor.email, approvalStatus: "approved", role: "member",
  });
  const messagePath = actor => room + "/messages/msg-" + actor.localId;
  const message = actor => update(messagePath(actor), {
    id: "msg-" + actor.localId, roomId, senderId: actor.localId, senderName: actor.email,
    type: "text", text: "Hello", createdAt: now,
  });
  async function send(actor, id, mention) {
    const outgoing = update(room + "/messages/" + id, {
      id, roomId, senderId: actor.localId, senderName: actor.email, type: "text", text: "Hello", createdAt: now,
      ...(mention ? { mentionUid: mention.localId } : {}),
    });
    const throttle = update(room + "/chat_throttles/" + actor.localId,
      { userId: actor.localId, messageId: id, t0: null, t1: null, t2: null, t3: null });
    throttle.updateTransforms = [{ fieldPath: "t4", setToServerValue: "REQUEST_TIME" }];
    return commit(actor.idToken, outgoing, throttle);
  }

  assert.equal((await commit("owner",
    update(room, { id: roomId, ownerId: owner.localId, memberIds: [owner.localId, child.localId, peer.localId],
      status: "active", visibility: "private", voiceEnabled: true }),
    ...[owner, child, peer, outsider].map(actor => update("users/" + actor.localId, { displayName: actor.email })),
    ...[owner, child, peer].map(member),
    message(owner), message(child), message(peer),
    update("users/" + owner.localId + "/friends/" + peer.localId, { id: peer.localId }),
    update("users/" + peer.localId + "/friends/" + owner.localId, { id: owner.localId }),
    update("friend_requests/req_" + owner.localId + "_" + peer.localId,
      { senderId: owner.localId, receiverId: peer.localId, status: "accepted" }),
    update(pathFor(child), { userId: child.localId, allowVoice: false, allowStrangerMentions: false }),
    update(pathFor(owner), { userId: owner.localId, blocked: [peer.localId] }),
    update(pathFor(peer), { userId: peer.localId, blockedBy: [owner.localId] }),
  )).status, 200);

  assert.equal((await get(owner.idToken, messagePath(peer))).status, 403);
  assert.equal((await get(peer.idToken, messagePath(owner))).status, 403);
  assert.equal((await get(child.idToken, messagePath(owner))).status, 200);
  assert.equal((await get(outsider.idToken, messagePath(owner))).status, 403);
  assert.equal((await get(owner.idToken, room + "/messages")).status, 403);
  assert.equal((await get(child.idToken, room + "/messages")).status, 200);
  assert.equal((await get(peer.idToken, pathFor(peer))).status, 403);
  assert.equal((await commit(owner.idToken, update(pathFor(child), { allowVoice: true }))).status, 403);
  assert.equal((await commit(owner.idToken, update("audit_events/injected-" + roomId, { reason: "forge" }))).status, 403);
  assert.equal((await send(peer, "blocked-mention", owner)).status, 403);
  assert.equal((await send(peer, "stranger-mention", child)).status, 403);
  assert.equal((await commit(peer.idToken, update("friend_messages/blocked-" + roomId,
    { senderId: peer.localId, receiverId: owner.localId, senderName: "Peer", senderAvatar: "0",
      content: "Hey", type: "text", createdAt: now }))).status, 403);
  const voice = update(room + "/voice_participants/" + child.localId,
    { uid: child.localId, muted: true, handRaised: false, joinedAt: now });
  voice.updateTransforms = [{ fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" }];
  assert.equal((await commit(child.idToken, voice,
    update(room + "/voice_state/capacity", { uids: [child.localId] }))).status, 403);

  const mute = room + "/safety_mutes/" + peer.localId;
  assert.equal((await commit(owner.idToken, update(mute, { userId: peer.localId, until: new Date(Date.now() + 60000) }))).status, 403);
  assert.equal((await commit("owner", update(mute, { userId: peer.localId, until: new Date(Date.now() + 60000) }))).status, 200);
  assert.equal((await send(peer, "muted")).status, 403);
  assert.equal((await commit("owner", update(mute, { userId: peer.localId, until: new Date(Date.now() - 60000) }))).status, 200);
  assert.equal((await send(peer, "after-mute")).status, 200);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
