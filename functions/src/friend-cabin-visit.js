import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { HttpsError } from "firebase-functions/v2/https";

const catalog = createRequire(import.meta.url)("./home-decor-catalog.json");
const notes = Object.freeze({
  cheer: "今天也替你加油！", step: "慢慢來，每一步都算數。",
  steady: "照自己的節奏就好。", rest: "休息一下也很重要。",
  proud: "為你今天的努力感到開心！", hello: "路過小屋，來打聲招呼。",
  focus: "祝你今天專注又順利。", brave: "開始就是值得鼓勵的一步。",
  together: "下次再一起努力！", progress: "一點一滴都在進步。",
  tomorrow: "明天也是新的開始。", thanks: "謝謝你一直這麼努力。",
});
const stickers = new Set(["cheer", "study", "sleep", "thumbs-up", "happy-tears", "flex",
  "coffee", "heart", "okay", "wave", "think", "fire"]);
const date = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", dateStyle: "short" });

function docId(value, maxLength = 128) {
  if (typeof value !== "string" || !value.length || value.length > maxLength || /[\/]/.test(value)) {
    throw new HttpsError("invalid-argument", "Invalid visit identity.");
  }
  return value;
}

function publicCabin(profile = {}, user = {}) {
  const index = profile.avatarProfile?.faceShapeIndex;
  const decor = {};
  const owned = new Set(Array.isArray(user.unlockedAvatarItems) ? user.unlockedAvatarItems : []);
  catalog.slots.forEach((slot, order) => {
    const choice = user.homeDecor?.[slot.slot];
    decor[slot.slot] = Number.isInteger(choice) && slot.variants.some(variant => variant.index === choice) &&
      (choice === 0 || owned.has("homeDecor:" + (order * 100 + choice))) ? choice : 0;
  });
  return {
    homeDecor: decor,
    avatarProfile: { faceShapeIndex: Number.isInteger(index) && index >= 0 && index < 18 ? index : 0 },
  };
}

export function createFriendCabinVisitHandler(firestore, clock = () => new Date()) {
  const users = firestore.collection("users");
  const visits = firestore.collection("friend_visits");
  const scopes = firestore.collection("friend_visit_settings");
  const notices = firestore.collection("user_notifications");
  const fences = firestore.collection("account_deletion_fences");

  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const input = request.data || {};
    const now = clock();
    const day = date.format(now);
    const notificationRef = key => notices.doc("cabin-guest--" +
      createHash("sha256").update(key).digest("hex"));

    if (input.action === "remove") {
      const visitRef = visits.doc(docId(input.visitId, 270));
      return firestore.runTransaction(async transaction => {
        const [snapshot, fence] = await transaction.getAll(visitRef, fences.doc(uid));
        const data = snapshot.data();
        if (fence.exists || data?.hostId !== uid || data.schemaVersion !== 2) {
          throw new HttpsError("permission-denied", "Only the host can remove this entry.");
        }
        if (data.removed === true) return { removed: true };
        transaction.update(visitRef, { removed: true, noteKey: null, stickerKey: null });
        transaction.delete(notificationRef(visitRef.id));
        return { removed: true };
      });
    }

    if (!["open", "leave"].includes(input.action)) {
      throw new HttpsError("invalid-argument", "Invalid visit action.");
    }
    const host = docId(input.hostId);
    if (host === uid) throw new HttpsError("invalid-argument", "Select an eligible friend.");
    if (input.action === "leave" && (!Object.hasOwn(notes, input.noteKey) || !stickers.has(input.stickerKey))) {
      throw new HttpsError("invalid-argument", "Choose one note and one sticker.");
    }

    const visitRef = visits.doc(host + "--" + uid + "--" + day);
    const hostRef = users.doc(host);
    const visitorRef = users.doc(uid);
    return firestore.runTransaction(async transaction => {
      const [settings, fromFriend, toFriend, hostFence, visitorFence, previous] =
        await transaction.getAll(scopes.doc(host), visitorRef.collection("friends").doc(host),
          hostRef.collection("friends").doc(uid), fences.doc(host), fences.doc(uid), visitRef);
      if (settings.data()?.allowVisits !== true || settings.data()?.shareCabin !== true ||
          !fromFriend.exists || !toFriend.exists || hostFence.exists || visitorFence.exists) {
        throw new HttpsError("permission-denied", "This cabin is unavailable.");
      }
      const prior = previous.data();
      if (prior && (prior.hostId !== host || prior.visitorId !== uid)) {
        throw new HttpsError("already-exists", "This visit identity is in use.");
      }
      const alreadyLeft = prior?.schemaVersion === 2;
      if (input.action === "open") {
        const [hostUser, profile] = await transaction.getAll(hostRef,
          firestore.collection("public_profiles").doc(host));
        if (!hostUser.exists) throw new HttpsError("not-found", "This cabin is unavailable.");
        return { cabin: publicCabin(profile.data(), hostUser.data()), alreadyLeft };
      }
      if (alreadyLeft) {
        if (prior.removed !== true && prior.noteKey === input.noteKey && prior.stickerKey === input.stickerKey) {
          return { sent: true };
        }
        throw new HttpsError("already-exists", "You already left a letter today.");
      }

      const createdAt = now.toISOString();
      const notice = notificationRef(visitRef.id);
      transaction.set(visitRef, {
        schemaVersion: 2, hostId: host, visitorId: uid, dateKey: day, sceneKey: "cabin",
        noteKey: input.noteKey, stickerKey: input.stickerKey, removed: false, createdAt,
      });
      transaction.create(notice, {
        schemaVersion: 1, notificationId: notice.id, recipientUserId: host,
        category: "social", kind: "friend_cabin_letter", sourceType: "friend_visit",
        sourceId: visitRef.id, actorUserId: uid, actorPrincipalId: uid,
        title: "好友在小屋留言了", body: notes[input.noteKey], route: "friend-visits",
        stickerKey: input.stickerKey, status: "unread", createdAt, updatedAt: createdAt,
      });
      return { sent: true };
    });
  };
}
