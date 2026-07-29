import assert from "node:assert/strict";
import test from "node:test";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const emulatorEnabled = Boolean(firestoreHost && authHost);
const projectId = "nudge-discipline-app";
const firestoreBase =
  `http://${firestoreHost}/v1/projects/${projectId}` +
  "/databases/(default)/documents";

function valueOf(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(valueOf) } };
  }
  return { mapValue: { fields: fieldsOf(value) } };
}

function fieldsOf(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, valueOf(value)]),
  );
}

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

async function request(path, token, options = {}) {
  return fetch(`${firestoreBase}/${path}`, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      ...(options.headers || {}),
    },
  });
}

test(
  "staff can read catalog state but all client mutations require Cloud",
  { skip: !emulatorEnabled },
  async () => {
    const app = initializeApp(
      { projectId },
      `catalog-rules-${Date.now()}`,
    );
    const firestore = getFirestore(app);
    const staff = await signUp("catalog-staff");
    const itemId = `catalog-item-${Date.now()}`;

    await firestore.collection("users").doc(staff.localId).set({
      staffRole: "operator",
    });
    await firestore.collection("shop_items").doc(itemId).set({
      schema_version: 1,
      id: itemId,
      type: "permanent",
      status: "published",
      name: "Cloud 管理商品",
      description: "只能由 Cloud 修改。",
      price: 60,
      image_path: "https://cdn.example.com/item.png",
    });
    await firestore.collection("catalog_counters").doc("avatar_series").set({
      next_index: 24,
    });

    assert.equal(
      (await request(`shop_items/${itemId}`, staff.idToken)).status,
      200,
    );
    assert.equal(
      (
        await request(
          "catalog_counters/avatar_series",
          staff.idToken,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(`shop_items/${itemId}`, staff.idToken, {
          method: "PATCH",
          body: JSON.stringify({
            fields: fieldsOf({
              status: "archived",
            }),
          }),
        })
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          `shop_items/catalog-direct-create-${Date.now()}`,
          staff.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({
                type: "permanent",
                status: "published",
                name: "繞過 Cloud",
                description: "此寫入必須被拒絕。",
                price: 1,
                image_path: "https://cdn.example.com/direct.png",
              }),
            }),
          },
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(
          "catalog_counters/avatar_series",
          staff.idToken,
          {
            method: "PATCH",
            body: JSON.stringify({
              fields: fieldsOf({ next_index: 999 }),
            }),
          },
        )
      ).status,
      403,
    );
  },
);
