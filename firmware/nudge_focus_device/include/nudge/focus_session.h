#pragma once

#include <cstdint>
#include <optional>
#include <string>

namespace nudge {

constexpr std::uint32_t kDeviceProtocolVersion = 1;

enum class FocusPhase { unconfigured, idle, running, paused, completed };

enum class ActivityEventType { started, paused, resumed, completed };

enum class TransitionStatus {
  accepted,
  invalid_configuration,
  invalid_transition,
  persistence_failed,
};

struct FocusConfiguration {
  std::string session_id;
  std::string activity_correlation_id;
  std::uint32_t duration_seconds = 0;
  std::string room_context_id;
};

struct ActivityEvent {
  std::uint32_t protocol_version = kDeviceProtocolVersion;
  std::string event_id;
  std::string source_record_id;
  std::string device_id;
  std::string session_id;
  std::string activity_correlation_id;
  std::uint32_t sequence = 0;
  ActivityEventType event_type = ActivityEventType::started;
  double metric_minutes = 0;
  std::uint64_t occurred_at_epoch_ms = 0;
  std::string room_context_id;
};

struct Transition {
  TransitionStatus status = TransitionStatus::invalid_transition;
  std::optional<ActivityEvent> event;

  [[nodiscard]] bool accepted() const {
    return status == TransitionStatus::accepted;
  }
};

struct FocusSnapshot {
  FocusPhase phase = FocusPhase::unconfigured;
  std::uint32_t duration_seconds = 0;
  std::uint32_t elapsed_seconds = 0;
  std::uint32_t remaining_seconds = 0;
};

class FocusSession {
 public:
  FocusSession(std::string device_id, std::uint32_t persisted_sequence = 0);

  Transition configure(const FocusConfiguration& configuration);
  Transition start(std::uint32_t monotonic_ms, std::uint64_t epoch_ms);
  Transition pause(std::uint32_t monotonic_ms, std::uint64_t epoch_ms);
  Transition resume(std::uint32_t monotonic_ms, std::uint64_t epoch_ms);
  Transition complete(std::uint32_t monotonic_ms, std::uint64_t epoch_ms);
  std::optional<ActivityEvent> tick(std::uint32_t monotonic_ms,
                                    std::uint64_t epoch_ms);

  [[nodiscard]] FocusSnapshot snapshot(std::uint32_t monotonic_ms) const;
  [[nodiscard]] std::uint32_t sequence() const { return sequence_; }
  [[nodiscard]] const FocusConfiguration& configuration() const {
    return configuration_;
  }

 private:
  [[nodiscard]] std::uint32_t elapsed_seconds(
      std::uint32_t monotonic_ms) const;
  ActivityEvent emit(ActivityEventType type, std::uint32_t elapsed_seconds,
                     std::uint64_t epoch_ms);

  std::string device_id_;
  FocusConfiguration configuration_;
  FocusPhase phase_ = FocusPhase::unconfigured;
  std::uint32_t sequence_ = 0;
  std::uint32_t accumulated_seconds_ = 0;
  std::uint32_t running_since_ms_ = 0;
};

const char* event_type_name(ActivityEventType type);
const char* phase_name(FocusPhase phase);

}  // namespace nudge
