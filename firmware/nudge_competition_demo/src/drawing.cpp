#include "demo/drawing.h"
#include <cmath>
#include <cstdio>

namespace demo {
namespace {
void centered(Canvas& c, int y, const char* text, int size = 2, std::uint16_t ink = color::text) {
  int length = 0;
  while (text[length]) ++length;
  c.text(120 - length * 6 * size / 2, y, text, size, ink);
}
void sprout(Canvas& c, int x, int y, bool grown, bool happy, std::uint16_t ink) {
  c.circle(x, y, 16, ink);
  c.line(x, y - 16, x, y - 32, ink);
  c.line(x, y - 28, x - 14, y - 36, ink);
  c.line(x, y - 26, x + 14, y - 34, ink);
  if (grown) c.line(x, y - 20, x + 18, y - 24, ink);
  c.circle(x - 5, y - 2, 2, color::background);
  c.circle(x + 5, y - 2, 2, color::background);
  c.line(x - 4, y + 7, x + 4, y + (happy ? 4 : 7), color::background);
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
        centered(c, 66, "NUDGE", 2, color::ready);
        centered(c, 154, "ORBIT", 2);
        break;
      case Scene::home:
        centered(c, 54, "08:30", 2);
        sprout(c, 120, 120, false, false, color::ready);
        std::snprintf(text, sizeof(text), "SCORE %d", v.disciplineScore);
        centered(c, 154, text, 2);
        break;
      case Scene::ready:
        centered(c, 96, "FOCUS?", 3, color::ready);
        std::snprintf(text, sizeof(text), "%d MIN", v.focusMinutes);
        centered(c, 144, text, 2);
        ring(c, 0, 120, color::ready);
        break;
      case Scene::focus:
        ring(c, 0, 120, color::muted);
        centered(c, 70, "FOCUS", 2, color::primary);
        centered(c, 148, "PROJECT", 2);
        break;
      case Scene::encouragement:
        centered(c, 70, "KEEP GOING", 2, color::support);
        sprout(c, 120, 120, false, true, color::support);
        std::snprintf(text, sizeof(text), "%d ACTIVE", v.activeMembers);
        centered(c, 154, text, 2);
        break;
      case Scene::complete:
        ring(c, 0, 120, color::complete);
        centered(c, 66, "DONE", 3, color::complete);
        std::snprintf(text, sizeof(text), "%d MIN", v.focusMinutes);
        centered(c, 154, text, 2);
        break;
      case Scene::growth:
        centered(c, 54, "GROW", 2, color::complete);
        sprout(c, 120, 120, true, true, color::complete);
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
  if (f.scene == Scene::boot || f.scene == Scene::complete) {
    const int phase = animate_ ? (f.elapsedMs >= 1000 ? 2 : f.elapsedMs >= 500 ? 1 : 0) : 2;
    if (phase != previousPhase_) {
      c.rect(88, 94, 64, 46, color::background);
      if (f.scene == Scene::boot) sprout(c, 120, 122, phase > 0, false, phase == 0 ? color::muted : color::ready);
      else {
        sprout(c, 120, 126, phase > 0, true, color::complete);
        if (phase > 0) {
          c.line(104, 104, 115, 114, color::complete);
          c.line(115, 114, 136, 94, color::complete);
        }
      }
      previousPhase_ = phase;
    }
  }
}
void Painter::station(Canvas& c, const Frame& f) {
  // Host preview/layout contract only. No Station LCD/GPIO is selected here.
  c.text(16, 18, "NUDGE STATION", 2, color::ready);
  c.text(16, 58, sceneName(f.scene), 2, color::text);
  char text[32];
  std::snprintf(text, sizeof(text), "PROJECT / %d MIN", f.values->focusMinutes);
  c.text(16, 100, text, 2, color::text);
  std::snprintf(text, sizeof(text), "ROOM %d / %d", f.values->activeMembers, f.values->totalMembers);
  c.text(16, 142, text, 2, color::support);
  sprout(c, 120, 220, f.scene == Scene::growth, f.scene == Scene::complete, color::complete);
  c.text(16, 284, "DEMO / OFFLINE", 2, color::muted);
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
