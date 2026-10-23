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

function loadTaskCompletion(tasks) {
  const queuedEvents = [];
  const context = {
    console,
    Date,
    localStorage: {
      getItem(key) {
        return key === "nudgeActiveDemoUserId" ? "user-1" : null;
      },
    },
    firebase: {
      auth() {
        return { currentUser: { uid: "user-1" } };
      },
    },
    db: {
      collection() {
        return {
          doc() {
            return {
              get() {
                return Promise.resolve({
                  exists: true,
                  data: () => ({ tasks }),
                });
              },
            };
          },
        };
      },
    },
    toast() {},
    window: {
      queueWebTaskLedgerEvent(event) {
        queuedEvents.push(event);
        return Promise.resolve();
      },
    },
  };
  vm.runInNewContext(
    `${extractFunction("completeFirestoreTask")}\n` +
      "this.completeFirestoreTask = completeFirestoreTask;",
    context,
  );
  return { completeFirestoreTask: context.completeFirestoreTask, queuedEvents };
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

test("AI task completion rejects stale or fuzzy task identifiers", async () => {
  const { completeFirestoreTask, queuedEvents } = loadTaskCompletion([
    { id: "current-task-id", title: "Review stale-task-id notes", isDone: false },
  ]);

  completeFirestoreTask("stale-task-id");
  await new Promise(resolve => setImmediate(resolve));

  assert.deepEqual(queuedEvents, []);

  completeFirestoreTask("current-task-id");
  await new Promise(resolve => setImmediate(resolve));

  assert.equal(queuedEvents.length, 1);
  assert.equal(queuedEvents[0].taskId, "current-task-id");
});

test("planet mission markup escapes every task id attribute", () => {
  const missions = app.slice(
    app.indexOf("window.bindFirestoreMissions = function"),
    app.indexOf("function addFirestoreTask"),
  );
  const taskIdAttributes = [...missions.matchAll(/data-task-id="\$\{([^}]+)\}"/g)]
    .map(match => match[1]);

  assert.ok(taskIdAttributes.length >= 3);
  assert.deepEqual([...new Set(taskIdAttributes)], ["escapeHtml(taskId)"]);
});

test("demo tool previews escape every value inserted into HTML", () => {
  const tools = extractFunction("bindExtensionTools");

  for (const safeMarkup of [
    "<strong>${escapeHtml(type)} ${days} 日模板</strong><p>每日 ${escapeHtml(effort)}，${escapeHtml(phase)}。",
    "<strong>${escapeHtml(group)}：${days} 日${escapeHtml(type)}</strong><p>獎勵為 ${escapeHtml(reward)}",
    "<strong>${escapeHtml(type)}</strong><p>${escapeHtml(privacy)}。",
    "<strong>${escapeHtml(building)}建築計畫</strong><p>解鎖條件：${escapeHtml(condition)}。${escapeHtml(event)}</p>",
    "我知道你現在是「${escapeHtml(state)}」。先做「${escapeHtml(action)}」",
    "<p>${escapeHtml(note)}</p>",
  ]) {
    assert.ok(tools.includes(safeMarkup), `missing safe markup: ${safeMarkup}`);
  }
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
