import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsHost =
  process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const functionsEnabled = process.env.NUDGE_FUNCTIONS_E2E === "1";
const appCheckJwt = process.env.NUDGE_APP_CHECK_JWT || "";
const emulatorEnabled = Boolean(
  firestoreHost && authHost && functionsEnabled,
);
const projectId = "nudge-discipline-app";

async function signUp(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${label}-${Date.now()}-${Math.random()}@example.test`,
        password: "correct-horse-battery-staple",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

test(
  "a real authenticated staff account needs App Check to publish an audited item",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `catalog-callable-e2e-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const staff = await signUp("catalog-callable-staff");
    const itemId = `catalog-item-${Date.now()}`;
    const clientRequestId = `catalog-request-${Date.now()}`;

    await firestore.collection("users").doc(staff.localId).set({
      staffRole: "operator",
    });

    const response = await fetch(
      `http://${functionsHost}/${projectId}/asia-east1/manageCatalogItem`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${staff.idToken}`,
          "content-type": "application/json",
          ...(appCheckJwt
            ? { "x-firebase-appcheck": appCheckJwt }
            : {}),
        },
        body: JSON.stringify({
          data: {
            action: "publish",
            itemId,
            clientRequestId,
            sourceSurface: "admin_web",
            payload: {
              type: "permanent",
              name: "真實帳號驗收商品",
              description: "由 Auth 與 Functions 模擬器完成的端到端上架。",
              price: 60,
              image_path: "https://cdn.example.com/e2e-item.png",
            },
          },
        }),
      },
    );
    const responseBody = await response.json();
    if (!appCheckJwt) {
      assert.equal(response.status, 401, JSON.stringify(responseBody));
      assert.equal(responseBody.error?.status, "UNAUTHENTICATED");
      assert.equal(
        (await firestore.collection("shop_items").doc(itemId).get()).exists,
        false,
      );
      return;
    }
    assert.equal(response.status, 200, JSON.stringify(responseBody));
    const result = responseBody.result ?? responseBody.data;
    assert.equal(result.itemId, itemId);
    assert.equal(result.replayed, false);

    const item = await firestore.collection("shop_items").doc(itemId).get();
    assert.equal(item.exists, true);
    assert.equal(item.data().status, "published");
    assert.equal(item.data().name, "真實帳號驗收商品");
    const audit = await firestore
      .collection("audit_events")
      .doc(`catalog-command--${staff.localId}--${clientRequestId}`)
      .get();
    assert.equal(audit.exists, true);
    assert.equal(audit.data().action, "catalog.item.publish");
    assert.equal(audit.data().actorUserId, staff.localId);
  },
);
