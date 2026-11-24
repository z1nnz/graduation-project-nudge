import { HttpsError } from "firebase-functions/v2/https";

const categories = ["mentions", "invitations", "focusRounds", "guildEvents", "familyLetters"];
const webKinds = Object.freeze({
  room_chat_mention: "mentions",
  friend_invitation: "invitations",
  buddy_invitation: "invitations",
  buddy_reminder: "invitations",
  family_invitation: "invitations",
  group_invitation: "invitations",
  room_focus_round: "focusRounds",
  guild_event_reminder: "guildEvents",
  family_scheduled_encouragement: "familyLetters",
});

const timePattern = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
function minuteOfDay(value) {
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}

export function normalizeWebPushPreferences(data) {
  if (!categories.every(key => typeof data?.categories?.[key] === "boolean") ||
      Object.keys(data.categories).length !== categories.length ||
      typeof data?.quiet?.enabled !== "boolean" ||
      !timePattern.test(data.quiet.start) || !timePattern.test(data.quiet.end) ||
      typeof data.quiet.zone !== "string" || data.quiet.zone.length > 80 ||
      data.quiet.enabled && data.quiet.start === data.quiet.end) {
    throw new HttpsError("invalid-argument", "Invalid web push preferences.");
  }
  let zone;
  try {
    zone = new Intl.DateTimeFormat("en", { timeZone: data.quiet.zone }).resolvedOptions().timeZone;
  } catch {
    throw new HttpsError("invalid-argument", "Unknown time zone.");
  }
  return {
    categories: Object.fromEntries(categories.map(key => [key, data.categories[key]])),
    quiet: { enabled: data.quiet.enabled, start: data.quiet.start, end: data.quiet.end, zone },
  };
}

export function webPushAllowed(preferences, kind, now) {
  const category = Object.hasOwn(webKinds, kind) ? webKinds[kind] : null;
  if (!category || preferences?.categories?.[category] === false) return false;
  const quiet = preferences?.quiet;
  if (!quiet?.enabled) return true;
  const time = new Intl.DateTimeFormat("en-GB", {
    timeZone: quiet.zone, hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).format(now);
  const current = minuteOfDay(time);
  const start = minuteOfDay(quiet.start);
  const end = minuteOfDay(quiet.end);
  const muted = start < end ? current >= start && current < end : current >= start || current < end;
  return !muted;
}

export function createUpdateWebPushPreferencesHandler(firestore, clock = () => new Date()) {
  return async request => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required.");
    const preferences = normalizeWebPushPreferences(request.data);
    const ref = firestore.collection("web_push_preferences").doc(uid);
    await ref.set({ ...preferences, updatedAt: clock().toISOString() });
    return { preferences };
  };
}

export function hasWebPushKind(kind) {
  return Object.hasOwn(webKinds, kind);
}
