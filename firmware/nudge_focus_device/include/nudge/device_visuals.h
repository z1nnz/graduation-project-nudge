#pragma once

#include <cstddef>
#include <cstdint>

#include "nudge/focus_session.h"

namespace nudge {

enum class DeviceVisualState { offline, ready, active, paused, complete, rest };

struct RgbColor {
  std::uint8_t red;
  std::uint8_t green;
  std::uint8_t blue;
};

struct LightFrame {
  DeviceVisualState state;
  RgbColor active_color;
  RgbColor background_color;
  std::size_t lit_pixels;
};

DeviceVisualState visual_state(bool connected, FocusPhase phase,
                               std::uint32_t completed_for_ms);
LightFrame light_frame(DeviceVisualState state, std::uint32_t elapsed_seconds,
                       std::uint32_t duration_seconds,
                       std::size_t pixel_count);
const char* visual_state_name(DeviceVisualState state);

enum class DeviceCue { none, start, pause, resume, complete, room_changed, error };

}  // namespace nudge
