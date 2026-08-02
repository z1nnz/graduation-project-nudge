const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sceneDelegate = fs.readFileSync(
  path.resolve(__dirname, "../ios/Runner/SceneDelegate.swift"),
  "utf8",
);

test("HealthKit statistics unwrap optional sources before mapping origins", () => {
  const safelyUnwrapped = sceneDelegate.match(
    /statistics\?\.sources\?\s*\.map\(\\\.bundleIdentifier\)/g,
  ) || [];

  assert.equal(safelyUnwrapped.length, 2);
  assert.doesNotMatch(
    sceneDelegate,
    /statistics\?\.sources\s*\.map\(\\\.bundleIdentifier\)/,
  );
});
