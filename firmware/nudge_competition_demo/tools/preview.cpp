#include "demo/drawing.h"
#include "demo/station.h"
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

namespace {
std::string rgb(std::uint16_t color) {
  std::ostringstream s;
  s << '#' << std::hex << std::setfill('0') << std::setw(2) << ((color >> 11) * 255 / 31)
    << std::setw(2) << (((color >> 5) & 63) * 255 / 63) << std::setw(2) << ((color & 31) * 255 / 31);
  return s.str();
}
class SvgCanvas final : public demo::Canvas {
 public:
  std::ostringstream out;
  void clear(std::uint16_t c) override { rect(0, 0, 240, 320, c); }
  void rect(int x, int y, int w, int h, std::uint16_t c) override {
    out << "<rect x='" << x << "' y='" << y << "' width='" << w << "' height='" << h << "' fill='" << rgb(c) << "'/>";
  }
  void line(int x, int y, int x2, int y2, std::uint16_t c) override {
    out << "<path d='M" << x << ' ' << y << 'L' << x2 << ' ' << y2 << "' stroke='" << rgb(c) << "'/>";
  }
  void circle(int x, int y, int r, std::uint16_t c) override {
    out << "<circle cx='" << x << "' cy='" << y << "' r='" << r << "' fill='" << rgb(c) << "'/>";
  }
  void text(int x, int y, const char* value, int size, std::uint16_t c) override {
    std::string safe;
    for (const char* p = value; *p; ++p) {
      if (*p == '&') safe += "&amp;";
      else if (*p == '<') safe += "&lt;";
      else safe += *p;
    }
    out << "<text x='" << x << "' y='" << y + 7 * size << "' font-family='monospace' font-size='"
        << 8 * size << "' textLength='" << safe.size() * 6 * size << "' lengthAdjust='spacingAndGlyphs' fill='"
        << rgb(c) << "'>" << safe << "</text>";
  }
};
}
#ifndef DEMO_CANVAS_ONLY
int main(int argc, char** argv) {
  if (argc != 2 && argc != 3) return 2;
  const bool station=argc==3 && std::string(argv[2])=="station";
  const int height=station?900:730;
  std::ofstream out(std::string(argv[1]) + (station?"/station-scene-preview.svg":"/scene-preview.svg"));
  out << "<svg xmlns='http://www.w3.org/2000/svg' width='1120' height='"<<height<<"' viewBox='0 0 1120 "<<height<<"'>"
      << "<rect width='1120' height='"<<height<<"' fill='#172033'/><text x='20' y='30' fill='white' font-family='sans-serif' font-size='18'>"
      << "HOST LAYOUT PREVIEW / NOT A DEVICE CAPTURE / font approximate</text><defs><clipPath id='round'><circle cx='120' cy='120' r='120'/></clipPath></defs>";
  for (unsigned i = 0; i < 8; ++i) {
    SvgCanvas canvas;
    demo::Painter painter(demo::Device::orbit);
    demo::Frame frame{static_cast<demo::Scene>(i), 1000, 20000, 500, 10, &demo::data()};
    if(station){demo::StationPainter p;p.render(canvas,frame,true);}else painter.render(canvas, frame, true);
    const int x = 20 + (i % 4) * 275, y = 65 + (i / 4) * (station?415:330);
    out << "<g transform='translate(" << x << ',' << y << ")'><g"<<(station?"":" clip-path='url(#round)'")<<">" << canvas.out.str() << "</g>"
        << "<text x='120' y='"<<(station?355:270)<<"' text-anchor='middle' fill='white' font-family='sans-serif' font-size='16'>"<<(station?"S":"O") << i << " / "
        << demo::sceneName(frame.scene) << "</text></g>";
  }
  out << "</svg>\n";
  if (!out) return 1;
  std::cout << "wrote "<<(station?"station-scene-preview.svg":"scene-preview.svg")<<" (software layout only; no hardware evidence)\n";
  return 0;
}
#endif
