const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  buildWebRuntimeConfig,
  renderWebRuntimeConfig,
} = require("../scripts/generate_web_runtime_config.cjs");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("runtime config generator accepts only an explicit App Check site key", () => {
  assert.throws(
    () => buildWebRuntimeConfig({ firebaseAppCheckSiteKey: "" }),
    /real public App Check site key/,
  );
  assert.throws(
    () =>
      buildWebRuntimeConfig({
        firebaseAppCheckSiteKey: "replace-with-site-key",
      }),
    /real public App Check site key/,
  );

  const config = buildWebRuntimeConfig({
    firebaseAppCheckSiteKey: "6Lc-real-public-site-key-123456",
    environment: "production",
  });
  const rendered = renderWebRuntimeConfig(config);
  assert.equal(config.environment, "production");
  assert.match(rendered, /firebaseAppCheckSiteKey/);
  assert.doesNotMatch(rendered, /DEBUG_TOKEN|debugToken/);
});

test("Web loads runtime config before Firebase App Check", () => {
  const app = read("web_dashboard/assets/app.js");
  const workflow = read(".github/workflows/pages.yml");
  const gitignore = read(".gitignore");

  assert.match(app, /function loadWebRuntimeConfig\(\)/);
  assert.match(
    app,
    /loadWebRuntimeConfig\(\)[\s\S]*configureFirebaseAppCheckDebugToken\(\)[\s\S]*loadFirebaseSDKs\(\)/,
  );
  assert.match(
    app,
    /window\.NUDGE_RUNTIME_CONFIG\?\.firebaseAppCheckSiteKey/,
  );
  assert.match(
    workflow,
    /vars\.NUDGE_FIREBASE_APP_CHECK_SITE_KEY/,
  );
  assert.match(workflow, /generate_web_runtime_config\.cjs/);
  assert.match(gitignore, /runtime-config\.js/);
});

test("App Check debug tokens are opt-in and localhost-only", () => {
  const app = read("web_dashboard/assets/app.js");

  assert.match(app, /\["localhost", "127\.0\.0\.1", "::1"\]/);
  assert.match(app, /window\.NUDGE_FIREBASE_APP_CHECK_DEBUG_TOKEN/);
  assert.doesNotMatch(
    read("web_dashboard/assets/runtime-config.example.js"),
    /DEBUG_TOKEN|debugToken/,
  );
});
