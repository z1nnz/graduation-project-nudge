#include "nudge/focus_session.h"

#include <algorithm>
#include <cctype>
#include <utility>

namespace nudge {
namespace {

bool valid_identifier(const std::string& value) {
  if (value.empty() || value.size() > 96 ||
      !std::isalnum(static_cast<unsigned char>(value.front()))) {
    return false;
  }
  return std::all_of(value.begin() + 1, value.end(), [](char character) {
    const auto value = static_cast<unsigned char>(character);
    return std::isalnum(value) || character == '.' || character == '_' ||
           character == '-';
  });
}

Transition rejected(TransitionStatus status) { return Transition{status, {}}; }

}  // namespace

FocusSession::FocusSession(std::string device_id,
                           std::uint32_t persisted_sequence)
    : device_id_(std::move(device_id)), sequence_(persisted_sequence) {}

Transition FocusSession::configure(const FocusConfiguration& configuration) {
  if ((phase_ == FocusPhase::running || phase_ == FocusPhase::paused)) {
    return rejected(TransitionStatus::invalid_transition);
  }
  if (!valid_identifier(device_id_) ||
      !valid_identifier(configuration.session_id) ||
      (!configuration.activity_correlation_id.empty() &&
       !valid_identifier(configuration.activity_correlation_id)) ||
      (!configuration.room_context_id.empty() &&
       !valid_identifier(configuration.room_context_id)) ||
      configuration.duration_seconds < 60 ||
      configuration.duration_seconds > 24U * 60U * 60U) {
    return rejected(TransitionStatus::invalid_configuration);
  }
  configuration_ = configuration;
  accumulated_seconds_ = 0;
  running_since_ms_ = 0;
  phase_ = FocusPhase::idle;
  return Transition{TransitionStatus::accepted, {}};
}

Transition FocusSession::start(std::uint32_t monotonic_ms,
                               std::uint64_t epoch_ms) {
  if (phase_ != FocusPhase::idle) {
    return rejected(TransitionStatus::invalid_transition);
  }
  accumulated_seconds_ = 0;
  running_since_ms_ = monotonic_ms;
  phase_ = FocusPhase::running;
  return Transition{TransitionStatus::accepted,
                    emit(ActivityEventType::started, 0, epoch_ms)};
}

Transition FocusSession::pause(std::uint32_t monotonic_ms,
                               std::uint64_t epoch_ms) {
  if (phase_ != FocusPhase::running) {
    return rejected(TransitionStatus::invalid_transition);
  }
  accumulated_seconds_ = elapsed_seconds(monotonic_ms);
  phase_ = FocusPhase::paused;
  return Transition{
      TransitionStatus::accepted,
      emit(ActivityEventType::paused, accumulated_seconds_, epoch_ms)};
}

Transition FocusSession::resume(std::uint32_t monotonic_ms,
                                std::uint64_t epoch_ms) {
  if (phase_ != FocusPhase::paused) {
    return rejected(TransitionStatus::invalid_transition);
  }
  running_since_ms_ = monotonic_ms;
  phase_ = FocusPhase::running;
  return Transition{
      TransitionStatus::accepted,
      emit(ActivityEventType::resumed, accumulated_seconds_, epoch_ms)};
}

Transition FocusSession::complete(std::uint32_t monotonic_ms,
                                  std::uint64_t epoch_ms) {
  if (phase_ != FocusPhase::running && phase_ != FocusPhase::paused) {
    return rejected(TransitionStatus::invalid_transition);
  }
  accumulated_seconds_ = std::min(
      elapsed_seconds(monotonic_ms), configuration_.duration_seconds);
  phase_ = FocusPhase::completed;
  return Transition{
      TransitionStatus::accepted,
      emit(ActivityEventType::completed, accumulated_seconds_, epoch_ms)};
}

std::optional<ActivityEvent> FocusSession::tick(std::uint32_t monotonic_ms,
                                                std::uint64_t epoch_ms) {
  if (phase_ != FocusPhase::running ||
      elapsed_seconds(monotonic_ms) < configuration_.duration_seconds) {
    return std::nullopt;
  }
  accumulated_seconds_ = configuration_.duration_seconds;
  phase_ = FocusPhase::completed;
  return emit(ActivityEventType::completed, accumulated_seconds_, epoch_ms);
}

FocusSnapshot FocusSession::snapshot(std::uint32_t monotonic_ms) const {
  const auto elapsed = std::min(elapsed_seconds(monotonic_ms),
                                configuration_.duration_seconds);
  return FocusSnapshot{
      phase_,
      configuration_.duration_seconds,
      elapsed,
      configuration_.duration_seconds > elapsed
          ? configuration_.duration_seconds - elapsed
          : 0,
  };
}

std::uint32_t FocusSession::elapsed_seconds(
    std::uint32_t monotonic_ms) const {
  if (phase_ != FocusPhase::running) {
    return accumulated_seconds_;
  }
  const auto delta_ms = monotonic_ms - running_since_ms_;
  return accumulated_seconds_ + delta_ms / 1000U;
}

ActivityEvent FocusSession::emit(ActivityEventType type,
                                 std::uint32_t elapsed_seconds,
                                 std::uint64_t epoch_ms) {
  ++sequence_;
  const std::string event_id = device_id_ + ":" + configuration_.session_id +
                               ":" + event_type_name(type) + ":" +
                               std::to_string(sequence_);
  return ActivityEvent{
      kDeviceProtocolVersion,
      event_id,
      event_id,
      device_id_,
      configuration_.session_id,
      configuration_.activity_correlation_id,
      sequence_,
      type,
      static_cast<double>(elapsed_seconds) / 60.0,
      epoch_ms,
      configuration_.room_context_id,
  };
}

const char* event_type_name(ActivityEventType type) {
  switch (type) {
    case ActivityEventType::started:
      return "started";
    case ActivityEventType::paused:
      return "paused";
    case ActivityEventType::resumed:
      return "resumed";
    case ActivityEventType::completed:
      return "completed";
  }
  return "unknown";
}

const char* phase_name(FocusPhase phase) {
  switch (phase) {
    case FocusPhase::unconfigured:
      return "unconfigured";
    case FocusPhase::idle:
      return "idle";
    case FocusPhase::running:
      return "running";
    case FocusPhase::paused:
      return "paused";
    case FocusPhase::completed:
      return "completed";
  }
  return "unknown";
}

}  // namespace nudge
