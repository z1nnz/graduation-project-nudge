#pragma once

#include <functional>
#include <string>
#include <vector>

#include "nudge/focus_session.h"
#include "nudge/pending_event_store.h"

namespace nudge {

using FocusTransitionOperation =
    std::function<Transition(FocusSession& candidate)>;

Transition apply_durable_focus_transition(
    FocusSession& session, PendingEventStore& store,
    const std::vector<std::string>& pending_event_json,
    const FocusTransitionOperation& operation);

}  // namespace nudge
