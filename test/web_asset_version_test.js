const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const webRoot = path.resolve(__dirname, "..", "web_dashboard");

test("every Web page loads the current shared app bundle", () => {
  const pages = fs.readdirSync(webRoot)
    .filter(name => name.endsWith(".html"));
  const versions = [];
  for (const page of pages) {
    const html = fs.readFileSync(path.join(webRoot, page), "utf8");
    for (const match of html.matchAll(/assets\/app\.js\?v=(\d+)/g)) {
      versions.push({ page, version: match[1] });
    }
  }

  assert.ok(versions.length > 20);
  assert.deepEqual(
    [...new Set(versions.map(item => item.version))],
    ["20"],
  );
});
