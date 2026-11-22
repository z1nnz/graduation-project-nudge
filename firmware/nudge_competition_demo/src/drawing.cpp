#include "demo/drawing.h"
#include "demo/station.h"
#include <cmath>
#include <cstdio>

namespace demo {
namespace {
void centered(Canvas& c, int y, const char* text, int size = 2, std::uint16_t ink = color::text) {
  int length = 0;
  while (text[length]) ++length;
  c.text(120 - length * 6 * size / 2, y, text, size, ink);
}
void ring(Canvas& c, int first, int end, std::uint16_t ink) {
  for (int i = first; i < end; ++i) {
    const double a = (i * 3.0 - 90.0) * 3.141592653589793 / 180.0;
    c.line(120 + static_cast<int>(108 * std::cos(a)), 120 + static_cast<int>(108 * std::sin(a)),
           120 + static_cast<int>(114 * std::cos(a)), 120 + static_cast<int>(114 * std::sin(a)), ink);
  }
}
}
void Painter::render(Canvas& c, const Frame& f, bool entered) {
  if (entered) {
    previousProgress_ = previousSecond_ = previousPhase_ = -1;
    c.clear(color::background);
  }
  if (device_ == Device::orbit) orbit(c, f, entered);
  else if (entered) station(c, f);
}
void Painter::orbit(Canvas& c, const Frame& f, bool entered) {
  char text[32];
  const auto& v = *f.values;
  if (entered) {
    // Every fixed-data scene carries the same readable DEMO label inside
    // the central 70% safe zone. The progress ring alone uses the perimeter.
    centered(c, 184, "DEMO", 2, color::muted);
    switch (f.scene) {
      case Scene::boot:
        centered(c, 54, "NUDGE", 2, color::ready);
        centered(c, 154, "ORBIT", 2);
        break;
      case Scene::home:
        centered(c, 44, "TODAY'S GOAL", 2, color::ready);
        std::snprintf(text, sizeof(text), "%d MIN", v.focusMinutes);
        centered(c, 68, text, 3);
        centered(c, 164, "READY TO FOCUS", 1, color::ready);
        break;
      case Scene::ready:
        centered(c, 54, "FOCUS?", 2, color::ready);
        std::snprintf(text, sizeof(text), "%d MIN", v.focusMinutes);
        centered(c, 144, text, 2);
        ring(c, 0, 120, color::ready);
        break;
      case Scene::focus:
        ring(c, 0, 120, color::muted);
        centered(c, 54, "FOCUS", 2, color::primary);
        centered(c, 78, v.taskLabels[f.taskIndex<3?f.taskIndex:0], 1);
        break;
      case Scene::encouragement:
        centered(c, 70, "KEEP GOING", 2, color::support);
        std::snprintf(text, sizeof(text), "%d ACTIVE", v.activeMembers);
        centered(c, 154, text, 2);
        break;
      case Scene::complete:
        ring(c, 0, 120, color::complete);
        centered(c, 54, "DONE", 3, color::complete);
        centered(c, 164, "OFFLINE PREVIEW", 1, color::complete);
        break;
      case Scene::growth:
        centered(c, 54, "GROW", 2, color::complete);
        std::snprintf(text, sizeof(text), "XP +%d", v.demoXp);
        centered(c, 148, text, 2);
        std::snprintf(text, sizeof(text), "LEVEL %d", v.characterLevel);
        centered(c, 164, text, 2);
        break;
      case Scene::summary:
        centered(c, 64, "TODAY", 2);
        std::snprintf(text, sizeof(text), "%d FOCUS", v.todayFocusCount);
        centered(c, 104, text, 3, color::ready);
        std::snprintf(text, sizeof(text), "%d MIN", v.todayFocusMinutes);
        centered(c, 148, text, 2);
        break;
    }
  }
  if (f.scene == Scene::focus) {
    // The 20-second countdown is explicitly the compressed demo countdown.
    const int second = static_cast<int>(f.remainingSeconds);
    if (second != previousSecond_) {
      c.rect(62, 104, 116, 32, color::background);
      std::snprintf(text, sizeof(text), "%02u:%02u", f.remainingSeconds / 60, f.remainingSeconds % 60);
      centered(c, 108, text, 3);
      previousSecond_ = second;
    }
    const int progress = f.progress * 120 / 1000;
    if (progress > previousProgress_) {
      ring(c, previousProgress_ < 0 ? 0 : previousProgress_, progress, color::primary);
      previousProgress_ = progress;
    }
  }
  if(f.scene!=Scene::summary){
    const bool focus=f.scene==Scene::focus;
    const bool hero=f.scene==Scene::home || f.scene==Scene::complete;
    character_.render(c,f,entered,focus?104:88,focus?146:hero?96:80,focus?32:64,animate_);
  }
}

void Painter::station(Canvas& c, const Frame& f) {
  // Compatibility entry point for the original shared-layout contract.
  // The hardware adapter holds a persistent StationPainter for partial updates.
  StationPainter painter;
  painter.render(c,f,true);
}
void paintCalibration(Canvas& c) {
  c.clear(color::background);
  ring(c, 0, 120, color::primary);
  c.line(110, 120, 130, 120, color::text);
  c.line(120, 110, 120, 130, color::text);
  centered(c, 22, "N", 2); centered(c, 202, "S", 2);
  c.text(14, 112, "W", 2, color::text); c.text(214, 112, "E", 2, color::text);
  centered(c, 56, "NUDGE", 3);
  centered(c, 160, "ORBIT 123", 2);
  centered(c, 184, "ROTATION 0", 1, color::muted);
}
}  // namespace demo
