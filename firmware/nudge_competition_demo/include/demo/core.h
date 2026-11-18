#pragma once

#include <cstdint>

namespace demo {
enum class Scene : std::uint8_t { boot, home, ready, focus, encouragement, complete, growth, summary };
enum class Mode { p0a, p0b };
enum class Device { orbit, station };
enum class Command { none, next, restart, start };

struct DemoData {
  const char* userName = "小樹";
  const char* characterName = "小芽";
  int characterLevel = 7;
  int disciplineScore = 82;
  const char* primaryTask = "完成專題韌體";
  const char* roomName = "期末一起前進";
  const char* encouragement = "今天也慢慢來，我們都在";
  int focusMinutes = 25;
  int demoXp = 10;
  int activeMembers = 3;
  int totalMembers = 5;
  int todayFocusCount = 2;
  int todayFocusMinutes = 50;
  const char* taskLabels[3] = {"PROJECT", "READ 25 MIN", "WALK 3000"};
};
const DemoData& data();
const char* sceneName(Scene scene);
Command serialCommand(char value);

struct Frame {
  Scene scene;
  std::uint32_t elapsedMs;
  std::uint32_t durationMs;
  std::uint16_t progress;  // 0..1000; compressed preview, never real activity evidence.
  unsigned remainingSeconds;
  const DemoData* values;
  unsigned taskIndex = 0;
};

class Scenario {
 public:
  explicit Scenario(Mode mode = Mode::p0b) : mode_(mode) {}
  void restart(std::uint32_t now);
  void next(std::uint32_t now);
  void tick(std::uint32_t now);
  void rotateTask(int delta, std::uint32_t now);
  void startFocus(std::uint32_t now);
  Frame frame(std::uint32_t now) const;
  Scene scene() const { return scene_; }
  std::uint32_t generation() const { return generation_; }
  bool autoPlay(std::uint32_t now) const { return now - lastInput_ >= 5000U; }
 private:
  void enter(Scene scene, std::uint32_t now);
  std::uint32_t duration() const;
  Mode mode_;
  Scene scene_ = Scene::boot;
  std::uint32_t enteredAt_ = 0;
  std::uint32_t lastInput_ = 0;
  std::uint32_t generation_ = 0;
  unsigned taskIndex_ = 0;
};

class DisplayPort {
 public:
  virtual bool begin() = 0;
  virtual void render(const Frame& frame, bool entered) = 0;
  virtual void showFatal(const char* code) = 0;
  virtual ~DisplayPort() = default;
};
class EffectPort {
 public:
  virtual bool begin() = 0;
  virtual void onScene(Scene scene) = 0;
  virtual ~EffectPort() = default;
};

// Display/effect availability never controls the scenario. Callers log failures.
class Runtime {
 public:
  Runtime(Scenario& scenario, DisplayPort& display, EffectPort* effect = nullptr)
      : scenario_(scenario), display_(display), effect_(effect) {}
  void begin(std::uint32_t now);
  void update(std::uint32_t now, Command command = Command::none);
  bool displayAvailable() const { return displayOk_; }
  bool effectAvailable() const { return effectOk_; }
 private:
  Scenario& scenario_;
  DisplayPort& display_;
  EffectPort* effect_;
  bool displayOk_ = false;
  bool effectOk_ = false;
  std::uint32_t seenGeneration_ = ~0U;
};
}  // namespace demo
