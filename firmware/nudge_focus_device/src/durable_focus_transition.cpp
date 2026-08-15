#include "nudge/durable_focus_transition.h"

#include <utility>

#include "nudge/protocol_json.h"

namespace nudge {

Transition apply_durable_focus_transition(
    FocusSession& session, PendingEventStore& store,
    const std::vector<std::string>& pending_event_json,
    const FocusTransitionOperation& operation) {
  auto candidate = session;
  auto transition = operation(candidate);
  if (!transition.accepted() || !transition.event.has_value()) {
    return transition;
  }

  PendingEventSnapshot snapshot;
  snapshot.sequence_high_water = candidate.sequence();
  snapshot.event_json = pending_event_json;
  snapshot.event_json.push_back(encode_activity_event(*transition.event));
  if (!store.commit(snapshot)) {
    return Transition{TransitionStatus::persistence_failed, {}};
  }

  session = std::move(candidate);
  return transition;
}

}  // namespace nudge
