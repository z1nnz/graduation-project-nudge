const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sceneKeys = ["boot", "home", "ready", "focus", "encouragement", "complete", "growth", "summary"];

// Paper rehearsal only: these intervals do not execute or certify firmware.
function buildTimeline(plan, untilMs, restartAtMs = null) {
  const rows = [];
  let sceneId = 1;
  let now = 0;
  let restarted = false;
  while (now < untilMs) {
    if (!restarted && restartAtMs === now) {
      sceneId = 0;
      restarted = true;
    }
    const end = Math.min(now + plan.scenes[sceneId].durationMs, untilMs);
    if (!restarted && restartAtMs !== null && restartAtMs > now && restartAtMs < end) {
      rows.push({ sceneId, startMs: now, endMs: restartAtMs });
      now = restartAtMs;
      continue;
    }
    rows.push({ sceneId, startMs: now, endMs: end });
    now = end;
    sceneId = sceneId === 7 ? plan.p0b.loopTo : sceneId + 1;
  }
  return rows;
}

function previewScene(plan, sceneId, device) {
  const view = plan.scenes[sceneId][device];
  function expand(text) {
    return text.replace(/\{\{(\w+)\}\}/g, (_, key) => {
      assert.ok(Object.hasOwn(plan.data, key), `Unknown data token: ${key}`);
      return Array.isArray(plan.data[key]) ? plan.data[key].join("、") : String(plan.data[key]);
    });
  }
  return { badge: plan.demoBadge, title: expand(view.title), lines: view.lines.map(expand) };
}

function validatePlan(plan) {
  assert.equal(plan.kind, "presentation_plan");
  assert.equal(plan.runtimeImplemented, false, "A script plan is not firmware delivery");
  assert.equal(plan.deviceVerified, false, "No physical acceptance is claimed");
  assert.equal(plan.fictionalData, true);
  assert.equal(plan.demoBadge, "DEMO");
  assert.deepEqual(plan.deviceDataRefs, { orbit: "data", station: "data" }, "Both devices use the same dataset");
  assert.equal(plan.data.focusMinutes, 25);
  assert.equal(plan.data.focusPreviewSeconds * 1000, plan.scenes[3].durationMs);
  assert.ok(plan.data.roomActiveMembers >= 0 && plan.data.roomActiveMembers <= plan.data.roomTotalMembers);
  assert.ok(plan.data.todayCompleted <= plan.data.todayTaskTotal);
  assert.equal(plan.data.todayFocusMinutes, plan.data.todayCompleted * plan.data.focusMinutes);
  assert.ok(plan.data.demoElapsedMinutes <= plan.data.focusMinutes);
  assert.ok(Number.isInteger(plan.data.demoXp) && plan.data.demoXp >= 0);
  assert.ok(!/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(JSON.stringify(plan.data)), "No account data in fixtures");
  assert.deepEqual(plan.scenes.map(s => s.id), [0, 1, 2, 3, 4, 5, 6, 7]);
  assert.deepEqual(plan.scenes.map(s => s.key), sceneKeys);
  for (const scene of plan.scenes) {
    assert.ok(Number.isInteger(scene.durationMs) && scene.durationMs > 0);
    for (const device of ["orbit", "station"]) {
      assert.ok(scene[device].title && scene[device].lines.length > 0);
      previewScene(plan, scene.id, device);
    }
  }
  assert.ok(plan.scenes[3].durationMs >= 12000 && plan.scenes[3].durationMs <= 20000);
  assert.deepEqual(plan.p0a.sceneIds, [1, 3, 5], "P0-A includes Complete");
  assert.equal(plan.p0a.durationsMs.length, 3);
  assert.ok(plan.p0a.durationsMs.every(ms => Number.isInteger(ms) && ms > 0));
  assert.deepEqual(plan.p0a.durationsMs, [5000, plan.scenes[3].durationMs, 5000]);
  const shortMs = plan.p0a.durationsMs.reduce((sum, ms) => sum + ms, 0);
  assert.ok(shortMs >= 30000 && shortMs <= 60000);
  assert.equal(plan.p0a.loopTo, 1);
  assert.equal(plan.p0b.initialScene, 0);
  assert.equal(plan.p0b.loopTo, 1, "Summary returns Home without a ninth scene");
  assert.equal(plan.p0b.autoInputRequired, false);
  assert.deepEqual(plan.controlPriority, ["auto", "verified_physical_input", "board_reset_or_verified_serial", "optional_ble_app"]);
  assert.deepEqual(plan.failures.map(f => f.id), ["device_stuck", "input_unresponsive", "app_unavailable", "led_dark", "white_screen"]);
  assert.ok(plan.failures.every(f => f.action.length > 0));

  const p = plan.presentation;
  assert.equal(p.durationMs, 180000);
  assert.equal(p.startAnchor, "home");
  assert.ok(p.resetHomeTargetMs > p.resetCueMs && p.resetHomeTargetMs <= p.resetCueMs + 10000);
  let end = 0;
  for (const segment of p.segments) {
    assert.equal(segment.startMs, end, "Narration has no gaps or overlaps");
    assert.ok(segment.endMs > segment.startMs && segment.spoken.length > 0);
    assert.ok(segment.cueSceneIds.every(id => sceneKeys[id]));
    const chars = [...segment.spoken.replace(/[\s\p{P}\p{S}]/gu, "")].length;
    assert.ok(chars <= (segment.endMs - segment.startMs) / 1000 * 5, "Spoken text exceeds five characters/second budget");
    end = segment.endMs;
  }
  assert.equal(end, p.durationMs);
  const timeline = buildTimeline(plan, p.durationMs, p.resetCueMs);
  assert.ok(timeline.some(r => r.sceneId === 5 && r.endMs <= p.resetCueMs), "Complete precedes the reset cue");
  assert.ok(timeline.some(r => r.sceneId === 1 && r.startMs > p.resetCueMs && r.startMs <= p.resetHomeTargetMs), "Reset plan returns Home inside its target");
  for (const segment of p.segments) {
    assert.ok(segment.cueSceneIds.length === 0 || timeline.some(r => segment.cueSceneIds.includes(r.sceneId) && r.startMs < segment.endMs && r.endMs > segment.startMs), `No planned scene cue for ${segment.key}`);
  }
  return { p0aSeconds: shortMs / 1000, homeLoopSeconds: plan.scenes.slice(1).reduce((n, s) => n + s.durationMs, 0) / 1000, narrationSeconds: end / 1000, restartHomeTargetMs: p.resetHomeTargetMs };
}

function validateEvidence(evidence) {
  assert.equal(evidence.kind, "unverified_capture_checklist");
  assert.equal(evidence.deviceVerified, false);
  assert.equal(evidence.physicalAcceptanceDeferredByUser, true);
  assert.equal(evidence.measuredSpokenDurationSeconds, null);
  assert.deepEqual(evidence.captures.map(c => c.id), ["p0a_orbit", "p0a_station", "p0b_full", "p0b_orbit_closeup", "p0b_station_closeup"]);
  for (const capture of evidence.captures) {
    assert.equal(capture.verified, false, "Pending evidence cannot be marked verified");
    assert.equal(capture.file, null, "No invented film path");
    assert.equal(capture.sha256, null, "No invented film checksum");
  }
}

module.exports = { validatePlan, validateEvidence, buildTimeline, previewScene };

if (require.main === module) {
  try {
    const base = path.resolve(__dirname, "../docs/competition-demo/package02");
    const plan = JSON.parse(fs.readFileSync(path.join(base, "scenario.json"), "utf8"));
    const evidence = JSON.parse(fs.readFileSync(path.join(base, "evidence.json"), "utf8"));
    const summary = validatePlan(plan);
    validateEvidence(evidence);
    console.log(JSON.stringify({ planValid: true, physicalEvidenceVerified: false, ...summary }, null, 2));
    if (process.argv.includes("--timeline")) console.log(JSON.stringify(buildTimeline(plan, plan.presentation.durationMs, plan.presentation.resetCueMs), null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
