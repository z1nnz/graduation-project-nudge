#include "nudge/device_visuals.h"

#include <algorithm>

namespace nudge {

DeviceVisualState visual_state(bool connected, FocusPhase phase,
                               std::uint32_t completed_for_ms) {
  if (!connected) return DeviceVisualState::offline;
  switch (phase) {
    case FocusPhase::unconfigured:
      return DeviceVisualState::ready;
    case FocusPhase::running:
      return DeviceVisualState::active;
    case FocusPhase::paused:
      return DeviceVisualState::paused;
    case FocusPhase::completed:
      return completed_for_ms < 10000 ? DeviceVisualState::complete
                                      : DeviceVisualState::rest;
    case FocusPhase::idle:
      return DeviceVisualState::ready;
  }
  return DeviceVisualState::offline;
}

LightFrame light_frame(DeviceVisualState state, std::uint32_t elapsed_seconds,
                       std::uint32_t duration_seconds,
                       std::size_t pixel_count) {
  RgbColor active{18, 8, 36};
  switch (state) {
    case DeviceVisualState::offline:
      active = {18, 8, 24};
      break;
    case DeviceVisualState::ready:
      active = {18, 10, 44};
      break;
    case DeviceVisualState::active:
      active = {0, 54, 120};
      break;
    case DeviceVisualState::paused:
      active = {110, 42, 0};
      break;
    case DeviceVisualState::complete:
      active = {0, 112, 36};
      break;
    case DeviceVisualState::rest:
      active = {0, 72, 68};
      break;
  }
  std::size_t lit = 0;
  if (state == DeviceVisualState::active && duration_seconds > 0) {
    lit = std::min<std::size_t>(
        pixel_count,
        (static_cast<std::uint64_t>(elapsed_seconds) * pixel_count) /
            duration_seconds);
  } else if (state != DeviceVisualState::offline) {
    lit = pixel_count;
  } else if (pixel_count > 0) {
    lit = 1;
  }
  return LightFrame{state, active, {2, 2, 3}, lit};
}

HugFrame hug_frame(std::uint32_t since_hug_ms, std::size_t pixel_count) {
  if (since_hug_ms >= kHugDurationMs) return HugFrame{false, {0, 0, 0}, 0};
  // Two slow breaths: a triangle wave over 1.5 s, from 100% down to 30%.
  constexpr std::uint32_t kBreathMs = 1500;
  const std::uint32_t phase = since_hug_ms % kBreathMs;
  const std::uint32_t half = kBreathMs / 2;
  const std::uint32_t distance = phase < half ? phase : kBreathMs - phase;
  const std::uint32_t level = 100 - (70 * distance) / half;  // 100..30
  const RgbColor pink{static_cast<std::uint8_t>(220 * level / 100),
                      static_cast<std::uint8_t>(40 * level / 100),
                      static_cast<std::uint8_t>(90 * level / 100)};
  return HugFrame{true, pink, pixel_count};
}

const char* visual_state_name(DeviceVisualState state) {
  switch (state) {
    case DeviceVisualState::offline:
      return "OFFLINE";
    case DeviceVisualState::ready:
      return "READY";
    case DeviceVisualState::active:
      return "FOCUS";
    case DeviceVisualState::paused:
      return "PAUSED";
    case DeviceVisualState::complete:
      return "COMPLETE";
    case DeviceVisualState::rest:
      return "REST";
  }
  return "OFFLINE";
}

}  // namespace nudge
