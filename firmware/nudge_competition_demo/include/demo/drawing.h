#pragma once
#include "demo/core.h"

namespace demo {
namespace color {
constexpr std::uint16_t background = 0x0883, primary = 0x8B5F, ready = 0xBD5F;
constexpr std::uint16_t complete = 0x5E97, support = 0x4E9D, text = 0xF7BD, muted = 0x6BF2;
}
class Canvas {
 public:
  virtual void clear(std::uint16_t color) = 0;
  virtual void rect(int x, int y, int w, int h, std::uint16_t color) = 0;
  virtual void line(int x1, int y1, int x2, int y2, std::uint16_t color) = 0;
  virtual void circle(int x, int y, int radius, std::uint16_t color) = 0;
  // size is the classic 6x8 ASCII bitmap font scale; x is left, y is top.
  virtual void text(int x, int y, const char* value, int size, std::uint16_t color) = 0;
  virtual ~Canvas() = default;
};
class Painter {
 public:
  explicit Painter(Device device, bool animate = true) : device_(device), animate_(animate) {}
  void render(Canvas& canvas, const Frame& frame, bool entered);
 private:
  void orbit(Canvas& canvas, const Frame& frame, bool entered);
  void station(Canvas& canvas, const Frame& frame);
  Device device_;
  bool animate_;
  int previousProgress_ = -1;
  int previousSecond_ = -1;
  int previousPhase_ = -1;
};
void paintCalibration(Canvas& canvas);
}  // namespace demo
