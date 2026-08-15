#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace nudge {

class JournalKeyValueStore {
 public:
  virtual ~JournalKeyValueStore() = default;
  virtual std::string get_string(const char* key) const = 0;
  virtual std::uint32_t get_uint(const char* key,
                                 std::uint32_t fallback) const = 0;
  virtual bool put_string(const char* key, const std::string& value) = 0;
  virtual bool put_uint(const char* key, std::uint32_t value) = 0;
};

struct PendingEventSnapshot {
  std::uint32_t sequence_high_water = 0;
  std::vector<std::string> event_json;
};

class PendingEventStore {
 public:
  explicit PendingEventStore(JournalKeyValueStore& storage)
      : storage_(storage) {}

  PendingEventSnapshot load();
  bool commit(const PendingEventSnapshot& snapshot);

 private:
  bool load_slot(std::uint32_t slot, PendingEventSnapshot& snapshot) const;

  JournalKeyValueStore& storage_;
  std::uint32_t active_slot_ = 0;
  bool has_active_slot_ = false;
};

}  // namespace nudge
