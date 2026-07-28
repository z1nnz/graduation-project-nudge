const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

test("group overview exposes canonical publications to members", () => {
  const html = read("web_dashboard/groups.html");
  const app = read("web_dashboard/assets/app.js");

  assert.match(html, /data-group-challenge-list/);
  assert.match(html, /data-group-schedule-list/);
  assert.match(html, /data-group-template-list/);
  assert.match(app, /function renderCanonicalGroupOverview/);
  assert.match(app, /template\.strategy/);
  assert.match(app, /const canReadPublications = isPreviewMode\(\) \|\| Boolean\(activeWebGroup\)/);
  assert.match(app, /function clearCanonicalGroupPublications/);
  assert.match(read("web_dashboard/assets/styles.css"), /\.center-hub \.hub-card\[hidden\]/);
});

test("app consumes the same canonical publication fields and full template list", () => {
  const state = read("lib/state/app_state.dart");
  const screen = read("lib/screens/group_management_page.dart");

  assert.match(state, /List<Map<String, dynamic>> get groupTemplates/);
  assert.match(state, /\.collection\('templates'\)[\s\S]*?\.limit\(50\)/);
  assert.match(state, /challenge\['groupName'\]/);
  assert.match(screen, /challenge\['groupName'\]/);
  assert.match(screen, /template\['strategy'\]/);
  assert.doesNotMatch(screen, /template\['pressure'\]/);
});

test("group challenge participation is shared and member-controlled", () => {
  const app = read("web_dashboard/assets/app.js");
  const state = read("lib/state/app_state.dart");
  const rules = read("firestore.rules");
  const overview = read("web_dashboard/groups.html");

  assert.match(overview, /目前挑戰與我的參與/);
  assert.match(app, /function joinCanonicalWebGroupChallenge/);
  assert.match(
    app,
    /\.collection\("challenges"\)[\s\S]*?\.collection\("participants"\)/,
  );
  assert.match(app, /data-join-current-challenge/);
  assert.match(state, /currentGroupChallengeParticipation/);
  assert.match(state, /GroupChallengeTaskPlan\.missingTasks/);
  assert.match(state, /GroupChallengeTaskPlan\.completedDays/);
  assert.match(
    state,
    /GroupChallengeTaskPlan\.isGroupChallengeTask\(task\)\) return 0/,
  );
  assert.match(
    rules,
    /match \/participants\/\{memberId\}[\s\S]*?request\.auth\.uid == memberId/,
  );
});

test("group surfaces do not ship fabricated outcomes", () => {
  const overview = read("web_dashboard/groups.html");
  const ranking = read("web_dashboard/groups-ranking.html");
  const schedule = read("web_dashboard/groups-study-schedule.html");

  assert.doesNotMatch(overview, /4 個企業挑戰|8 個讀書會房間/);
  assert.doesNotMatch(ranking, /842|798|751|匯出週報 Demo/);
  assert.doesNotMatch(schedule, /42 位學生/);
  assert.match(ranking, /尚未產生/);
});

test("group member management uses canonical membership and consent summaries", () => {
  const app = read("web_dashboard/assets/app.js");
  const ranking = read("web_dashboard/groups-ranking.html");

  assert.match(app, /\.collection\("member_summaries"\)/);
  assert.match(app, /function renderCanonicalWebGroupMembers/);
  assert.match(app, /function renderCanonicalGroupRanking/);
  assert.match(app, /removeCanonicalWebGroupMember/);
  assert.match(app, /transferCanonicalWebGroupOwnership/);
  assert.doesNotMatch(
    app,
    /collection\("users"\)\.where\("groupId",\s*"==",\s*groupId\)/,
  );
  assert.match(ranking, /data-group-ranking-list/);
  assert.match(ranking, /只有成員主動分享/);
});

test("social lookup reads the explicit public profile projection", () => {
  const app = read("web_dashboard/assets/app.js");
  const state = read("lib/state/app_state.dart");
  const friendPage = read("lib/screens/friend_public_profile_page.dart");
  const friendWeb = read("web_dashboard/friend.html");
  const postLogic = read("web_dashboard/js/post_logic.js");

  assert.match(app, /function buildWebPublicProfile/);
  assert.match(app, /collection\("public_profiles"\)/);
  assert.doesNotMatch(
    app,
    /collection\("users"\)\.where\("(?:username|myNudgeId)"/,
  );
  assert.match(state, /\.collection\('public_profiles'\)/);
  assert.doesNotMatch(state, /candidate_mina|NDG-MINA01|NDG-RAY777/);
  assert.doesNotMatch(
    state,
    /\.collection\('users'\)\s*\.where\('username'/,
  );
  assert.match(friendPage, /\.collection\('public_profiles'\)/);
  assert.match(friendWeb, /collection\("public_profiles"\)/);
  assert.doesNotMatch(
    friendWeb,
    /collection\("users"\)\.(?:doc\(friendId\)\.get|where\("myNudgeId")/,
  );
  assert.doesNotMatch(friendWeb, /sleepHours:\s*7\.5|steps:\s*3000/);
  assert.match(friendWeb, /function escapeFriendHtml/);
  assert.match(friendWeb, /function inlineFriendArgument/);
  assert.match(friendWeb, /escapeFriendHtml\(f\.name\)/);
  assert.match(friendWeb, /escapeFriendHtml\(userData\.nickname\)/);
  assert.doesNotMatch(friendWeb, /\$\{f\.(?:name|signature)\}/);
  assert.match(postLogic, /function requireOwnProfileId/);
  assert.match(
    app,
    /私人自律動態不會公開讀取/,
  );
});

test("friend acceptance and removal stay atomic across App and Web", () => {
  const rules = read("firestore.rules");
  const state = read("lib/state/app_state.dart");
  const friendWeb = read("web_dashboard/friend.html");

  assert.match(rules, /function acceptedFriendshipAfterByReceiver/);
  assert.match(rules, /function removedFriendshipAfter/);
  assert.match(rules, /request\.resource\.data\.status == 'removed'/);
  assert.match(state, /batch\.update\(docRef, \{'status': 'accepted'\}\)/);
  assert.match(state, /batch\.set\(myFriendRef, myFriendProfile\.toJson\(\)\)/);
  assert.match(
    state,
    /batch\.update\(acceptedRequest, \{'status': 'removed'\}\)/,
  );
  assert.match(friendWeb, /batch\.update\(requestRef, \{ status: "accepted" \}\)/);
  assert.match(friendWeb, /batch\.update\(acceptedRequest, \{ status: "removed" \}\)/);
  assert.match(friendWeb, /\.where\("senderId", "==", activeUserId\)/);
});
