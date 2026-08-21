#include "nudge/ambient_brightness.h"

#include <algorithm>
#include <cmath>

namespace nudge {
namespace {

std::uint8_t approach(std::uint8_t current, std::uint8_t target,
                      std::uint8_t maximum_step) {
  // Ignore tiny target movement after filtering so fluorescent-light noise
  // cannot make the display or diffuser visibly breathe.
  if (std::abs(static_cast<int>(current) - static_cast<int>(target)) <= 2) {
    return current;
  }
  if (current < target) {
    return static_cast<std::uint8_t>(
        std::min<int>(target, current + maximum_step));
  }
  return static_cast<std::uint8_t>(
      std::max<int>(target, current - maximum_step));
}

float normalized_log_lux(float lux) {
  const auto bounded = std::clamp(lux, 0.0F, 2000.0F);
  return std::log10(bounded + 1.0F) / std::log10(2001.0F);
}

}  // namespace

BrightnessLevels AmbientBrightnessController::update(float lux,
                                                       bool sample_valid) {
  if (!sample_valid || !std::isfinite(lux) || lux < 0.0F) {
    display_percent_ = approach(display_percent_, 55, 8);
    led_level_ = approach(led_level_, 32, 6);
    return BrightnessLevels{display_percent_, led_level_, false};
  }

  if (!initialized_) {
    filtered_lux_ = std::clamp(lux, 0.0F, 2000.0F);
    initialized_ = true;
  } else {
    // A slow EWMA prevents a hand passing over the sensor from flashing the UI.
    filtered_lux_ = (filtered_lux_ * 0.82F) +
                    (std::clamp(lux, 0.0F, 2000.0F) * 0.18F);
  }

  const auto normalized = normalized_log_lux(filtered_lux_);
  const auto display_target = static_cast<std::uint8_t>(
      std::lround(18.0F + normalized * 82.0F));
  const auto led_target = static_cast<std::uint8_t>(
      std::lround(8.0F + normalized * 64.0F));
  display_percent_ = approach(display_percent_, display_target, 8);
  led_level_ = approach(led_level_, led_target, 6);
  return BrightnessLevels{display_percent_, led_level_, true};
}

}  // namespace nudge
