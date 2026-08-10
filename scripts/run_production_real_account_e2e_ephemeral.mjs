import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const projectId = "nudge-discipline-app";
const projectNumber = "497972469632";
const webAppId = "1:497972469632:web:cb87819a70c7cb8f2f6b65";
const gcloud = process.env.NUDGE_GCLOUD_BIN?.trim() || "gcloud";

function adminAccessToken() {
  const result = spawnSync(gcloud, ["auth", "print-access-token"], {
    encoding: "utf8",
  });
  if (result.status !== 0 || !result.stdout.trim()) {
    throw new Error("Unable to acquire the short-lived administrator token.");
  }
  return result.stdout.trim();
}

function webApiKey() {
  const source = readFileSync("lib/firebase_options.dart", "utf8");
  const match = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/s,
  );
  if (!match) {
    throw new Error("Unable to resolve the public Firebase Web API key.");
  }
  return match[1];
}

async function jsonRequest(url, { method = "GET", bearer, body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      ...(bearer
        ? {
            Authorization: `Bearer ${bearer}`,
            "x-goog-user-project": projectId,
          }
        : {}),
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  let payload = {};
  try {
    payload = text ? JSON.parse(text) : {};
  } catch {
    payload = {};
  }
  if (!response.ok) {
    const reason = payload?.error?.message || `HTTP ${response.status}`;
    throw new Error(reason);
  }
  return payload;
}

const encodedAppId = encodeURIComponent(webAppId);
const debugTokenSecret = randomUUID();
let debugTokenName = "";
let exitCode = 1;

try {
  const administratorToken = adminAccessToken();
  const created = await jsonRequest(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectNumber}/apps/${encodedAppId}/debugTokens`,
    {
      method: "POST",
      bearer: administratorToken,
      body: {
        displayName: `production-e2e-${new Date().toISOString()}`,
        token: debugTokenSecret,
      },
    },
  );
  debugTokenName = created.name || "";
  if (!debugTokenName) {
    throw new Error("Debug token registration returned no name.");
  }

  const exchanged = await jsonRequest(
    `https://firebaseappcheck.googleapis.com/v1/projects/${projectNumber}/apps/${encodedAppId}:exchangeDebugToken?key=${encodeURIComponent(webApiKey())}`,
    {
      method: "POST",
      body: { debugToken: debugTokenSecret, limitedUse: false },
    },
  );
  const appCheckToken = exchanged.token || "";
  if (!appCheckToken) throw new Error("App Check exchange returned no token.");

  const e2e = spawnSync(
    process.execPath,
    ["scripts/production_real_account_e2e.mjs"],
    {
      cwd: process.cwd(),
      env: {
        ...process.env,
        NUDGE_FIREBASE_PROJECT_ID: projectId,
        NUDGE_FIREBASE_WEB_API_KEY: webApiKey(),
        NUDGE_FIREBASE_ADMIN_ACCESS_TOKEN: administratorToken,
        NUDGE_FIREBASE_APP_CHECK_TOKEN: appCheckToken,
        NUDGE_GOOGLE_QUOTA_PROJECT: projectId,
      },
      stdio: "inherit",
    },
  );
  exitCode = e2e.status ?? 1;
  if (e2e.error) throw e2e.error;
} finally {
  if (debugTokenName) {
    try {
      await jsonRequest(
        `https://firebaseappcheck.googleapis.com/v1/${debugTokenName}`,
        { method: "DELETE", bearer: adminAccessToken() },
      );
      console.log("Ephemeral App Check debug token revoked.");
    } catch (error) {
      console.error(
        `Failed to revoke ephemeral App Check debug token: ${error.message}`,
      );
      exitCode = 1;
    }
  }
}

process.exitCode = exitCode;
