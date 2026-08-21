const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const manifest = fs.readFileSync(
  path.join(root, "android/app/src/main/AndroidManifest.xml"),
  "utf8",
);
const controller = fs.readFileSync(
  path.join(
    root,
    "android/app/src/main/kotlin/com/example/nudge/NudgeBleController.kt",
  ),
  "utf8",
);
const activity = fs.readFileSync(
  path.join(
    root,
    "android/app/src/main/kotlin/com/example/nudge/MainActivity.kt",
  ),
  "utf8",
);
const firmware = fs.readFileSync(
  path.join(root, "firmware/nudge_focus_device/src/main.cpp"),
  "utf8",
);

test("Android declares modern BLE permissions without location derivation", () => {
  assert.match(manifest, /android\.permission\.BLUETOOTH_SCAN/);
  assert.match(manifest, /usesPermissionFlags="neverForLocation"/);
  assert.match(manifest, /android\.permission\.BLUETOOTH_CONNECT/);
});

test("native BLE bridge binds only the Nudge service and characteristics", () => {
  assert.match(controller, /7df10000-4e55-4447-4500-4e5544474531/i);
  assert.match(controller, /7df10001-4e55-4447-4500-4e5544474531/i);
  assert.match(controller, /7df10002-4e55-4447-4500-4e5544474531/i);
  assert.match(controller, /7df10003-4e55-4447-4500-4e5544474531/i);
  assert.match(controller, /EventChannel/);
  assert.match(controller, /readPendingEvent/);
  assert.match(controller, /writeCommand/);
  assert.match(controller, /requestMtu\(TARGET_MTU\)/);
  assert.match(controller, /negotiatedMtu - ATT_HEADER_BYTES/);
  assert.match(firmware, /BLEDevice::setMTU\(517\)/);
  assert.match(activity, /NudgeBleController/);
});

test("firmware samples the room selector before lifecycle commands", () => {
  const loopStart = firmware.indexOf("void loop() {");
  const rotation = firmware.indexOf("handle_encoder_rotation();", loopStart);
  const commandQueue = firmware.indexOf("CommandMessage command{};", loopStart);
  const button = firmware.indexOf("handle_encoder_button();", loopStart);

  assert.notEqual(loopStart, -1);
  assert.ok(rotation > loopStart);
  assert.ok(rotation < commandQueue);
  assert.ok(rotation < button);
});
