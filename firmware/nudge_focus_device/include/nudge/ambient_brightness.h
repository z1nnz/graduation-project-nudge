#pragma once

#include <cstdint>

namespace nudge {

struct BrightnessLevels {
  std::uint8_t display_percent;
  std::uint8_t led_level;
  bool using_sensor;
};

// Converts noisy ambient-light samples into bounded, gradual output levels.
// A missing/invalid sensor fails to a comfortable fixed indoor level.
class AmbientBrightnessController {
 public:
  BrightnessLevels update(float lux, bool sample_valid);

 private:
  bool initialized_ = false;
  float filtered_lux_ = 80.0F;
  std::uint8_t display_percent_ = 55;
  std::uint8_t led_level_ = 32;
};

}  // namespace nudge
