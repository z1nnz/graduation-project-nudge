#include "demo/core.h"
#include <algorithm>

namespace demo {
const DemoData& data() { static const DemoData values; return values; }
const char* sceneName(Scene scene) {
  static const char* const names[] = {"boot", "home", "ready", "focus", "encouragement", "complete", "growth", "summary"};
  return names[static_cast<unsigned>(scene)];
}
Command serialCommand(char value) {
  if (value == 'N' || value == 'n') return Command::next;
  if (value == 'R' || value == 'r') return Command::restart;
  return Command::none;
}
void Scenario::enter(Scene scene, std::uint32_t now) {
  scene_ = scene;
  enteredAt_ = now;
  ++generation_;
}
void Scenario::restart(std::uint32_t now) {
  lastInput_ = now;
  enter(Scene::boot, now);
}
void Scenario::next(std::uint32_t now) {
  lastInput_ = now;
  if (scene_ == Scene::boot) enter(Scene::home, now);
  else if (mode_ == Mode::p0a) {
    enter(scene_ == Scene::home ? Scene::focus : scene_ == Scene::focus ? Scene::complete : Scene::home, now);
  } else {
    enter(scene_ == Scene::summary ? Scene::home : static_cast<Scene>(static_cast<unsigned>(scene_) + 1), now);
  }
}
std::uint32_t Scenario::duration() const {
  if (mode_ == Mode::p0a) {
    if (scene_ == Scene::boot) return 1500;
    return scene_ == Scene::focus ? 20000 : 5000;
  }
  static constexpr std::uint32_t durations[] = {1500, 4000, 3000, 20000, 5000, 4000, 5000, 8000};
  return durations[static_cast<unsigned>(scene_)];
}
void Scenario::tick(std::uint32_t now) {
  if ((scene_ == Scene::boot || autoPlay(now)) && now - enteredAt_ >= duration()) {
    // Advance ONCE and re-anchor at now: a delayed loop must visibly render
    // Complete for its full duration rather than skipping through missed scenes.
    const auto inputAt = lastInput_;
    next(now);
    lastInput_ = inputAt;
  }
}
Frame Scenario::frame(std::uint32_t now) const {
  const auto total = duration();
  const auto elapsed = std::min(now - enteredAt_, total);
  return {scene_, elapsed, total, static_cast<std::uint16_t>(elapsed * 1000U / total),
          static_cast<unsigned>((total - elapsed + 999) / 1000), &data()};
}
void Runtime::begin(std::uint32_t now) {
  scenario_.restart(now);
  seenGeneration_ = ~0U;
  displayOk_ = display_.begin();
  if (!displayOk_) display_.showFatal("DISPLAY_UNAVAILABLE");
  effectOk_ = effect_ && effect_->begin();
}
void Runtime::update(std::uint32_t now, Command command) {
  if (command == Command::restart) scenario_.restart(now);
  else if (command == Command::next) scenario_.next(now);
  else scenario_.tick(now);
  const bool entered = seenGeneration_ != scenario_.generation();
  if (displayOk_) display_.render(scenario_.frame(now), entered);
  if (entered && effectOk_) effect_->onScene(scenario_.scene());
  seenGeneration_ = scenario_.generation();
}
}  // namespace demo
