import { createHash } from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

const actions = new Set(["seal", "open", "export", "cancel", "delete"]);
const idPattern = /^[A-Za-z0-9_-]{8,128}$/;
const validISO = value => typeof value === "string" &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value) &&
  Number.isFinite(Date.parse(value)) && new Date(value).toISOString() === value;

export function normalizeCapsuleRequest(data) {
  if (!data || typeof data !== "object" || Array.isArray(data) ||
      !actions.has(data.action) || typeof data.capsuleId !== "string" || !idPattern.test(data.capsuleId)) {
    throw new HttpsError("invalid-argument", "請提供有效的操作與膠囊識別。");
  }
  const allowed = data.action === "seal"
    ? ["action", "capsuleId", "title", "message", "unlockDate"]
    : ["action", "capsuleId"];
  if (Object.keys(data).length !== allowed.length || Object.keys(data).some(k => !allowed.includes(k))) {
    throw new HttpsError("invalid-argument", "不接受額外身分、時鐘或狀態欄位。");
  }
  const result = { action: data.action, capsuleId: data.capsuleId };
  if (data.action !== "seal") return result;
  if (typeof data.title !== "string" || !data.title.trim() || data.title.trim().length > 120 ||
      typeof data.message !== "string" || !data.message.trim() || data.message.trim().length > 8000 ||
      !/^\d{4}-\d{2}-\d{2}$/.test(data.unlockDate || "")) {
    throw new HttpsError("invalid-argument", "請填寫標題、正文與有效日期。");
  }
  const [y,m,d] = data.unlockDate.split("-").map(Number);
  const check = new Date(Date.UTC(y,m-1,d));
  if (y < 2020 || y > 2200 || check.getUTCFullYear() !== y ||
      check.getUTCMonth() !== m-1 || check.getUTCDate() !== d) {
    throw new HttpsError("invalid-argument", "日期不存在。");
  }
  result.title = data.title.trim();
  result.message = data.message.trim();
  result.unlockAt = new Date(check.getTime() - 8*3600000).toISOString();
  result.digest = createHash("sha256").update(JSON.stringify({
    title: result.title, message: result.message, unlockAt: result.unlockAt,
  })).digest("hex");
  return result;
}

function requireIdentity(request) {
  const uid = request.auth?.uid;
  if (!uid || uid.includes("/") || request.auth?.token?.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "請使用本人帳號登入。");
  }
  if (!request.app?.appId) throw new HttpsError("unauthenticated", "此操作需要 App Check。");
  return uid;
}

function refs(firestore, uid, id) {
  const user = firestore.collection("users").doc(uid);
  return {
    user, fence: firestore.collection("account_deletion_fences").doc(uid),
    meta: user.collection("growth_capsules").doc(id),
    secret: user.collection("growth_capsule_secrets").doc(id),
    operation: user.collection("growth_capsule_operations").doc(id),
    notification: firestore.collection("user_notifications").doc("growth-capsule--" + uid + "--" + id),
  };
}

export function canOpenCapsule(meta, uid, now) {
  return meta?.ownerUid === uid && ["sealed", "opened"].includes(meta.status) &&
    validISO(meta.unlockAt) && Number.isFinite(new Date(now).getTime()) &&
    Date.parse(meta.unlockAt) <= new Date(now).getTime();
}

export function createManageGrowthCapsuleHandler({ firestore, clock = () => new Date() }) {
  return async request => {
    const uid = requireIdentity(request);
    const input = normalizeCapsuleRequest(request.data);
    const ref = refs(firestore, uid, input.capsuleId);
    return firestore.runTransaction(async tx => {
      const now = clock().toISOString();
      const [user,fence,metaSnap,opSnap] = await Promise.all([
        tx.get(ref.user),tx.get(ref.fence),tx.get(ref.meta),tx.get(ref.operation),
      ]);
      if (!user.exists || fence.exists) throw new HttpsError("failed-precondition", "帳號無法進行此操作。");
      const meta = metaSnap.exists ? metaSnap.data() : null;
      const op = opSnap.exists ? opSnap.data() : null;
      if ((meta && (meta.ownerUid !== uid || meta.capsuleId !== input.capsuleId)) ||
          (op && op.ownerUid !== uid)) throw new HttpsError("permission-denied", "無法讀取此膠囊。");
      if (input.action === "seal") {
        if (op) {
          if (op.status !== "active") throw new HttpsError("failed-precondition", "此膠囊已取消或刪除；重試不會恢復正文。");
          if (op.digest !== input.digest || !meta) throw new HttpsError("already-exists", "此識別已用於不同的膠囊。");
          return { capsule: meta, serverNow: now, wasDuplicate: true };
        }
        if (meta) throw new HttpsError("data-loss", "膠囊版本不完整，未覆寫既有正文。");
        if (Date.parse(input.unlockAt) <= Date.parse(now) ||
            Date.parse(input.unlockAt) > Date.parse(now) + 3660*86400000) {
          throw new HttpsError("invalid-argument", "開封日必須在伺服器現在時間之後、十年以內。");
        }
        const saved = await tx.get(ref.user.collection("growth_capsules").limit(100));
        if (saved.size >= 100) throw new HttpsError("resource-exhausted", "請先整理已保存的膠囊（最多 100 封）。");
        const created = { schemaVersion: 1, capsuleId: input.capsuleId, ownerUid: uid,
          title: input.title, status: "sealed", unlockAt: input.unlockAt, createdAt: now,
          updatedAt: now, openedAt: null, notifiedAt: null };
        tx.set(ref.secret, { schemaVersion: 1, capsuleId: input.capsuleId, ownerUid: uid,
          unlockAt: input.unlockAt, message: input.message });
        tx.set(ref.operation, { schemaVersion: 1, ownerUid: uid, digest: input.digest,
          status: "active", createdAt: now });
        tx.set(ref.meta, created);
        return { capsule: created, serverNow: now, wasDuplicate: false };
      }
      if (input.action === "delete" && op?.status === "deleted") return { status: "deleted", serverNow: now };
      if (!meta) throw new HttpsError("not-found", "膠囊不存在或已刪除。");
      if (["open", "export"].includes(input.action)) {
        if (!canOpenCapsule(meta, uid, now)) throw new HttpsError("failed-precondition", "尚未到開封時間，或膠囊已取消。");
        const secretSnap = await tx.get(ref.secret);
        const secret = secretSnap.exists ? secretSnap.data() : null;
        if (secret?.ownerUid !== uid || secret?.capsuleId !== input.capsuleId ||
            secret?.unlockAt !== meta.unlockAt || typeof secret?.message !== "string") {
          throw new HttpsError("data-loss", "正文未完整保存；請稍後重試，不會以空白代替。");
        }
        const opened = { ...meta, status: "opened", openedAt: meta.openedAt || now, updatedAt: now };
        tx.set(ref.meta, opened);
        return { capsule: { ...opened, message: secret.message }, serverNow: now };
      }
      // Erasing the secret is real cancellation/deletion, not merely hidden UI.
      tx.delete(ref.secret);
      tx.delete(ref.notification);
      if (input.action === "cancel") {
        const cancelled = { ...meta, status: "cancelled", updatedAt: now };
        tx.set(ref.meta, cancelled);
        tx.set(ref.operation, { ...op, ownerUid: uid, status: "cancelled" });
        return { capsule: cancelled, serverNow: now };
      }
      tx.delete(ref.meta);
      tx.set(ref.operation, { ...op, ownerUid: uid, status: "deleted", deletedAt: now });
      return { status: "deleted", serverNow: now };
    });
  };
}

export function createNotifyDueGrowthCapsulesHandler({ firestore, clock = () => new Date() }) {
  return async () => {
    const now = clock().toISOString();
    const due = await firestore.collectionGroup("growth_capsules")
      .where("status", "==", "sealed").where("notifiedAt", "==", null)
      .where("unlockAt", "<=", now).orderBy("unlockAt", "asc").limit(100).get();
    let notified = 0;
    for (const doc of due.docs) {
      const parts = doc.ref.path.split("/");
      if (parts.length !== 4 || parts[0] !== "users" || parts[2] !== "growth_capsules") continue;
      const uid = parts[1], ref = refs(firestore, uid, doc.id);
      const changed = await firestore.runTransaction(async tx => {
        const [current,user,fence] = await Promise.all([tx.get(ref.meta),tx.get(ref.user),tx.get(ref.fence)]);
        const meta = current.exists ? current.data() : null;
        if (!user.exists || fence.exists || !canOpenCapsule(meta,uid,now) ||
            meta.status !== "sealed" || meta.notifiedAt) return false;
        tx.set(ref.notification, { schemaVersion: 1, notificationId: ref.notification.id,
          recipientUserId: uid, actorUserId: uid, actorPrincipalId: uid,
          category: "reminder", kind: "growth_capsule_due", sourceType: "growth_capsule",
          sourceId: doc.id, title: "一封時間膠囊到期了",
          body: "回到紀錄館，用自己的帳號開啟這封信。", route: "personal-time-capsule",
          status: "unread", createdAt: now, updatedAt: now });
        tx.update(ref.meta, { notifiedAt: now, updatedAt: now });
        return true;
      });
      if (changed) notified++;
    }
    return { examined: due.size, notified, hasMore: due.size === 100 };
  };
}

export async function collectGrowthCapsuleExport({ firestore, userId, now, collect }) {
  const metadata = await collect(firestore.collection("users/" + userId + "/growth_capsules"));
  const result = [];
  for (const item of metadata) {
    const meta = item.data;
    if (meta.ownerUid !== userId) throw new Error("Growth capsule owner mismatch.");
    const exported = { ...item, data: { ...meta, messageWithheldUntilDue: true } };
    if (canOpenCapsule(meta,userId,now)) {
      const secretSnap = await firestore.collection("users/" + userId + "/growth_capsule_secrets").doc(item.id).get();
      const secret = secretSnap.exists ? secretSnap.data() : null;
      if (secret?.ownerUid !== userId || secret?.capsuleId !== item.id ||
          secret?.unlockAt !== meta.unlockAt || typeof secret?.message !== "string") {
        throw new Error("Growth capsule export is incomplete.");
      }
      exported.data.message = secret.message;
      exported.data.messageWithheldUntilDue = false;
    }
    result.push(exported);
  }
  return result;
}
