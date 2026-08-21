#include "nudge/device_context.h"

#include <algorithm>
#include <set>

namespace nudge {
namespace {

bool bounded_text(const std::string& value, std::size_t maximum_bytes,
                  bool allow_empty = false) {
  return (allow_empty || !value.empty()) && value.size() <= maximum_bytes;
}

bool valid_identifier(const std::string& value) {
  if (!bounded_text(value, 96)) return false;
  const auto alphanumeric = [](unsigned char character) {
    return (character >= 'a' && character <= 'z') ||
           (character >= 'A' && character <= 'Z') ||
           (character >= '0' && character <= '9');
  };
  if (!alphanumeric(static_cast<unsigned char>(value.front()))) return false;
  return std::all_of(value.begin() + 1, value.end(), [&](unsigned char character) {
    return alphanumeric(character) || character == '_' || character == '-' ||
           character == '.';
  });
}

}  // namespace

bool DeviceContext::replace(const DeviceContextSnapshot& candidate) {
  if (candidate.rooms.size() > kMaximumDeviceRooms ||
      !bounded_text(candidate.personal_goal_label, 32, true) ||
      !bounded_text(candidate.character.name, 24) ||
      candidate.character.level == 0 || candidate.character.level > 999 ||
      candidate.character.stage == 0 || candidate.character.stage > 3) {
    return false;
  }

  std::set<std::string> room_ids;
  std::size_t selected_index = 0;
  bool selected_found = candidate.rooms.empty();
  for (std::size_t index = 0; index < candidate.rooms.size(); ++index) {
    const auto& room = candidate.rooms[index];
    if (!valid_identifier(room.id) || !bounded_text(room.label, 24) ||
        !bounded_text(room.goal_label, 32, true) ||
        !room_ids.insert(room.id).second) {
      return false;
    }
    if (room.id == candidate.selected_room_id) {
      selected_index = index;
      selected_found = true;
    }
  }
  if (!selected_found ||
      (!candidate.rooms.empty() && candidate.selected_room_id.empty())) {
    return false;
  }

  snapshot_ = candidate;
  selected_index_ = selected_index;
  if (!snapshot_.rooms.empty()) {
    snapshot_.selected_room_id = snapshot_.rooms[selected_index_].id;
  } else {
    snapshot_.selected_room_id.clear();
  }
  return true;
}

bool DeviceContext::rotate(int steps) {
  if (steps == 0 || snapshot_.rooms.size() < 2) return false;
  const auto count = static_cast<int>(snapshot_.rooms.size());
  auto next = (static_cast<int>(selected_index_) + steps) % count;
  if (next < 0) next += count;
  selected_index_ = static_cast<std::size_t>(next);
  snapshot_.selected_room_id = snapshot_.rooms[selected_index_].id;
  return true;
}

const DeviceRoomContext* DeviceContext::selected_room() const {
  if (snapshot_.rooms.empty()) return nullptr;
  return &snapshot_.rooms[selected_index_];
}

}  // namespace nudge
