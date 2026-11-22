#include "demo/core.h"
#include "demo/drawing.h"
#include <cassert>
#include <cstring>
#include <iostream>
#include <vector>

using namespace demo;
struct FakeDisplay : DisplayPort {
  bool available = true;
  int rendered = 0, fatal = 0, entered = 0;
  bool begin() override { return available; }
  void render(const Frame&, bool change) override { ++rendered; if (change) ++entered; }
  void showFatal(const char*) override { ++fatal; }
};
struct FailedEffect : EffectPort {
  int calls = 0;
  bool begin() override { return false; }
  void onScene(Scene) override { ++calls; }
};
struct RecordCanvas : Canvas {
  int clears = 0, primitives = 0;
  std::vector<std::string> strings;
  void clear(std::uint16_t) override { ++clears; }
  void rect(int, int, int, int, std::uint16_t) override { ++primitives; }
  void line(int, int, int, int, std::uint16_t) override { ++primitives; }
  void circle(int, int, int, std::uint16_t) override { ++primitives; }
  void text(int, int, const char* value, int, std::uint16_t) override { strings.emplace_back(value); }
};
int main() {
  // 10 full replays: exactly eight IDs initially; seven after Boot, no ninth.
  Scenario s;
  s.restart(0);
  std::vector<Scene> seen{s.scene()};
  auto generation = s.generation();
  for (std::uint32_t now = 50; now <= 500000; now += 50) {
    s.tick(now);
    if (generation != s.generation()) { seen.push_back(s.scene()); generation = s.generation(); }
  }
  assert(seen.size() >= 72);
  for (unsigned i = 1; i < seen.size(); ++i) assert(static_cast<unsigned>(seen[i]) == 1 + (i - 1) % 7);
  // A late clock advances once, preserving the Complete dwell instead of skipping it.
  s.restart(0);
  for (int i = 0; i < 4; ++i) s.next(0);
  assert(s.scene() == Scene::encouragement);
  s.tick(1000000); assert(s.scene() == Scene::complete);
  s.tick(1000001); assert(s.scene() == Scene::complete);
  s.tick(1003999); assert(s.scene() == Scene::complete);
  s.tick(1004000); assert(s.scene() == Scene::growth);
  // Restart from every scene; repeated reset in Boot must retrigger the display.
  for (unsigned i = 0; i < 8; ++i) {
    s.restart(0);
    for (unsigned j = 0; j < i; ++j) s.next(0);
    assert(static_cast<unsigned>(s.scene()) == i);
    const auto old = s.generation();
    s.restart(100); assert(s.scene() == Scene::boot && s.generation() != old);
    s.tick(1599); assert(s.scene() == Scene::boot);
    s.tick(1600); assert(s.scene() == Scene::home);
  }
  // No input starts auto after five seconds. Serial/manual is a bounded command.
  s.restart(0); assert(!s.autoPlay(4999)); assert(s.autoPlay(5000));
  s.next(8000); assert(!s.autoPlay(12999)); assert(s.autoPlay(13000));
  assert(serialCommand('N') == Command::next && serialCommand('r') == Command::restart);
  assert(serialCommand('\n') == Command::none && serialCommand('x') == Command::none);
  // uint32 millis rollover: Boot and Focus finish correctly across wrap.
  s.restart(0xFFFFFF00U); s.tick(1243); assert(s.scene() == Scene::boot);
  s.tick(1244); assert(s.scene() == Scene::home);
  s.restart(0xFFFFFF00U); s.next(0xFFFFFF00U); s.next(0xFFFFFF00U); s.next(0xFFFFFF00U);
  auto f = s.frame(9744); assert(f.scene == Scene::focus && f.progress == 500 && f.remainingSeconds == 10);
  s.tick(19744); assert(s.scene() == Scene::encouragement);
  // P0-A is 5/20/5 seconds, continuously repeated with no optional scenes.
  Scenario a(Mode::p0a); a.restart(0); a.tick(1500); assert(a.scene() == Scene::home);
  a.tick(6499); assert(a.scene() == Scene::home);
  a.tick(6500); assert(a.scene() == Scene::focus);
  assert(a.frame(6500).remainingSeconds == 20 && a.frame(16500).remainingSeconds == 10);
  a.tick(26500); assert(a.scene() == Scene::complete);
  a.tick(31500); assert(a.scene() == Scene::home);
  for (int i = 0; i < 10; ++i) {
    const unsigned t = 31500 + i * 30000;
    a.tick(t + 5000); assert(a.scene() == Scene::focus);
    a.tick(t + 25000); assert(a.scene() == Scene::complete);
    a.tick(t + 30000); assert(a.scene() == Scene::home);
  }
  // Optional and display failures do not gate the state machine.
  FailedEffect effect; FakeDisplay d; Runtime runtime(s, d, &effect);
  runtime.begin(0); runtime.update(0); runtime.update(1500);
  assert(runtime.displayAvailable() && !runtime.effectAvailable() && effect.calls == 0 && s.scene() == Scene::home);
  d.available = false; runtime.begin(0); runtime.update(1500); runtime.update(5500);
  assert(!runtime.displayAvailable() && d.fatal == 1 && s.scene() == Scene::ready);
  // Shared scene/data; different layouts; DEMO present for all eight scenes.
  for (unsigned id = 0; id < 8; ++id) {
    Frame frame{static_cast<Scene>(id), 0, 20000, 0, 20, &data()};
    Painter orbit(Device::orbit), station(Device::station); RecordCanvas o, t;
    orbit.render(o, frame, true); station.render(t, frame, true);
    assert(o.strings != t.strings);
    bool oDemo = false, tDemo = false;
    for (const auto& text : o.strings) oDemo |= text.find("DEMO") != std::string::npos;
    for (const auto& text : t.strings) tDemo |= text.find("DEMO") != std::string::npos;
    assert(oDemo && tDemo && frame.values == &data());
  }
  // The report's three scenes are rendered by the real firmware painter.
  const Scene reportScenes[] = {Scene::home, Scene::focus, Scene::complete};
  const char* requiredLabels[] = {"READY TO FOCUS", "00:14", "OFFLINE PREVIEW"};
  for (unsigned i = 0; i < 3; ++i) {
    Painter report(Device::orbit, false);
    RecordCanvas output;
    Frame frame{reportScenes[i], 6000, 20000, 300, 14, &data()};
    report.render(output, frame, true);
    bool found = false;
    for (const auto& text : output.strings) found |= text == requiredLabels[i];
    assert(found);
  }
  // Focus animation never clears the background; duplicate frames draw nothing.
  Painter painter(Device::orbit); RecordCanvas c;
  Frame focus{Scene::focus, 0, 20000, 0, 20, &data()};
  painter.render(c, focus, true); const auto first = c.primitives;
  painter.render(c, focus, false); assert(c.primitives == first && c.clears == 1);
  focus.progress = 500; focus.remainingSeconds = 10;
  painter.render(c, focus, false); assert(c.clears == 1 && c.primitives > first);
  // A restart command takes precedence over a timer deadline.
  d.available = true; runtime.begin(0); runtime.update(0); const auto before = d.entered;
  runtime.update(1500, Command::restart); assert(s.scene() == Scene::boot && d.entered == before + 1);
  assert(std::strcmp(data().userName, "小樹") == 0 && data().demoXp == 10);
  std::cout << "PASS: replay, restart, late tick, rollover, fallback, shared data, layouts, incremental drawing\n";
}
