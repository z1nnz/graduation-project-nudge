const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync('web_dashboard/assets/companion_install.js', 'utf8');
function browser({ standalone = false, online = true } = {}) {
  const events = {};
  const nodes = Object.fromEntries(['companionInstallButton', 'companionInstallStatus', 'companionInstallHelp', 'companionNetworkStatus'].map(id => [id, {
    dataset: {}, hidden: id === 'companionInstallHelp', addEventListener(name, callback) { this[name] = callback; },
  }]));
  const context = { navigator: { onLine: online },
    matchMedia: () => ({ matches: standalone, addEventListener() {} }),
    addEventListener: (name, callback) => { events[name] = callback; },
    document: { getElementById: id => nodes[id], addEventListener() {} },
  };
  vm.runInNewContext(source, context);
  return { nodes, events, context };
}
test('unsupported install keeps manual guidance and network hints honest', async () => {
  const { nodes, events, context } = browser({ online: false });
  assert.equal(nodes.companionInstallButton.hidden, false);
  assert.equal(nodes.companionInstallButton.disabled, false);
  assert.match(nodes.companionNetworkStatus.textContent, /回報離線/);
  await nodes.companionInstallButton.click();
  assert.equal(nodes.companionInstallHelp.hidden, false);
  context.navigator.onLine = true;
  events.online();
  assert.match(nodes.companionNetworkStatus.textContent, /不代表 Cloud 已確認/);
});
test('retained browser prompt is one-use and acceptance alone is not installation', async () => {
  const { nodes, events } = browser();
  let calls = 0;
  events.beforeinstallprompt({ preventDefault() {}, prompt: async () => { calls++; }, userChoice: Promise.resolve({ outcome: 'accepted' }) });
  assert.equal(calls, 0);
  await nodes.companionInstallButton.click();
  await nodes.companionInstallButton.click();
  assert.equal(calls, 1);
  assert.match(nodes.companionInstallStatus.textContent, /已送出安裝要求/);
  events.appinstalled();
  assert.equal(nodes.companionInstallButton.hidden, true);
  assert.equal(nodes.companionInstallStatus.textContent, '瀏覽器已回報安裝完成');
  events.pageshow();
  assert.equal(nodes.companionInstallButton.hidden, true);
});
test('dismissal and prompt errors remain usable without retrying consumed events', async () => {
  for (const error of [false, true]) {
    const { nodes, events } = browser();
    events.beforeinstallprompt({ preventDefault() {}, prompt: async () => { if (error) throw new Error('unsupported'); }, userChoice: Promise.resolve({ outcome: 'dismissed' }) });
    await nodes.companionInstallButton.click();
    assert.equal(nodes.companionInstallButton.disabled, false);
    assert.equal(nodes.companionInstallHelp.hidden, false);
    assert.match(nodes.companionInstallStatus.textContent, error ? /未能開啟/ : /這次未安裝/);
  }
});
test('standalone mode does not offer redundant installation', () => {
  assert.equal(browser({ standalone: true }).nodes.companionInstallButton.hidden, true);
});
test('manifest is subdirectory-safe and references a real correctly sized icon', () => {
  const manifest = JSON.parse(fs.readFileSync('web_dashboard/manifest.webmanifest', 'utf8'));
  const base = new URL('https://example.test/repository/manifest.webmanifest');
  assert.equal(new URL(manifest.start_url, base).pathname, '/repository/dashboard.html');
  assert.equal(new URL(manifest.scope, base).pathname, '/repository/');
  const png = fs.readFileSync(path.join('web_dashboard', manifest.icons[0].src));
  assert.equal(`${png.readUInt32BE(16)}x${png.readUInt32BE(20)}`, manifest.icons[0].sizes);
  assert.doesNotMatch(source, /serviceWorker|caches\.|localStorage|requestPermission|indexedDB/);
});
