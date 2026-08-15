#include "nudge/pending_event_store.h"

#include <charconv>
#include <limits>
#include <string_view>

namespace nudge {
namespace {

constexpr char kActiveSlotKey[] = "journalActive";

const char* payload_key(std::uint32_t slot) {
  return slot == 0 ? "journalPayload0" : "journalPayload1";
}

const char* checksum_key(std::uint32_t slot) {
  return slot == 0 ? "journalCheck0" : "journalCheck1";
}

std::uint32_t checksum(const std::string& value) {
  std::uint32_t result = 2166136261U;
  for (const unsigned char byte : value) {
    result ^= byte;
    result *= 16777619U;
  }
  return result;
}

std::string encode(const PendingEventSnapshot& snapshot) {
  std::string payload = "N1\n" + std::to_string(snapshot.sequence_high_water) +
                        "\n" + std::to_string(snapshot.event_json.size()) +
                        "\n";
  for (const auto& event : snapshot.event_json) {
    payload += std::to_string(event.size()) + "\n" + event;
  }
  return payload;
}

bool read_line(std::string_view payload, std::size_t& cursor,
               std::string_view& line) {
  const auto end = payload.find('\n', cursor);
  if (end == std::string_view::npos) return false;
  line = payload.substr(cursor, end - cursor);
  cursor = end + 1;
  return true;
}

bool parse_uint(std::string_view value, std::uint32_t& output) {
  const auto* begin = value.data();
  const auto* end = begin + value.size();
  const auto parsed = std::from_chars(begin, end, output);
  return parsed.ec == std::errc{} && parsed.ptr == end;
}

bool decode(const std::string& source, PendingEventSnapshot& snapshot) {
  const std::string_view payload(source);
  std::size_t cursor = 0;
  std::string_view line;
  if (!read_line(payload, cursor, line) || line != "N1") return false;
  if (!read_line(payload, cursor, line) ||
      !parse_uint(line, snapshot.sequence_high_water)) {
    return false;
  }
  std::uint32_t count = 0;
  if (!read_line(payload, cursor, line) || !parse_uint(line, count) ||
      count > 8) {
    return false;
  }
  snapshot.event_json.clear();
  for (std::uint32_t index = 0; index < count; ++index) {
    std::uint32_t length = 0;
    if (!read_line(payload, cursor, line) || !parse_uint(line, length) ||
        length > payload.size() - cursor) {
      return false;
    }
    snapshot.event_json.emplace_back(payload.substr(cursor, length));
    cursor += length;
  }
  return cursor == payload.size();
}

}  // namespace

PendingEventSnapshot PendingEventStore::load() {
  PendingEventSnapshot snapshot;
  const auto requested_slot = storage_.get_uint(kActiveSlotKey, 2);
  if (requested_slot <= 1 && load_slot(requested_slot, snapshot)) {
    active_slot_ = requested_slot;
    has_active_slot_ = true;
    return snapshot;
  }
  const auto fallback_slot = requested_slot == 0 ? 1U : 0U;
  if (load_slot(fallback_slot, snapshot)) {
    active_slot_ = fallback_slot;
    has_active_slot_ = true;
  }
  return snapshot;
}

bool PendingEventStore::commit(const PendingEventSnapshot& snapshot) {
  if (snapshot.event_json.size() > 8) return false;
  const std::uint32_t target = has_active_slot_ ? 1U - active_slot_ : 0U;
  const auto payload = encode(snapshot);
  if (!storage_.put_string(payload_key(target), payload) ||
      !storage_.put_uint(checksum_key(target), checksum(payload)) ||
      !storage_.put_uint(kActiveSlotKey, target)) {
    return false;
  }
  active_slot_ = target;
  has_active_slot_ = true;
  return true;
}

bool PendingEventStore::load_slot(std::uint32_t slot,
                                  PendingEventSnapshot& snapshot) const {
  const auto payload = storage_.get_string(payload_key(slot));
  if (payload.empty() ||
      storage_.get_uint(checksum_key(slot), 0) != checksum(payload)) {
    return false;
  }
  PendingEventSnapshot candidate;
  if (!decode(payload, candidate)) return false;
  snapshot = std::move(candidate);
  return true;
}

}  // namespace nudge
