import assert from "node:assert/strict";
import test from "node:test";

import {
  createManageCatalogItemHandler,
  normalizeCatalogCommand,
  normalizeCatalogPayload,
} from "../src/catalog-management-service.js";

function fakeFirestore(seed = {}) {
  const documents = new Map(
    Object.entries(seed).map(([path, data]) => [path, structuredClone(data)]),
  );
  const documentReference = (collection, id) => ({
    kind: "document",
    id,
    path: `${collection}/${id}`,
  });
  const collectionReference = collection => ({
    doc: id => documentReference(collection, id),
    where: (field, operator, value) => ({
      kind: "query",
      collection,
      field,
      operator,
      value,
    }),
  });
  const snapshotFor = ref => ({
    exists: documents.has(ref.path),
    id: ref.id,
    data: () => structuredClone(documents.get(ref.path)),
  });
  const querySnapshotFor = query => {
    assert.equal(query.operator, "==");
    const prefix = `${query.collection}/`;
    const docs = [...documents.entries()]
      .filter(([path, value]) =>
        path.startsWith(prefix) && value?.[query.field] === query.value,
      )
      .map(([path]) => {
        const id = path.slice(prefix.length);
        return snapshotFor(documentReference(query.collection, id));
      });
    return {
      docs,
      size: docs.length,
      forEach: callback => docs.forEach(callback),
    };
  };
  return {
    documents,
    collection: collectionReference,
    runTransaction: async callback =>
      callback({
        get: async ref =>
          ref.kind === "query" ? querySnapshotFor(ref) : snapshotFor(ref),
        set: (ref, data, options) => {
          const next = structuredClone(data);
          if (options?.merge && documents.has(ref.path)) {
            documents.set(ref.path, {
              ...documents.get(ref.path),
              ...next,
            });
          } else {
            documents.set(ref.path, next);
          }
        },
        update: (ref, data) => {
          if (!documents.has(ref.path)) throw new Error("not found");
          documents.set(ref.path, {
            ...documents.get(ref.path),
            ...structuredClone(data),
          });
        },
        create: (ref, data) => {
          if (documents.has(ref.path)) throw new Error("already exists");
          documents.set(ref.path, structuredClone(data));
        },
      }),
  };
}

function avatarSeriesPayload(overrides = {}) {
  return {
    type: "avatar_series",
    name: "夜影學院",
    description: "在專注與運動中逐步解鎖完整進化。",
    price: 120,
    series_key: "night-academy",
    series_name: "夜影學院",
    series_theme: "夜間專注",
    codex_description: "完整三階角色圖鑑。",
    start_time: 1_800_000_000,
    end_time: 1_900_000_000,
    character_stages: [
      {
        stage: 1,
        name: "夜影見習生",
        description: "初始型態。",
        character_asset: "https://cdn.example.com/stage-1.png",
        icon_asset: "https://cdn.example.com/stage-1-icon.png",
        required_level: 1,
        required_experience: 0,
        shop_eligible: false,
        coin_price: 999,
      },
      {
        stage: 2,
        name: "夜影修行者",
        description: "完成成長條件後進化。",
        character_asset: "https://cdn.example.com/stage-2.png",
        icon_asset: "https://cdn.example.com/stage-2-icon.png",
        required_level: 30,
        required_experience: 10_000,
        shop_eligible: true,
        coin_price: 999,
      },
      {
        stage: 3,
        name: "夜影宗師",
        description: "最終進化型態。",
        character_asset: "https://cdn.example.com/stage-3.png",
        icon_asset: "https://cdn.example.com/stage-3-icon.png",
        required_level: 60,
        required_experience: 30_000,
        shop_eligible: true,
        coin_price: 999,
      },
    ],
    ...overrides,
  };
}

test("catalog payload makes only the initial avatar stage shop eligible", () => {
  const payload = normalizeCatalogPayload(avatarSeriesPayload());

  assert.equal(payload.character_stages[0].shop_eligible, true);
  assert.equal(payload.character_stages[0].coin_price, 120);
  assert.equal(payload.character_stages[1].shop_eligible, false);
  assert.equal(payload.character_stages[1].coin_price, 0);
  assert.equal(payload.character_stages[2].shop_eligible, false);
  assert.equal(payload.character_stages[2].coin_price, 0);
  assert.equal(payload.image_path, payload.character_stages[0].character_asset);
});

test("catalog command rejects incomplete evolution chains and non-admin surfaces", () => {
  assert.throws(
    () =>
      normalizeCatalogPayload(
        avatarSeriesPayload({ character_stages: [{ stage: 1 }] }),
      ),
    error => error.code === "invalid-argument",
  );
  assert.throws(
    () =>
      normalizeCatalogCommand({
        action: "publish",
        itemId: "catalog-item-001",
        clientRequestId: "catalog-request-001",
        sourceSurface: "web",
        payload: avatarSeriesPayload(),
      }),
    error => error.code === "invalid-argument",
  );
});

test("catalog handler rejects unauthenticated and non-staff accounts", async () => {
  const firestore = fakeFirestore({
    "users/member-one": { staffRole: "member" },
  });
  const handler = createManageCatalogItemHandler({
    firestore,
    clock: () => new Date("2026-07-29T04:00:00.000Z"),
  });
  const data = {
    action: "publish",
    itemId: "catalog-item-001",
    clientRequestId: "catalog-request-001",
    sourceSurface: "admin_web",
    payload: avatarSeriesPayload(),
  };

  await assert.rejects(
    () => handler({ auth: null, data }),
    error => error.code === "unauthenticated",
  );
  await assert.rejects(
    () => handler({ auth: { uid: "member-one" }, data }),
    error => error.code === "permission-denied",
  );
});

test("catalog publish allocates collision-free indexes and one immutable audit", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "operator" },
    "shop_items/legacy-series": {
      type: "avatar_series",
      catalog_index_base: 40,
      character_stages: [
        { catalog_index: 40 },
        { catalog_index: 41 },
        { catalog_index: 42 },
      ],
    },
    "catalog_counters/avatar_series": { next_index: 30 },
  });
  const handler = createManageCatalogItemHandler({
    firestore,
    clock: () => new Date("2026-07-29T04:00:00.000Z"),
  });
  const request = {
    auth: { uid: "admin-one", token: { email: "admin@example.com" } },
    data: {
      action: "publish",
      itemId: "catalog-item-001",
      clientRequestId: "catalog-request-001",
      sourceSurface: "admin_web",
      payload: avatarSeriesPayload(),
    },
  };

  const first = await handler(request);
  const replay = await handler(request);
  const item = firestore.documents.get("shop_items/catalog-item-001");
  const audits = [...firestore.documents.keys()].filter(path =>
    path.startsWith("audit_events/"),
  );

  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(first.itemId, "catalog-item-001");
  assert.equal(item.catalog_index_base, 43);
  assert.deepEqual(
    item.character_stages.map(stage => stage.catalog_index),
    [43, 44, 45],
  );
  assert.equal(
    firestore.documents.get("catalog_counters/avatar_series").next_index,
    46,
  );
  assert.equal("created_by_email" in item, false);
  assert.equal(audits.length, 1);
  assert.equal(
    firestore.documents.get(audits[0]).action,
    "catalog.item.publish",
  );
});

test("catalog publish reserves each avatar series key", async () => {
  const firestore = fakeFirestore({
    "users/admin-one": { staffRole: "admin" },
    "shop_items/existing-series": {
      type: "avatar_series",
      series: { key: "night-academy" },
      status: "archived",
    },
  });
  const handler = createManageCatalogItemHandler({
    firestore,
    clock: () => new Date("2026-07-29T04:00:00.000Z"),
  });

  await assert.rejects(
    () =>
      handler({
        auth: { uid: "admin-one" },
        data: {
          action: "publish",
          itemId: "catalog-item-001",
          clientRequestId: "catalog-request-001",
          sourceSurface: "admin_web",
          payload: avatarSeriesPayload(),
        },
      }),
    error => error.code === "already-exists",
  );
  assert.equal(
    firestore.documents.has("shop_items/catalog-item-001"),
    false,
  );
});

test("catalog update preserves indexes and archive is audited", async () => {
  const existing = {
    ...normalizeCatalogPayload(avatarSeriesPayload()),
    id: "catalog-item-001",
    catalog_index_base: 43,
    character_stages: normalizeCatalogPayload(
      avatarSeriesPayload(),
    ).character_stages.map((stage, index) => ({
      ...stage,
      catalog_index: 43 + index,
    })),
    created_at: 1_700_000_000,
    updated_at: 1_700_000_000,
  };
  const firestore = fakeFirestore({
    "users/admin-one": { developerAccess: true },
    "shop_items/catalog-item-001": existing,
  });
  const handler = createManageCatalogItemHandler({
    firestore,
    clock: () => new Date("2026-07-29T04:00:00.000Z"),
  });

  const update = await handler({
    auth: { uid: "admin-one" },
    data: {
      action: "update",
      itemId: "catalog-item-001",
      clientRequestId: "catalog-update-001",
      sourceSurface: "admin_web",
      payload: avatarSeriesPayload({ name: "夜影學院・新版" }),
    },
  });
  const archived = await handler({
    auth: { uid: "admin-one" },
    data: {
      action: "archive",
      itemId: "catalog-item-001",
      clientRequestId: "catalog-archive-001",
      sourceSurface: "admin_web",
    },
  });

  assert.equal(update.item.name, "夜影學院・新版");
  assert.equal(update.item.catalog_index_base, 43);
  assert.deepEqual(
    update.item.character_stages.map(stage => stage.catalog_index),
    [43, 44, 45],
  );
  assert.equal(update.item.created_at, 1_700_000_000);
  assert.equal(archived.item.status, "archived");
  assert.equal(firestore.documents.get("shop_items/catalog-item-001").status, "archived");
  assert.equal(
    [...firestore.documents.keys()].filter(path =>
      path.startsWith("audit_events/"),
    ).length,
    2,
  );
});
