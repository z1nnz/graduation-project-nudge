import admin from "firebase-admin";
import fs from "fs";
import path from "path";
import { fileURLToPath, pathToFileURL } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const AVATAR_KEYS = [
  "skinToneIndex",
  "faceShapeIndex",
  "hairStyleIndex",
  "hairColorIndex",
  "eyeStyleIndex",
  "eyebrowStyleIndex",
  "mouthStyleIndex",
  "outfitStyleIndex",
  "outfitColorIndex",
  "accessoryIndex",
  "backgroundColorIndex",
  "avatarIconIndex",
];

function boundedString(value, fallback, maxLength) {
  const normalized = String(value ?? fallback).trim().slice(0, maxLength);
  return normalized || fallback;
}

export function buildPublicProfile(userId, userData, now = new Date()) {
  const fallbackNudgeId = `NDG_${userId.slice(0, 6).toUpperCase()}`;
  const username = boundedString(
    userData.username || userData.myNudgeId,
    fallbackNudgeId,
    40,
  );
  const myNudgeId = boundedString(
    userData.myNudgeId || username,
    fallbackNudgeId,
    40,
  );
  const avatar = userData.avatarProfile || {};
  const rawPlanetCount = Number.isFinite(userData.planetCount)
    ? Math.floor(userData.planetCount)
    : 0;
  const familyRole = ["guardian", "child"].includes(userData.userRole)
    ? userData.userRole
    : "personal";
  const accentColor = [
    "purple",
    "blue",
    "teal",
    "green",
    "orange",
    "pink",
    "red",
    "indigo",
  ].includes(userData.accentColor)
    ? userData.accentColor
    : "purple";

  return {
    schemaVersion: 1,
    userId,
    username,
    myNudgeId,
    nickname: boundedString(userData.nickname, "自律使用者", 40),
    signature: boundedString(userData.signature, "", 160),
    avatarProfile: Object.fromEntries(
      AVATAR_KEYS.map(key => [
        key,
        Number.isInteger(avatar[key]) ? avatar[key] : 0,
      ]),
    ),
    accentColor,
    planetCount: Math.max(0, rawPlanetCount),
    familyRole,
    profileTitleBadgeKey: boundedString(
      userData.profileTitleBadgeKey,
      "",
      80,
    ),
    unlockedBadgeDates:
      userData.unlockedBadgeDates &&
      typeof userData.unlockedBadgeDates === "object" &&
      !Array.isArray(userData.unlockedBadgeDates)
        ? userData.unlockedBadgeDates
        : {},
    updatedAt: now.toISOString(),
  };
}

async function backfillPublicProfiles({ apply }) {
  const serviceAccountPath = path.join(
    __dirname,
    "..",
    "firebase-service-account.json",
  );
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(
      "找不到 firebase-service-account.json；請依 scripts/seed_firestore.js 的既有流程放在專案根目錄。",
    );
  }

  const serviceAccount = JSON.parse(
    fs.readFileSync(serviceAccountPath, "utf8"),
  );
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();
  const usersSnapshot = await db.collection("users").get();
  const now = new Date();

  console.log(
    `${apply ? "APPLY" : "DRY RUN"}: 找到 ${usersSnapshot.size} 個既有使用者。`,
  );
  if (!apply) {
    console.log(
      "未寫入資料。確認數量後執行：node scripts/backfill_public_profiles.js --apply",
    );
    return;
  }

  let batch = db.batch();
  let pendingWrites = 0;
  let completedWrites = 0;
  for (const userDoc of usersSnapshot.docs) {
    batch.set(
      db.collection("public_profiles").doc(userDoc.id),
      buildPublicProfile(userDoc.id, userDoc.data(), now),
    );
    pendingWrites += 1;
    if (pendingWrites === 400) {
      await batch.commit();
      completedWrites += pendingWrites;
      batch = db.batch();
      pendingWrites = 0;
    }
  }
  if (pendingWrites > 0) {
    await batch.commit();
    completedWrites += pendingWrites;
  }
  console.log(`完成 ${completedWrites} 份 public_profiles 回填。`);
}

const isDirectRun =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isDirectRun) {
  backfillPublicProfiles({ apply: process.argv.includes("--apply") }).catch(
    error => {
      console.error(error.message);
      process.exitCode = 1;
    },
  );
}
