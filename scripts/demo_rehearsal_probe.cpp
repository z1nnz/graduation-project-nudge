#include "demo/core.h"
#include <cassert>
#include <iostream>
#include <vector>
using namespace demo;
int main() {
  const std::vector<Scene> p0a{Scene::boot, Scene::home, Scene::focus, Scene::complete, Scene::home};
  const std::vector<Scene> p0b{Scene::boot, Scene::home, Scene::ready, Scene::focus,
    Scene::encouragement, Scene::complete, Scene::growth, Scene::summary, Scene::home};
  unsigned runs = 0;
  for (Mode mode : {Mode::p0a, Mode::p0b}) {
    const auto& expected = mode == Mode::p0a ? p0a : p0b;
    for (unsigned trial = 0; trial < 10; ++trial) {
      Scenario scenario(mode);
      const std::uint32_t start = trial * 200000U;
      scenario.restart(start);
      std::vector<Scene> seen{scenario.scene()};
      auto generation = scenario.generation();
      for (std::uint32_t elapsed = 50; elapsed <= 120000 && seen.size() < expected.size(); elapsed += 50) {
        scenario.tick(start + elapsed);
        if (generation != scenario.generation()) {
          generation = scenario.generation();
          seen.push_back(scenario.scene());
          if (seen.size() == 2) assert(elapsed < 10000); // Initial Home deadline.
        }
      }
      assert(seen == expected); // Includes Complete and Summary -> Home for P0-B.
      ++runs;
    }
  }
  unsigned restarts = 0;
  for (unsigned scene = 0; scene < 8; ++scene) {
    for (unsigned trial = 0; trial < 10; ++trial) {
      Scenario scenario;
      scenario.restart(0);
      for (unsigned i = 0; i < scene; ++i) scenario.next(0);
      assert(static_cast<unsigned>(scenario.scene()) == scene);
      const auto generation = scenario.generation();
      scenario.restart(100);
      assert(scenario.scene() == Scene::boot && scenario.generation() == generation + 1);
      ++restarts;
    }
  }
  Scenario scenario;
  scenario.restart(0);
  scenario.next(100); // Start Focus is intentionally allowed only in Home/Ready.
  scenario.startFocus(150);
  assert(scenario.scene() == Scene::focus);
  const auto before = scenario.generation();
  scenario.next(151); // Input does not wait for the Focus timer.
  assert(scenario.generation() == before + 1 && scenario.scene() == Scene::encouragement);
  std::cout << "{\"scope\":\"host-simulation-only\",\"physical_verified\":false,"
    "\"p0a_replays\":10,\"p0b_replays\":10,\"restart_per_scene\":10,"
    "\"restart_total\":" << restarts << ",\"total_replays\":" << runs << "}\n";
}
