import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

import {
  assertFails,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const emulatorEnabled = Boolean(storageHost);
const projectId = "nudge-discipline-app";

function storageEndpoint() {
  const [host, port] = storageHost.split(":");
  assert.ok(host);
  assert.ok(Number.isInteger(Number(port)));
  return { host, port: Number(port) };
}

test(
  "privacy export objects deny direct owner and outsider Storage SDK access",
  { skip: !emulatorEnabled, timeout: 15_000 },
  async () => {
    const testEnvironment = await initializeTestEnvironment({
      projectId,
      storage: {
        ...storageEndpoint(),
        rules: fs.readFileSync(
          new URL("../../storage.rules", import.meta.url),
          "utf8",
        ),
      },
    });
    try {
      const ownerUserId = "privacy-storage-owner";
      const path =
        `privacy_exports/${ownerUserId}/` +
        `${ownerUserId}--privacy-storage-001.json`;
      await testEnvironment.withSecurityRulesDisabled(async context => {
        await context.storage().ref(path).putString("{}");
      });

      const ownerStorage = testEnvironment
        .authenticatedContext(ownerUserId)
        .storage();
      const outsiderStorage = testEnvironment
        .authenticatedContext("privacy-storage-outsider")
        .storage();
      await assertFails(ownerStorage.ref(path).getDownloadURL());
      await assertFails(outsiderStorage.ref(path).getDownloadURL());
      await assertFails(ownerStorage.ref(`${path}-client`).putString("{}"));
    } finally {
      await testEnvironment.cleanup();
    }
  },
);
