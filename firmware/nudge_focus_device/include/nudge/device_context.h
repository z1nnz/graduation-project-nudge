#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace nudge {

constexpr std::size_t kMaximumDeviceRooms = 3;

struct DeviceRoomContext {
  std::string id;
  std::string label;
  std::string goal_label;
};

struct DeviceCharacterContext {
  std::string name;
  std::uint16_t level = 1;
  std::uint8_t stage = 1;
};

struct DeviceContextSnapshot {
  std::vector<DeviceRoomContext> rooms;
  std::string selected_room_id;
  std::string personal_goal_label;
  DeviceCharacterContext character;
  bool sound_enabled = true;
  std::uint64_t revision = 0;
};

class DeviceContext {
 public:
  bool replace(const DeviceContextSnapshot& candidate);
  bool rotate(int steps);
  const DeviceContextSnapshot& snapshot() const { return snapshot_; }
  const DeviceRoomContext* selected_room() const;

 private:
  DeviceContextSnapshot snapshot_;
  std::size_t selected_index_ = 0;
};

}  // namespace nudge
