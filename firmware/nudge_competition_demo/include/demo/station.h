#pragma once
#include "demo/drawing.h"
namespace demo {
class StationPainter {
 public:
  explicit StationPainter(const char* buildId = "HOST") : buildId_(buildId) {}
  void render(Canvas& c, const Frame& f, bool entered);
 private:
  const char* buildId_;
  int second_ = -1, progress_ = -1;
};
void paintStationCalibration(Canvas& c,unsigned rotation=0);
}
