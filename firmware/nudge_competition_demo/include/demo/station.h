#pragma once
#include "demo/drawing.h"
namespace demo {
class StationPainter {
 public:
  explicit StationPainter(const char* buildId = "HOST",bool animate=true) : buildId_(buildId),animate_(animate) {}
  void render(Canvas& c, const Frame& f, bool entered);
 private:
  const char* buildId_;
  bool animate_;
  CharacterPainter character_;
  int second_ = -1, progress_ = -1;
};
void paintStationCalibration(Canvas& c,unsigned rotation=0);
}
