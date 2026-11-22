// Include the host Canvas adapter so report figures use the firmware painter.
#define DEMO_CANVAS_ONLY
#include "preview.cpp"

int main(int argc, char** argv) {
  if (argc != 2) return 2;
  std::ofstream out(argv[1]);
  if (!out) return 1;
  out << "<svg xmlns='http://www.w3.org/2000/svg' width='1500' height='610' viewBox='0 0 1500 610'>"
      << "<rect width='1500' height='610' fill='white'/>"
      << "<text x='45' y='55' font-family='sans-serif' font-size='30' fill='#172033'>Nudge Orbit / Firmware screen preview</text>"
      << "<defs><clipPath id='round'><circle cx='120' cy='120' r='120'/></clipPath></defs>";
  const demo::Scene scenes[] = {demo::Scene::home, demo::Scene::focus, demo::Scene::complete};
  const char* labels[] = {"Companion / ready", "Focus / countdown", "Completion / feedback"};
  for (unsigned i = 0; i < 3; ++i) {
    SvgCanvas canvas;
    demo::Painter painter(demo::Device::orbit, false);
    demo::Frame frame{scenes[i], 6000, 20000, 300, 14, &demo::data()};
    painter.render(canvas, frame, true);
    out << "<g transform='translate(" << 55 + i * 490 << ",100) scale(1.65)'>"
        << "<g clip-path='url(#round)'>" << canvas.out.str() << "</g></g>"
        << "<text x='" << 253 + i * 490 << "' y='535' text-anchor='middle' font-family='sans-serif' font-size='23' fill='#172033'>"
        << labels[i] << "</text>";
  }
  out << "<text x='45' y='585' font-family='sans-serif' font-size='18' fill='#556070'>"
      << "Software rendering of firmware drawing commands. Not a device photograph. Font approximate; demo values only.</text></svg>";
  return out ? 0 : 1;
}
