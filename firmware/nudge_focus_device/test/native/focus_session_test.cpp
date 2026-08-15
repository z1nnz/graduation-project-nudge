#include <cassert>
#include <cmath>
#include <iostream>
#include <string>

#include "nudge/focus_session.h"
#include "nudge/protocol_json.h"

namespace {

void configure(nudge::FocusSession& session, std::uint32_t duration = 1500) {
  const auto result = session.configure(
      nudge::FocusConfiguration{"focus-42", "cloud-focus-42", duration});
  assert(result.accepted());
  assert(!result.event.has_value());
}

void pause_and_resume_excludes_paused_time() {
  nudge::FocusSession session("desk-1", 7);
  configure(session);

  const auto started = session.start(1000, 1786759200000ULL);
  assert(started.accepted());
  assert(started.event->sequence == 8);
  assert(started.event->event_id == "desk-1:focus-42:started:8");

  const auto paused = session.pause(601000, 1786759800000ULL);
  assert(paused.accepted());
  assert(std::abs(paused.event->metric_minutes - 10.0) < 0.0001);
  assert(session.snapshot(901000).elapsed_seconds == 600);

  const auto resumed = session.resume(901000, 1786760100000ULL);
  assert(resumed.accepted());
  const auto completed = session.complete(1201000, 1786760400000ULL);
  assert(completed.accepted());
  assert(std::abs(completed.event->metric_minutes - 15.0) < 0.0001);
  assert(session.snapshot(1201000).phase == nudge::FocusPhase::completed);
}

void automatic_completion_emits_once() {
  nudge::FocusSession session("desk-auto");
  configure(session, 60);
  assert(session.start(0, 1000).accepted());
  assert(!session.tick(59999, 60999).has_value());

  const auto completed = session.tick(60000, 61000);
  assert(completed.has_value());
  assert(completed->event_type == nudge::ActivityEventType::completed);
  assert(std::abs(completed->metric_minutes - 1.0) < 0.0001);
  assert(!session.tick(120000, 121000).has_value());
}

void invalid_transitions_do_not_consume_sequence_numbers() {
  nudge::FocusSession session("desk-invalid", 10);
  assert(!session.start(0, 1000).accepted());
  assert(session.sequence() == 10);
  assert(!session
              .configure(nudge::FocusConfiguration{"bad id", "", 1500})
              .accepted());
  configure(session);
  assert(session.start(0, 1000).accepted());
  assert(!session.start(1, 1001).accepted());
  assert(session.sequence() == 11);
}

void identifiers_fit_the_cloud_ledger_contract() {
  nudge::FocusSession long_device(std::string(97, 'd'));
  assert(!long_device
              .configure(nudge::FocusConfiguration{"focus-42", "", 1500})
              .accepted());

  nudge::FocusSession valid_device("desk-bounds");
  assert(!valid_device
              .configure(
                  nudge::FocusConfiguration{std::string(97, 's'), "", 1500})
              .accepted());
  assert(valid_device
             .configure(nudge::FocusConfiguration{std::string(96, 's'),
                                                   std::string(96, 'c'), 1500})
             .accepted());
  const auto event = valid_device.start(0, 1000).event.value();
  assert(event.event_id.size() <= 256);
}

void protocol_json_matches_the_app_contract() {
  nudge::FocusSession session("desk-json");
  configure(session, 1500);
  session.start(0, 1786759200000ULL);
  const auto completed = session.complete(1500000, 1786760700000ULL);
  const auto json = nudge::encode_activity_event(*completed.event);

  assert(json.find("\"protocolVersion\":1") != std::string::npos);
  assert(json.find("\"messageType\":\"activity_event\"") !=
         std::string::npos);
  assert(json.find("\"eventId\":\"desk-json:focus-42:completed:2\"") !=
         std::string::npos);
  assert(json.find("\"metricValue\":25") != std::string::npos);
  assert(json.find("\"occurredAtEpochMs\":1786760700000") !=
         std::string::npos);
}

}  // namespace

int main() {
  pause_and_resume_excludes_paused_time();
  automatic_completion_emits_once();
  invalid_transitions_do_not_consume_sequence_numbers();
  identifiers_fit_the_cloud_ledger_contract();
  protocol_json_matches_the_app_contract();
  std::cout << "nudge_focus_device native tests passed\n";
  return 0;
}
