const fs = require("node:fs");
const path = require("node:path");

function normalizedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildWebRuntimeConfig({
  firebaseAppCheckSiteKey,
  environment = "production",
}) {
  const siteKey = normalizedString(firebaseAppCheckSiteKey);
  const deploymentEnvironment = normalizedString(environment) || "production";
  if (
    siteKey.length < 20 ||
    /\s/.test(siteKey) ||
    /replace|placeholder|example/i.test(siteKey)
  ) {
    throw new Error(
      "NUDGE_FIREBASE_APP_CHECK_SITE_KEY must contain the real public App Check site key.",
    );
  }
  if (!/^[a-z0-9_-]{2,32}$/i.test(deploymentEnvironment)) {
    throw new Error("NUDGE_WEB_ENVIRONMENT is invalid.");
  }
  return Object.freeze({
    environment: deploymentEnvironment,
    firebaseAppCheckSiteKey: siteKey,
  });
}

function renderWebRuntimeConfig(config) {
  return [
    "window.NUDGE_RUNTIME_CONFIG = Object.freeze(",
    `${JSON.stringify(config, null, 2)});`,
    "",
  ].join("\n");
}

function parseOutputArgument(argv) {
  const outputIndex = argv.indexOf("--output");
  if (outputIndex === -1 || !argv[outputIndex + 1]) {
    throw new Error("--output <path> is required.");
  }
  return path.resolve(argv[outputIndex + 1]);
}

function main() {
  const config = buildWebRuntimeConfig({
    firebaseAppCheckSiteKey:
      process.env.NUDGE_FIREBASE_APP_CHECK_SITE_KEY,
    environment: process.env.NUDGE_WEB_ENVIRONMENT,
  });
  const outputPath = parseOutputArgument(process.argv.slice(2));
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, renderWebRuntimeConfig(config), {
    encoding: "utf8",
    mode: 0o644,
  });
  console.log(`Generated public Web runtime config: ${outputPath}`);
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}

module.exports = {
  buildWebRuntimeConfig,
  renderWebRuntimeConfig,
};
