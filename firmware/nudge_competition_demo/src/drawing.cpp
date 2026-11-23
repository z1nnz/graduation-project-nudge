#include "demo/drawing.h"
#include "demo/station.h"
#include "demo/orbit_assets.h"
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
void asset(Canvas& c, const orbit_assets::Image& image, int x, int y) {
  for (std::size_t i = 0; i < image.count; ++i) {
    const auto& run = image.runs[i];
    c.rect(x + run.x, y + run.y, run.width, 1, run.ink);
  }
}
void label(Canvas& c, const orbit_assets::Image& image, int y) {
  asset(c, image, 120 - image.width / 2, y);
}
constexpr std::uint16_t halo = 0x1948;
constexpr std::uint16_t lavender = 0xb51f;
constexpr std::uint16_t gold = 0xf64e;
void star(Canvas& c, int x, int y, int r, std::uint16_t ink) {
  c.line(x-r,y,x+r,y,ink);
  c.line(x,y-r,x,y+r,ink);
  c.circle(x,y,1,ink);
}
void companion(Canvas& c, bool small = false) {
  const auto& image = small ? orbit_assets::focusHero : orbit_assets::hero;
  asset(c, image, 120-image.width/2, small ? 59 : 62);
}
}
void Painter::render(Canvas& c, const Frame& f, bool entered) {
  if (entered) {
    previousProgress_ = previousSecond_ = -1;
    c.clear(color::background);
  }
  if (device_ == Device::orbit) orbit(c, f, entered);
  else if (entered) station(c, f);
}
void Painter::orbit(Canvas& c, const Frame& f, bool entered) {
  char text[32];
  const auto& v = *f.values;
  if (entered) {
    // This is explicitly offline fixed data: no battery, clock, XP or sync claims.
    // Keep the status away from the circular crop; only the ring uses the edge.
    centered(c, 211, "OFFLINE / DEMO", 1, lavender);
    switch (f.scene) {
      case Scene::boot:
        centered(c, 32, "NUDGE", 2, color::text);
        c.circle(120,132,64,halo);
        companion(c);
        star(c,65,105,4,gold); star(c,176,140,3,lavender);
        centered(c, 192, "ORBIT", 1, lavender);
        break;
      case Scene::home:
        centered(c, 27, "NUDGE", 2, color::text);
        label(c, orbit_assets::today, 50);
        c.circle(100,135,60,halo);
        asset(c,orbit_assets::hero,48,73);
        star(c,53,96,4,gold); star(c,188,150,3,lavender);
        std::snprintf(text,sizeof(text),"%d",v.focusMinutes);
        c.text(146,102,text,3,color::text);
        c.text(152,130,"MIN",1,gold);
        asset(c,orbit_assets::focusHint,147,152);
        break;
      case Scene::ready:
        label(c,orbit_assets::ready,38);
        c.circle(120,132,62,halo);
        companion(c);
        centered(c,194,"READY TO FOCUS",1,lavender);
        break;
      case Scene::focus:
        ring(c,0,120,halo);
        label(c,orbit_assets::focus,35);
        c.circle(120,94,36,halo);
        companion(c,true);
        star(c,75,92,3,gold); star(c,166,80,2,lavender);
        centered(c,179,v.taskLabels[f.taskIndex<3?f.taskIndex:0],1,lavender);
        break;
      case Scene::encouragement:
        label(c,orbit_assets::support,38);
        c.circle(120,132,62,halo);
        companion(c);
        std::snprintf(text,sizeof(text),"%d FRIENDS / DEMO",v.activeMembers);
        centered(c,192,text,1,lavender);
        break;
      case Scene::complete:
        ring(c,0,120,halo);
        ring(c,0,120,gold);
        label(c,orbit_assets::complete,37);
        c.circle(120,133,64,halo);
        companion(c);
        star(c,60,111,5,gold); star(c,178,96,4,lavender);
        star(c,177,163,3,gold); star(c,75,66,2,lavender);
        centered(c,194,"ONE STEP FORWARD",1,gold);
        break;
      case Scene::growth:
        label(c,orbit_assets::growth,38);
        c.circle(120,132,62,halo);
        companion(c);
        star(c,65,112,4,gold); star(c,178,144,4,lavender);
        label(c,orbit_assets::companion,190);
        break;
      case Scene::summary:
        label(c,orbit_assets::summary,48);
        std::snprintf(text, sizeof(text), "%d FOCUS", v.todayFocusCount);
        centered(c, 91, text, 3, lavender);
        c.rect(80,130,80,1,halo);
        std::snprintf(text, sizeof(text), "%d MIN", v.todayFocusMinutes);
        centered(c, 151, text, 2,gold);
        break;
    }
  }
  if (f.scene == Scene::focus) {
    // The 20-second countdown is explicitly the compressed demo countdown.
    const int second = static_cast<int>(f.remainingSeconds);
    if (second != previousSecond_) {
      c.rect(58,133,124,33,color::background);
      std::snprintf(text, sizeof(text), "%02u:%02u", f.remainingSeconds / 60, f.remainingSeconds % 60);
      centered(c,134,text,4);
      previousSecond_ = second;
    }
    const int progress = (f.progress>1000?1000:f.progress)*120/1000;
    if (progress > previousProgress_) {
      ring(c,previousProgress_<0?0:previousProgress_,progress,lavender);
      previousProgress_ = progress;
    }
  }
  // App artwork is static in this demo: no invented pose or stage transition.
  // Only the countdown/ring update, avoiding full-frame transfers each tick.
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
