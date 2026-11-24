import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { HttpsError } from "firebase-functions/v2/https";
import { hiddenBySafety, safetyDocument } from "./social-safety-service.js";

const prompts = JSON.parse(readFileSync(new URL("./exchange-journal-prompts.json", import.meta.url)));
const stickers = new Set(["cheer", "study", "sleep", "thumbs-up", "happy-tears", "flex", "coffee", "heart", "okay", "wave", "think", "fire"]);
const thirtyDays = 30 * 24 * 60 * 60 * 1000;
const fail = (code, message) => { throw new HttpsError(code, message); };

function id(value) {
  if (typeof value !== "string" || !/^[^/]{1,180}$/.test(value)) fail("invalid-argument", "Invalid journal identity.");
  return value;
}

function pointerId(people) {
  return createHash("sha256").update(JSON.stringify(people)).digest("hex");
}

export function journalEntry(body, sticker) {
  const text = typeof body === "string" ? body.trim() : "";
  if (!text || [...text].length > 500 || sticker && !stickers.has(sticker)) {
    fail("invalid-argument", "An entry requires 1–500 characters and at most one known sticker.");
  }
  return { text, sticker: sticker || null };
}

async function related(db, tx, uid, peer) {
  const users = db.collection("users");
  const [mine, theirs] = await tx.getAll(users.doc(uid).collection("friends").doc(peer),
    users.doc(peer).collection("friends").doc(uid));
  if (mine.exists && theirs.exists) return true;
  const relationships = await tx.get(db.collection("family_links").where("participantIds", "array-contains", uid));
  return relationships.docs.some(doc => {
    const link = doc.data();
    return link.status === "active" && [link.childId, link.guardianId].includes(uid) &&
      [link.childId, link.guardianId].includes(peer);
  });
}

async function removeJournal(db, ref) {
  await db.recursiveDelete(ref);
}

export function createJournalHandler(db, clock = () => new Date()) {
  const books = db.collection("exchange_journals");
  const pairs = db.collection("exchange_journal_pairs");

  return async ({ auth, data = {} }) => {
    const uid = auth?.uid;
    if (!uid) fail("unauthenticated", "Sign-in is required.");
    const instant = clock();
    const now = instant.toISOString();
    if (data.action === "list") {
      const [journals, friends, families, safety] = await Promise.all([
        books.where("participantIds", "array-contains", uid).get(),
        db.collection("users").doc(uid).collection("friends").get(),
        db.collection("family_links").where("participantIds", "array-contains", uid).get(),
        safetyDocument(db, uid).get(),
      ]);
      const peers = new Set(friends.docs.map(doc => doc.id));
      for (const family of families.docs) {
        const link = family.data();
        if (link.status === "active") peers.add(uid === link.childId ? link.guardianId : link.childId);
      }
      const visible = journals.docs.filter(doc => {
        const book = doc.data();
        return book.status !== "deleted" && (!book.expiresAt || book.expiresAt > now);
      });
      visible.forEach(doc => peers.add(doc.data().participantIds.find(member => member !== uid)));
      const profiles = peers.size ? await db.getAll(...[...peers].map(peer => db.collection("public_profiles").doc(peer))) : [];
      return {
        people: profiles.filter(doc => !hiddenBySafety(safety.data(), doc.id)).map(doc => ({
          id: doc.id, name: doc.data()?.nickname || doc.data()?.displayName || "小鎮夥伴",
        })),
        journals: visible.map(doc => ({ id: doc.id, ...doc.data() })),
      };
    }

    if (data.action === "open") {
      const peer = id(data.peerId);
      if (uid === peer) fail("invalid-argument", "Choose another person.");
      const participantIds = [uid, peer].sort();
      return db.runTransaction(async tx => {
        const pointer = pairs.doc(pointerId(participantIds));
        const [previous, safety, fence] = await tx.getAll(pointer, safetyDocument(db, uid),
          db.collection("account_deletion_fences").doc(peer));
        if (fence.exists || hiddenBySafety(safety.data(), peer) || !(await related(db, tx, uid, peer))) {
          fail("permission-denied", "Only current friends or family can open a journal.");
        }
        if (previous.exists) {
          const existing = await tx.get(books.doc(previous.data().journalId));
          const book = existing.data();
          if (book && book.status !== "deleted" && (!book.expiresAt || book.expiresAt > now)) {
            return { id: existing.id };
          }
        }
        const book = books.doc();
        tx.create(book, { participantIds, authorId: uid, status: "pending", nextAuthorId: peer,
          count: 0, createdAt: now, updatedAt: now, expiresAt: null });
        tx.set(pointer, { participantIds, journalId: book.id });
        return { id: book.id };
      });
    }

    const ref = books.doc(id(data.journalId));
    const result = await db.runTransaction(async tx => {
      const book = (await tx.get(ref)).data();
      if (!book?.participantIds.includes(uid) || book.status === "deleted" || book.expiresAt && book.expiresAt <= now) {
        fail("permission-denied", "Journal is unavailable.");
      }
      const peer = book.participantIds.find(member => member !== uid);
      if (data.action === "read") {
        const entries = book.status === "pending" ? [] : await tx.get(ref.collection("entries")
          .orderBy("number", "desc").startAfter(Number.isSafeInteger(data.before) ? data.before : book.count + 1).limit(30));
        return { ...book, prompt: book.status === "active" && book.nextAuthorId === uid ? prompts[book.count % prompts.length] : null,
          entries: Array.isArray(entries) ? entries : entries.docs.map(doc => doc.data()) };
      }
      if (data.action === "delete" || data.action === "end" && book.status === "pending") {
        const pointer = pairs.doc(pointerId(book.participantIds));
        const previous = await tx.get(pointer);
        if (previous.data()?.journalId === ref.id) tx.delete(pointer);
        tx.update(ref, { status: "deleted", nextAuthorId: null, expiresAt: now });
        return { remove: true };
      }
      if (data.action === "end" && book.status === "active") {
        tx.update(ref, { status: "ended", nextAuthorId: null, updatedAt: now,
          expiresAt: new Date(instant.getTime() + thirtyDays).toISOString() });
        return {};
      }
      if (!["accept", "write"].includes(data.action)) fail("failed-precondition", "That action is unavailable.");
      const [safety, fence] = await tx.getAll(safetyDocument(db, uid), db.collection("account_deletion_fences").doc(peer));
      if (fence.exists || hiddenBySafety(safety.data(), peer)) fail("permission-denied", "Journal is unavailable.");
      if (data.action === "accept" && book.status === "pending" && book.nextAuthorId === uid) {
        if (!(await related(db, tx, uid, peer))) fail("permission-denied", "Journal is unavailable.");
        tx.update(ref, { status: "active", nextAuthorId: book.authorId, updatedAt: now });
        return {};
      }
      if (data.action !== "write" || book.status !== "active" || book.nextAuthorId !== uid) {
        fail("failed-precondition", "Wait for your turn.");
      }
      const entry = journalEntry(data.text, data.sticker);
      const number = book.count + 1;
      tx.create(ref.collection("entries").doc(String(number)), {
        ...entry, number, authorId: uid, prompt: prompts[book.count % prompts.length], createdAt: now,
      });
      tx.update(ref, { count: number, nextAuthorId: peer, updatedAt: now });
      return {};
    });
    if (result.remove) await removeJournal(db, ref);
    return result;
  };
}

export function createJournalCleanup(db, clock = () => new Date()) {
  return async () => {
    const expired = await db.collection("exchange_journals").where("expiresAt", "<=", clock().toISOString()).limit(100).get();
    for (const doc of expired.docs) {
      if (!doc.data().expiresAt) continue;
      const pointer = db.collection("exchange_journal_pairs").doc(pointerId(doc.data().participantIds));
      await db.runTransaction(async tx => {
        if ((await tx.get(pointer)).data()?.journalId === doc.id) tx.delete(pointer);
      });
      await removeJournal(db, doc.ref);
    }
  };
}
