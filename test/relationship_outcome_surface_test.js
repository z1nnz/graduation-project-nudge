const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relativePath =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("App and Web consume the same Cloud-built relationship outcomes", () => {
  const appState = read("lib/state/app_state.dart");
  const guardianPage = read("lib/screens/guardian_center_page.dart");
  const groupPage = read("lib/screens/group_management_page.dart");
  const webApp = read("web_dashboard/assets/app.js");
  const guardianHtml = read("web_dashboard/guardian.html");
  const groupHtml = read("web_dashboard/groups.html");
  const cloudIndex = read("functions/index.js");

  assert.match(appState, /collection\('relationship_outcomes'\)/);
  assert.match(appState, /refreshFamilyRelationshipOutcome/);
  assert.match(appState, /refreshGroupRelationshipOutcome/);
  assert.match(guardianPage, /familyRelationshipMemories/);
  assert.match(groupPage, /groupRelationshipOutcome/);

  assert.match(webApp, /refreshRelationshipOutcome/);
  assert.match(webApp, /relationship_outcomes/);
  assert.match(webApp, /data-family-guardian-tools/);
  assert.match(webApp, /data-group-manager-tools/);
  assert.match(guardianHtml, /data-family-outcome/);
  assert.match(groupHtml, /data-group-outcome/);
  assert.match(cloudIndex, /export const refreshRelationshipOutcome/);
});

test("relationship growth is explicitly separated from personal rewards", () => {
  const familyPage = read("lib/screens/guardian_center_page.dart");
  const groupPage = read("lib/screens/group_management_page.dart");
  const guardianHtml = read("web_dashboard/guardian.html");
  const groupHtml = read("web_dashboard/groups.html");

  assert.match(familyPage, /不會變成任一方的個人獎勵/);
  assert.match(groupPage, /不發放個人 XP／自律幣/);
  assert.match(guardianHtml, /不會成為任一方的個人獎勵/);
  assert.match(groupHtml, /不發放個人 XP／自律幣/);
});
