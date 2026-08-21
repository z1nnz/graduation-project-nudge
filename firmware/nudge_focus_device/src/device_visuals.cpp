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
