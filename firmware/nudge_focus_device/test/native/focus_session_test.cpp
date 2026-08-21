#include <cassert>
#include <cmath>
#include <iostream>
#include <map>
#include <string>

#include "nudge/ambient_brightness.h"
#include "nudge/device_context.h"
#include "nudge/device_visuals.h"
#include "nudge/focus_session.h"
#include "nudge/durable_focus_transition.h"
#include "nudge/pending_event_store.h"
#include "nudge/protocol_json.h"

namespace {

class MemoryJournalStore final : public nudge::JournalKeyValueStore {
 public:
  std::string get_string(const char* key) const override {
    const auto value = strings.find(key);
    return value == strings.end() ? "" : value->second;
  }

  std::uint32_t get_uint(const char* key,
                         std::uint32_t fallback) const override {
    const auto value = integers.find(key);
    return value == integers.end() ? fallback : value->second;
  }

  bool put_string(const char* key, const std::string& value) override {
    if (writes++ == fail_on_write) return false;
    strings[key] = value;
    return true;
  }

  bool put_uint(const char* key, std::uint32_t value) override {
    if (writes++ == fail_on_write) return false;
    integers[key] = value;
    return true;
  }

  std::map<std::string, std::string> strings;
  std::map<std::string, std::uint32_t> integers;
  std::size_t writes = 0;
  std::size_t fail_on_write = static_cast<std::size_t>(-1);
};

void configure(nudge::FocusSession& session, std::uint32_t duration = 1500) {
  const auto result = session.configure(
      nudge::FocusConfiguration{"focus-42", "cloud-focus-42", duration, ""});
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
              .configure(nudge::FocusConfiguration{"bad id", "", 1500, ""})
              .accepted());
  configure(session);
  assert(session.start(0, 1000).accepted());
  assert(!session.start(1, 1001).accepted());
  assert(session.sequence() == 11);
}

void identifiers_fit_the_cloud_ledger_contract() {
  nudge::FocusSession long_device(std::string(97, 'd'));
  assert(!long_device
              .configure(
                  nudge::FocusConfiguration{"focus-42", "", 1500, ""})
              .accepted());

  nudge::FocusSession valid_device("desk-bounds");
  assert(!valid_device
              .configure(
                  nudge::FocusConfiguration{std::string(97, 's'), "", 1500,
                                            ""})
              .accepted());
  assert(valid_device
             .configure(nudge::FocusConfiguration{std::string(96, 's'),
                                                   std::string(96, 'c'), 1500,
                                                   ""})
             .accepted());
  const auto event = valid_device.start(0, 1000).event.value();
  assert(event.event_id.size() <= 256);
}

void protocol_json_matches_the_app_contract() {
  nudge::FocusSession session("desk-json");
  assert(session
             .configure(nudge::FocusConfiguration{
                 "focus-42", "cloud-focus-42", 1500, "room-study"})
             .accepted());
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
  assert(json.find("\"roomContextId\":\"room-study\"") !=
         std::string::npos);
}

void pending_event_journal_is_atomic_at_every_write_boundary() {
  const nudge::PendingEventSnapshot first{7, {"event-7"}};
  const nudge::PendingEventSnapshot second{8, {"event-7", "event-8"}};

  for (std::size_t boundary = 0; boundary < 3; ++boundary) {
    MemoryJournalStore storage;
    nudge::PendingEventStore initial_store(storage);
    assert(initial_store.commit(first));
    storage.fail_on_write = storage.writes + boundary;
    assert(!initial_store.commit(second));

    nudge::PendingEventStore reopened(storage);
    const auto recovered = reopened.load();
    assert(recovered.sequence_high_water == 7);
    assert(recovered.event_json == std::vector<std::string>{"event-7"});
  }

  MemoryJournalStore storage;
  nudge::PendingEventStore store(storage);
  assert(store.commit(first));
  assert(store.commit(second));
  nudge::PendingEventStore reopened(storage);
  const auto recovered = reopened.load();
  assert(recovered.sequence_high_water == 8);
  assert(recovered.event_json ==
         (std::vector<std::string>{"event-7", "event-8"}));
}

void transition_failure_keeps_session_retryable(
    const nudge::FocusSession& initial,
    const std::vector<std::string>& pending_json,
    const nudge::FocusTransitionOperation& operation,
    std::uint32_t snapshot_time) {
  for (std::size_t boundary = 0; boundary < 3; ++boundary) {
    MemoryJournalStore storage;
    nudge::PendingEventStore store(storage);
    assert(store.commit(
        nudge::PendingEventSnapshot{initial.sequence(), pending_json}));
    storage.fail_on_write = storage.writes + boundary;

    auto session = initial;
    const auto prior_phase = session.snapshot(snapshot_time).phase;
    const auto prior_sequence = session.sequence();
    const auto failed = nudge::apply_durable_focus_transition(
        session, store, pending_json, operation);
    assert(failed.status == nudge::TransitionStatus::persistence_failed);
    assert(session.sequence() == prior_sequence);
    assert(session.snapshot(snapshot_time).phase == prior_phase);

    storage.fail_on_write = static_cast<std::size_t>(-1);
    const auto retried = nudge::apply_durable_focus_transition(
        session, store, pending_json, operation);
    assert(retried.accepted());
    assert(session.sequence() == prior_sequence + 1);
  }
}

void focus_transitions_commit_before_mutating_live_state() {
  nudge::FocusSession idle("desk-transaction");
  configure(idle, 60);
  transition_failure_keeps_session_retryable(
      idle, {}, [](auto& session) { return session.start(0, 1000); }, 0);

  auto running = idle;
  const auto started = running.start(0, 1000).event.value();
  const std::vector<std::string> started_json{
      nudge::encode_activity_event(started)};
  transition_failure_keeps_session_retryable(
      running, started_json,
      [](auto& session) { return session.pause(10000, 11000); }, 10000);
  transition_failure_keeps_session_retryable(
      running, started_json,
      [](auto& session) { return session.complete(10000, 11000); }, 10000);

  auto paused = running;
  const auto paused_event = paused.pause(10000, 11000).event.value();
  const std::vector<std::string> paused_json{
      started_json.front(), nudge::encode_activity_event(paused_event)};
  transition_failure_keeps_session_retryable(
      paused, paused_json,
      [](auto& session) { return session.resume(12000, 13000); }, 12000);

  transition_failure_keeps_session_retryable(
      running, started_json,
      [](auto& session) {
        const auto event = session.tick(60000, 61000);
        return nudge::Transition{nudge::TransitionStatus::accepted, event};
      },
      60000);
}

void ambient_brightness_is_bounded_smooth_and_fail_safe() {
  nudge::AmbientBrightnessController controller;
  const auto dark = controller.update(0.0F, true);
  assert(dark.using_sensor);
  assert(dark.display_percent >= 18);
  assert(dark.led_level >= 8);

  const auto sudden_sun = controller.update(2000.0F, true);
  assert(sudden_sun.display_percent <= dark.display_percent + 8);
  assert(sudden_sun.led_level <= dark.led_level + 6);

  for (int sample = 0; sample < 50; ++sample) {
    controller.update(2000.0F, true);
  }
  const auto bright = controller.update(2000.0F, true);
  assert(bright.display_percent <= 100);
  assert(bright.led_level <= 72);
  assert(bright.display_percent > dark.display_percent);

  const auto fallback = controller.update(-1.0F, false);
  assert(!fallback.using_sensor);
  assert(fallback.display_percent >= 18 && fallback.display_percent <= 100);
  assert(fallback.led_level >= 8 && fallback.led_level <= 72);
}

void device_context_is_bounded_and_rotation_is_deterministic() {
  nudge::DeviceContext context;
  const nudge::DeviceContextSnapshot snapshot{
      {{"room-a", "Study", "25 min"},
       {"room-b", "Walk", "6000 steps"},
       {"room-c", "Sleep", "8 hours"}},
      "room-b",
      "Focus 25 min",
      {"Nudgie", 12, 3},
      true};
  assert(context.replace(snapshot));
  assert(context.selected_room()->id == "room-b");
  assert(context.rotate(1));
  assert(context.selected_room()->id == "room-c");
  assert(context.rotate(1));
  assert(context.selected_room()->id == "room-a");
  assert(context.rotate(-1));
  assert(context.selected_room()->id == "room-c");

  auto duplicate = snapshot;
  duplicate.rooms[2].id = "room-a";
  assert(!context.replace(duplicate));
  assert(context.selected_room()->id == "room-c");

  auto too_many = snapshot;
  too_many.rooms.push_back({"room-d", "Fourth", ""});
  assert(!context.replace(too_many));

  auto dotted = snapshot;
  dotted.rooms[0].id = "room.study-1";
  dotted.selected_room_id = "room.study-1";
  assert(context.replace(dotted));

  auto invalid_leading_punctuation = snapshot;
  invalid_leading_punctuation.rooms[0].id = "_room-a";
  invalid_leading_punctuation.selected_room_id = "_room-a";
  assert(!context.replace(invalid_leading_punctuation));

  auto invalid_stage = snapshot;
  invalid_stage.character.stage = 4;
  assert(!context.replace(invalid_stage));
}

void six_visual_states_have_safe_frames() {
  assert(nudge::visual_state(false, nudge::FocusPhase::running, 0) ==
         nudge::DeviceVisualState::offline);
  assert(nudge::visual_state(true, nudge::FocusPhase::idle, 0) ==
         nudge::DeviceVisualState::ready);
  assert(nudge::visual_state(true, nudge::FocusPhase::running, 0) ==
         nudge::DeviceVisualState::active);
  assert(nudge::visual_state(true, nudge::FocusPhase::paused, 0) ==
         nudge::DeviceVisualState::paused);
  assert(nudge::visual_state(true, nudge::FocusPhase::completed, 9999) ==
         nudge::DeviceVisualState::complete);
  assert(nudge::visual_state(true, nudge::FocusPhase::completed, 10000) ==
         nudge::DeviceVisualState::rest);

  const auto progress = nudge::light_frame(
      nudge::DeviceVisualState::active, 30, 60, 10);
  assert(progress.lit_pixels == 5);
  const auto offline = nudge::light_frame(
      nudge::DeviceVisualState::offline, 0, 0, 10);
  assert(offline.lit_pixels == 1);
}

void idle_room_selection_is_frozen_into_the_next_event() {
  nudge::FocusSession session("desk-room");
  assert(session
             .configure(nudge::FocusConfiguration{
                 "focus-room", "cloud-focus-room", 1500, "room-a"})
             .accepted());
  auto updated = session.configuration();
  updated.room_context_id = "room-b";
  assert(session.configure(updated).accepted());
  const auto started = session.start(0, 1000);
  assert(started.accepted());
  assert(started.event->room_context_id == "room-b");
  assert(nudge::encode_activity_event(*started.event)
             .find("\"roomContextId\":\"room-b\"") != std::string::npos);
}

}  // namespace

int main() {
  pause_and_resume_excludes_paused_time();
  automatic_completion_emits_once();
  invalid_transitions_do_not_consume_sequence_numbers();
  identifiers_fit_the_cloud_ledger_contract();
  protocol_json_matches_the_app_contract();
  pending_event_journal_is_atomic_at_every_write_boundary();
  focus_transitions_commit_before_mutating_live_state();
  ambient_brightness_is_bounded_smooth_and_fail_safe();
  device_context_is_bounded_and_rotation_is_deterministic();
  six_visual_states_have_safe_frames();
  idle_room_selection_is_frozen_into_the_next_event();
  std::cout << "nudge_focus_device native tests passed\n";
  return 0;
}
