// #82 slice 3: Web cabin, shop and planet. Pure rules plus page structure.
// Web <-> Cloud command compatibility is checked against the real handlers in
// functions/test/web_cabin_shop_contract.test.js.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const vm = require('node:vm');

const cabin = require('../web_dashboard/assets/cabin_core.js');
const shop = require('../web_dashboard/assets/reward_shop_core.js');
const planet = require('../web_dashboard/assets/planet_core.js');
const routes = require('../web_dashboard/assets/town_routes.js');

const read = file => fs.readFileSync(file, 'utf8');
const catalog = JSON.parse(read('web_dashboard/assets/home/home_decor_catalog.json'));
const layout = JSON.parse(read('web_dashboard/assets/home/cabin_layout.json'));
const sha = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
// Firestore writes look like doc(...).set/update/delete or collection(...).add.
const FIRESTORE_WRITE = /\.doc\([^)]*\)\s*\.(set|update|delete)\(|collection\([^)]*\)\s*\.add\(|runTransaction|batch\(\)/;
const inlineScripts = html => [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);

test('the Web cabin art and catalog are byte-identical copies of the App assets', () => {
  const files = fs.readdirSync('assets/home').filter(f => /\.(png|json)$/.test(f));
  assert.ok(files.includes('room_base.png') && files.includes('home_decor_catalog.json'));
  for (const file of files) {
    assert.equal(sha(`web_dashboard/assets/home/${file}`), sha(`assets/home/${file}`), file);
  }
  assert.deepEqual(catalog, JSON.parse(read('functions/src/home-decor-catalog.json')));
  for (const layer of Object.values(layout.layers)) {
    for (const src of layer.images) assert.ok(fs.existsSync(`web_dashboard/${src}`), src);
  }
});

test('only free defaults and owned variants can be placed', () => {
  const owned = cabin.ownedVariants(catalog, ['homeDecor:101', 'faceShape:3', 7]);
  assert.deepEqual([...owned.get('rug')], [0]);
  assert.deepEqual([...owned.get('curtain')].sort(), [0, 1]);
  const draft = cabin.normalizeArrangement({}, catalog);
  assert.deepEqual(draft, { rug: 0, curtain: 0, lamp: 0 });
  assert.equal(cabin.choose(draft, owned, 'lamp', 2), draft, 'unowned lamp is refused');
  const next = cabin.choose(draft, owned, 'curtain', 1);
  assert.deepEqual(next, { rug: 0, curtain: 1, lamp: 0 });
  assert.equal(cabin.isDirty(next, draft), true);
  assert.equal(cabin.isDirty(draft, { ...draft }), false);
});

test('a saved arrangement is normalized and never shows an item no longer owned', () => {
  const owned = cabin.ownedVariants(catalog, ['homeDecor:2']);
  assert.deepEqual(cabin.visibleArrangement({ rug: 2, curtain: 9, lamp: '1', sofa: 1 }, catalog, owned),
    { rug: 2, curtain: 0, lamp: 0 });
  assert.deepEqual(cabin.visibleArrangement({ rug: 1, curtain: 0, lamp: 0 }, catalog, owned),
    { rug: 0, curtain: 0, lamp: 0 }, 'rug 1 is not owned');
});

test('cabin layers follow the App layout and the arrange command is well formed', () => {
  const layers = cabin.decorLayers(layout, { rug: 1, curtain: 0, lamp: 2 });
  assert.deepEqual(layers.map(l => [l.slot, l.src]), [
    ['rug', 'assets/home/rug_1.png'], ['curtain', 'assets/home/curtain_0.png'], ['lamp', 'assets/home/lamp_2.png'],
  ]);
  const id = cabin.newRequestId(Date.parse('2026-11-23T10:00:00Z'), () => 0.123456789);
  assert.match(id, cabin.REQUEST_ID);
  assert.deepEqual(cabin.arrangeCommand({ lamp: 1 }, catalog, id),
    { arrangement: { rug: 0, curtain: 0, lamp: 1 }, clientRequestId: id, sourceSurface: 'web' });
  assert.equal(cabin.validArrangeResult({ homeDecor: { rug: 0, curtain: 0, lamp: 1 } }, { rug: 0, curtain: 0, lamp: 1 }), true);
  assert.equal(cabin.validArrangeResult({ homeDecor: { rug: 0, curtain: 0, lamp: 0 } }, { rug: 0, curtain: 0, lamp: 1 }), false);
  assert.equal(cabin.characterSprite({ avatarProfile: { faceShapeIndex: 4 } }), 'assets/avatar/characters/character_4.png');
  assert.equal(cabin.characterSprite(null), 'assets/avatar/characters/character_0.png');
});

test('save failures are explained honestly', () => {
  assert.equal(cabin.arrangeError({ code: 'functions/failed-precondition', message: 'Only owned home decor variants can be arranged.' }).kind, 'not-owned');
  const network = cabin.arrangeError({ code: 'functions/unavailable', message: '' });
  assert.equal(network.kind, 'network');
  assert.equal(network.saved, 'unknown');
  assert.equal(cabin.arrangeError({ code: 'unavailable', message: 'Home decor changes are temporarily paused for a ledger cutover.' }).kind, 'paused');
  assert.equal(cabin.arrangeError({ code: 'invalid-argument' }).saved, 'no');
});

test('shop listings come only from published, in-window catalog data and the shared decor catalog', () => {
  const now = 1_800_000_000;
  const stages = price => [
    { stage: 1, catalog_index: 40, shop_eligible: true, coin_price: price, name: '小火' },
    { stage: 2, catalog_index: 41, shop_eligible: false, coin_price: 0 },
    { stage: 3, catalog_index: 42, shop_eligible: false, coin_price: 0 },
  ];
  const items = [
    { id: 'a', status: 'published', type: 'avatar_series', name: '火焰系', character_stages: stages(80) },
    { id: 'b', status: 'draft', type: 'avatar_series', character_stages: stages(80) },
    { id: 'c', status: 'published', type: 'limited', end_time: now - 1, character_stages: stages(80) },
    { id: 'd', status: 'published', type: 'limited', start_time: now + 10, character_stages: stages(80) },
    { id: 'e', status: 'published', type: 'limited', end_time: now + 100, character_stages: stages(0) },
  ];
  const list = shop.characterListings(items, now, ['faceShape:40']);
  assert.deepEqual(list.map(x => [x.id, x.tab, x.price, x.owned]), [['a', 'permanent', 80, true]]);
  const decor = shop.decorListings(catalog, ['homeDecor:202']);
  assert.deepEqual(decor.map(x => x.itemKey), ['homeDecor:1', 'homeDecor:2', 'homeDecor:101', 'homeDecor:102', 'homeDecor:201', 'homeDecor:202']);
  assert.ok(decor.every(x => x.price > 0), 'free defaults are not sold');
  assert.equal(decor.find(x => x.itemKey === 'homeDecor:202').owned, true);
  for (const x of decor) assert.ok(fs.existsSync(`web_dashboard/${x.image}`), x.image);
});

test('purchase buttons explain state, and one item cannot be sent twice at once', () => {
  const [item] = shop.decorListings(catalog, []);
  assert.deepEqual(shop.buttonState(item, { signedIn: true, balance: 10, busy: false }),
    { disabled: true, label: `還差 ${item.price - 10} 幣`, reason: 'balance' });
  assert.equal(shop.buttonState(item, { signedIn: true, balance: 999, busy: false }).disabled, false);
  assert.equal(shop.buttonState(item, { signedIn: true, balance: 999, busy: true }).label, '兌換中…');
  assert.equal(shop.buttonState({ ...item, owned: true }, { signedIn: true, balance: 999 }).label, '已擁有');
  assert.equal(shop.buttonState(item, { signedIn: false }).login, true);
  const flight = shop.createInFlight();
  assert.equal(flight.start(item.itemKey), true);
  assert.equal(flight.start(item.itemKey), false, 'double click is ignored');
  flight.finish(item.itemKey);
  assert.equal(flight.start(item.itemKey), true);
  assert.deepEqual(shop.purchaseCommand(item), shop.purchaseCommand(item), 'retries reuse the same request id');
});

test('purchase failures say whether coins were taken', () => {
  const cases = [
    [{ code: 'functions/failed-precondition', message: 'The discipline coin balance is insufficient.' }, 'balance', 'no'],
    [{ code: 'functions/not-found', message: 'The catalog item is not available.' }, 'gone', 'no'],
    [{ code: 'functions/unavailable', message: 'Reward purchases are temporarily paused for a ledger cutover.' }, 'paused', 'no'],
    [{ code: 'functions/unavailable', message: 'unavailable' }, 'network', 'unknown'],
    [{ code: 'functions/deadline-exceeded' }, 'network', 'unknown'],
    [new TypeError('Failed to fetch'), 'network', 'unknown'],
    [{ code: 'functions/unauthenticated' }, 'login', 'no'],
  ];
  for (const [error, kind, charged] of cases) {
    const out = shop.purchaseError(error);
    assert.equal(out.kind, kind, JSON.stringify(error));
    assert.equal(out.charged, charged, JSON.stringify(error));
  }
});

test('the shop page has no client-side discount or fake success, and its scripts parse', () => {
  const html = read('web_dashboard/operations.html');
  assert.doesNotMatch(html, /nudgeActiveDiscount|兌換成功！以優惠價|alert\(/);
  assert.doesNotMatch(html, /品牌日|降低 10%|即將推出/);
  for (const source of inlineScripts(html)) assert.doesNotThrow(() => new vm.Script(source));
  const core = html.indexOf('assets/reward_shop_core.js');
  const page = html.indexOf('assets/reward_shop.js');
  assert.ok(core > 0 && page > core && html.indexOf('assets/app.js') > page);
  assert.match(html, /data-tab="decor"/);
  const js = read('web_dashboard/assets/reward_shop.js');
  assert.doesNotMatch(js, FIRESTORE_WRITE, 'the shop never writes balances or items itself');
  assert.doesNotMatch(js, /disciplineCoins\s*[-+]=/);
  assert.match(js, /httpsCallable\('purchaseRewardItem'\)/);
});

test('the cabin page is a login page in the route table and only writes through the callable', () => {
  const dest = routes.DESTINATIONS.find(x => x.id === 'cabin-scene');
  assert.equal(dest.status, 'available');
  assert.equal(dest.href, 'cabin.html');
  const publicLine = read('web_dashboard/assets/app.js').split('\n').find(l => l.startsWith('const isPublicPage'));
  assert.doesNotMatch(publicLine, /cabin/);
  const html = read('web_dashboard/cabin.html');
  assert.match(html, /data-town-return="cabin"/);
  const order = ['town_routes.js', 'town_return.js', 'cabin_core.js', 'cabin.js', 'app.js'].map(f => html.indexOf(`assets/${f}`));
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  assert.ok(order.every(i => i > 0));
  const js = read('web_dashboard/assets/cabin.js');
  assert.match(js, /httpsCallable\('arrangeHomeDecor'\)/);
  assert.doesNotMatch(js, FIRESTORE_WRITE, 'no direct Firestore writes');
});

test('the planet shows only real unlocks and never invents planet kinds', () => {
  assert.deepEqual(planet.planets({ unlockedPlanets: ['新手星球', '熔岩星球', ''] }).nodes, [{ name: '熔岩星球', color: '#ef4444' }]);
  const old = planet.planets({ planetCount: 3 });
  assert.equal(old.source, 'count');
  assert.equal(old.count, 3);
  assert.ok(old.nodes.every(n => n.name === '星球（類型未記錄）'));
  assert.match(old.note, /沒有記錄星球類型/);
  assert.equal(planet.planets({ unlockedPlanets: [], planetCount: 5 }).count, 0, 'named list wins over the old count');
  assert.equal(planet.planets(null).count, 0);
  assert.equal(planet.planets({ planetCount: 1000 }).nodes.length, planet.MAX_SHOWN);
  const html = read('web_dashboard/planet.html');
  assert.doesNotMatch(html.replace(/\/\/.*$/gm, ''), /an_nudge|nudgeActiveDemoUserId|planetsPool/);
  assert.match(html, /collection\('users'\)\.doc\(user\.uid\)/);
  for (const source of inlineScripts(html)) assert.doesNotThrow(() => new vm.Script(source));
});
