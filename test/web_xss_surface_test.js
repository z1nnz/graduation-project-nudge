const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8").replace(/\r\n/g, "\n");
const app = read("web_dashboard/assets/app.js");

function extractFunction(name) {
  const start = app.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = app.indexOf("\n}\n", start);
  return app.slice(start, end + 2);
}

function loadEscapers() {
  const context = {};
  vm.runInNewContext(
    `${extractFunction("escapeHtml")}\n${extractFunction("jsStringArg")}\n` +
      "this.escapeHtml = escapeHtml; this.jsStringArg = jsStringArg;",
    context,
  );
  return context;
}

function decodeHtmlAttribute(value) {
  return value
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

test("jsStringArg keeps hostile ids inside one JS string argument", () => {
  const { jsStringArg } = loadEscapers();
  const hostile = `x');alert(1);//"<img src=x onerror=alert(2)>`;
  const attribute = jsStringArg(hostile);

  assert.doesNotMatch(attribute, /["'<>]/);
  const handlerSource = decodeHtmlAttribute(attribute);
  assert.equal(vm.runInNewContext(`(${handlerSource})`), hostile);
});

test("AI assistant renders chat text without HTML and confirms data actions", () => {
  const navigator = app.slice(
    app.indexOf("function injectAINavigator"),
    app.indexOf("window.bindMissions = function"),
  );

  assert.doesNotMatch(navigator, /body\.innerHTML\s*\+=/);
  assert.doesNotMatch(navigator, /loadingMsg\.innerHTML/);
  assert.match(navigator, /loadingMsg\.textContent = reply\.trim\(\)/);
  assert.match(navigator, /appendActionConfirm\(loadingMsg, `新增任務/);
  assert.match(navigator, /appendActionConfirm\(loadingMsg, `完成任務/);
  // Data-changing actions only run from the confirm button callback.
  const beforeRender = navigator.slice(
    navigator.indexOf("const taskMatch"),
    navigator.indexOf("loadingMsg.textContent = reply.trim()"),
  );
  assert.doesNotMatch(beforeRender, /addFirestoreTask|completeFirestoreTask/);
});

test("profile timeline escapes user-authored posts and comments", () => {
  const feed = app.slice(
    app.indexOf("// Dynamic Timeline Feed"),
    app.indexOf("feedContainer.innerHTML = postsHtml"),
  );

  for (const sink of [
    "${escapeHtml(post.content)}",
    "${escapeHtml(c.text)}",
    "${escapeHtml(c.author)}",
    "${escapeHtml(nickname)}",
    "${escapeHtml(post.dateStr)}",
  ]) {
    assert.ok(feed.includes(sink), `missing ${sink}`);
  }
  assert.doesNotMatch(feed, /\$\{(post\.content|c\.text|c\.author|nickname)\}/);
  assert.doesNotMatch(feed, /\('\$\{post\.id\}'/);
});

test("profile edit modal escapes stored nickname and signature", () => {
  assert.match(app, /value="\$\{escapeHtml\(data\.nickname \|\| ''\)\}"/);
  assert.match(app, /value="\$\{escapeHtml\(data\.signature \|\| ''\)\}"/);
});
