const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { validatePlan, validateEvidence, buildTimeline, previewScene } = require("../scripts/validate_competition_demo_story.cjs");
const base = path.resolve(__dirname, "../docs/competition-demo/package02");
const load = name => JSON.parse(fs.readFileSync(path.join(base, name), "utf8"));

test("script has a contiguous 180-second narration and a separate 30-second P0-A loop", () => {
  const result = validatePlan(load("scenario.json"));
  assert.equal(result.narrationSeconds, 180);
  assert.equal(result.p0aSeconds, 30);
  assert.equal(result.homeLoopSeconds, 48);
});

test("paper timeline captures Complete before reset and returns to Home", () => {
  const plan = load("scenario.json");
  const timeline = buildTimeline(plan, 180000, 140000);
  assert.ok(timeline.some(r => r.sceneId === 5 && r.startMs === 129000));
  assert.ok(timeline.some(r => r.sceneId === 0 && r.startMs === 140000));
  assert.ok(timeline.some(r => r.sceneId === 1 && r.startMs === 141500));
  assert.equal(timeline.at(-1).endMs, 180000);
});

test("both device previews resolve shared data and visibly retain DEMO", () => {
  const plan = load("scenario.json");
  for (const device of ["orbit", "station"]) {
    const growth = previewScene(plan, 6, device);
    assert.equal(growth.badge, "DEMO");
    assert.match(growth.lines.join(" "), /小芽 LEVEL 7/);
    assert.match(growth.lines.join(" "), /DEMO XP \+10/);
  }
  assert.notDeepEqual(previewScene(plan, 1, "orbit"), previewScene(plan, 1, "station"));
});

for (const [name, mutate] of [
  ["missing completion", p => { p.p0a.sceneIds = [1, 3, 7]; }],
  ["ninth scene as loop target", p => { p.p0b.loopTo = 8; }],
  ["narration gap", p => { p.presentation.segments[1].startMs += 1000; }],
  ["unresolved display data", p => { p.scenes[1].station.lines.push("{{unknownMemberCount}}"); }],
  ["different device dataset", p => { p.deviceDataRefs.station = "stationData"; }],
  ["impossible room count", p => { p.data.roomActiveMembers = 6; }],
  ["reset before completion", p => { p.presentation.resetCueMs = 1000; }],
  ["overlong focus preview", p => { p.scenes[3].durationMs = 1500000; }],
  ["missing DEMO label", p => { p.demoBadge = ""; }],
  ["manual input required", p => { p.p0b.autoInputRequired = true; }]
]) {
  test(`validator rejects ${name}`, () => {
    const plan = load("scenario.json");
    mutate(plan);
    assert.throws(() => validatePlan(plan));
  });
}

test("capture checklist keeps all five required recordings pending", () => {
  validateEvidence(load("evidence.json"));
});

test("capture checklist rejects fabricated verification and recording paths", () => {
  const evidence = load("evidence.json");
  evidence.captures[2].verified = true;
  assert.throws(() => validateEvidence(evidence));
  evidence.captures[2].verified = false;
  evidence.captures[2].file = "not-recorded.mp4";
  assert.throws(() => validateEvidence(evidence));
});

test("spoken script matches the canonical data plan and all local document links resolve", () => {
  const plan = load("scenario.json");
  const script = fs.readFileSync(path.join(base, "presenter-script.md"), "utf8");
  for (const segment of plan.presentation.segments) assert.ok(script.includes(segment.spoken), segment.key);
  for (const file of fs.readdirSync(base).filter(name => name.endsWith(".md"))) {
    const body = fs.readFileSync(path.join(base, file), "utf8");
    assert.equal((body.match(/```/g) || []).length % 2, 0, file);
    const prose = body.replace(/```[\s\S]*?```/g, "");
    for (const match of prose.matchAll(/!?\[[^\]]*\]\(([^)]+)\)/g)) {
      const target = match[1];
      if (!target.includes("://") && !target.startsWith("#")) assert.ok(fs.existsSync(path.resolve(base, target.split("#")[0])), `${file}: ${target}`);
    }
    assert.ok(!body.includes("/Users/") && !body.includes("codex-remote-attachments"), file);
  }
});
