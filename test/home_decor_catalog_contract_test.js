const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));

test('App and Cloud share one home decor catalog', () => {
  const app = read('assets/home/home_decor_catalog.json');
  const cloud = read('functions/src/home-decor-catalog.json');
  assert.deepEqual(app, cloud);
  assert.deepEqual(app.slots.map(slot => slot.slot), ['rug', 'curtain', 'lamp']);
  for (const slot of app.slots) {
    assert.equal(slot.variants[0].index, 0);
    assert.equal(slot.variants[0].price, 0, `${slot.slot} default must be free`);
    for (const variant of slot.variants.slice(1)) {
      assert.ok(Number.isInteger(variant.price) && variant.price >= 1 && variant.price <= 200,
        `${slot.slot}:${variant.index} price`);
    }
  }
});
