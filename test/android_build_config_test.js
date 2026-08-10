const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const appBuild = fs.readFileSync(
  path.resolve(__dirname, "../android/app/build.gradle.kts"),
  "utf8",
);
const mainActivity = fs.readFileSync(
  path.resolve(
    __dirname,
    "../android/app/src/main/kotlin/com/example/nudge/MainActivity.kt",
  ),
  "utf8",
);

test("Android build stays on the stable Health Connect and desugaring contract", () => {
  assert.match(
    appBuild,
    /implementation\("androidx\.health\.connect:connect-client:1\.1\.0"\)/,
  );
  assert.doesNotMatch(appBuild, /connect-client:1\.2\.0-alpha/);
  assert.match(appBuild, /minSdk\s*=\s*26/);
  assert.match(appBuild, /isCoreLibraryDesugaringEnabled\s*=\s*true/);
  assert.match(
    appBuild,
    /coreLibraryDesugaring\("com\.android\.tools:desugar_jdk_libs:2\.1\.4"\)/,
  );
});

test("Android Health Connect permission flow uses an Activity Result host", () => {
  assert.match(
    mainActivity,
    /class MainActivity\s*:\s*FlutterFragmentActivity\(\)/,
  );
  assert.match(mainActivity, /registerForActivityResult\(/);
  assert.doesNotMatch(mainActivity, /class MainActivity\s*:\s*FlutterActivity\(\)/);
});
