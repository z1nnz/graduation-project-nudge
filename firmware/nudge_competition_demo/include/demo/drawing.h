#pragma once
#include "demo/core.h"
#include "demo/generated_contract.h"

namespace demo {
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
class CharacterPainter {
 public:
  void render(Canvas& c,const Frame& f,bool entered,int x,int y,int size,bool animate);
 private:
  int pose_=-1,phase_=-1;
};
class Painter {
 public:
  // Retain the legacy constructor argument; Orbit art is deliberately static.
  explicit Painter(Device device, bool = true) : device_(device) {}
  void render(Canvas& canvas, const Frame& frame, bool entered);
 private:
  void orbit(Canvas& canvas, const Frame& frame, bool entered);
  void station(Canvas& canvas, const Frame& frame);
  Device device_;
  int previousProgress_ = -1;
  int previousSecond_ = -1;
};
void paintCalibration(Canvas& canvas);
}  // namespace demo
