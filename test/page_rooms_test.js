'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const web = path.join(__dirname, '..', 'web_dashboard');
const read = f => fs.readFileSync(path.join(web, f), 'utf8');
const box = {};
const ctx = vm.createContext({ globalThis: box });
vm.runInContext(read('assets/page_rooms.js'), ctx);
vm.runInContext(read('assets/page_rooms_home.js'), ctx);
const rooms = box.NudgePageRooms;

test('each page room points its objects at sections that exist on that page', () => {
  const pages = { privacy: 'privacy.html', quests: 'quests.html', login: 'login.html' };
  for (const [key, file] of Object.entries(pages)) {
    const room = rooms[key];
    assert.ok(room, key);
    assert.ok(fs.existsSync(path.join(web, room.art)), room.art);
    const html = read(file);
    assert.ok(html.includes('assets/page_room.js') && (html.includes('assets/page_rooms.js') || html.includes('assets/page_rooms_home.js')), `${file} loads the room`);
    for (const o of room.objects) {
      assert.ok(o.x >= 0 && o.y >= 0 && o.x + o.w <= 1.001 && o.y + o.h <= 1.001, `${key}.${o.id} fits the art`);
      assert.ok(o.section || o.href || o.say, `${key}.${o.id} does something`);
      if (!o.section) continue;
      const hook = o.section.match(/\[([\w-]+)\]|#([\w-]+)|\.([\w-]+)$/);
      const name = hook[1] || hook[2] || hook[3];
      assert.ok(html.includes(name), `${file} has ${o.section}`);
    }
  }
});

test('privacy keeps every consent and data-rights control, only moved behind objects', () => {
  const objects = rooms.privacy.objects.map(o => o.section);
  assert.ok(objects.includes('[data-privacy-data-rights]'));
  assert.ok(objects.includes('[data-privacy-consent]'));
  const html = read('privacy.html');
  for (const hook of ['data-privacy-accept', 'data-privacy-revoke', 'data-privacy-request-export', 'data-privacy-request-deletion']) {
    assert.ok(html.includes(hook), hook);
  }
  const room = read('assets/page_room.js');
  assert.doesNotMatch(room, /firestore|httpsCallable|\.remove\(\)/, 'sections are moved, never removed or rewritten');
});
