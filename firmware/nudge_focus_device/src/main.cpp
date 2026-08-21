#ifdef ARDUINO

#include <Adafruit_NeoPixel.h>
#include <Adafruit_seesaw.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <Preferences.h>
#include <SparkFun_Qwiic_Buzzer_Arduino_Library.h>
#include <SparkFun_VEML7700_Arduino_Library.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

#include <algorithm>
#include <deque>
#include <memory>
#include <string>

#include "driver.h"
#include <TFT_eSPI.h>
#include "nudge/ambient_brightness.h"
#include "nudge/device_context.h"
#include "nudge/device_visuals.h"
#include "nudge/durable_focus_transition.h"
#include "nudge/focus_session.h"
#include "nudge/pending_event_store.h"
#include "nudge/protocol_json.h"

namespace {

constexpr char kServiceUuid[] = "7df10000-4e55-4447-4500-4e5544474531";
constexpr char kCommandUuid[] = "7df10001-4e55-4447-4500-4e5544474531";
constexpr char kStateUuid[] = "7df10002-4e55-4447-4500-4e5544474531";
constexpr char kEventUuid[] = "7df10003-4e55-4447-4500-4e5544474531";
constexpr std::uint8_t kEncoderAddress = 0x36;
constexpr std::uint8_t kEncoderSwitchPin = 24;
constexpr std::size_t kMaximumPendingEvents = 8;
constexpr std::uint32_t kLongPressMs = 1200;
constexpr std::uint32_t kAmbientSampleMs = 1000;
constexpr std::uint8_t kBacklightPwmChannel = 7;

struct PendingMessage {
  std::string event_id;
  std::string json;
  std::uint32_t sequence;
};

struct CommandMessage {
  // Protocol v1 permits 512 payload bytes; reserve one more for the C string
  // terminator used by the FreeRTOS command queue.
  char payload[513];
};

class PreferencesJournalStore final : public nudge::JournalKeyValueStore {
 public:
  explicit PreferencesJournalStore(Preferences& preferences)
      : preferences_(preferences) {}

  std::string get_string(const char* key) const override {
    return preferences_.getString(key, "").c_str();
  }

  std::uint32_t get_uint(const char* key,
                         std::uint32_t fallback) const override {
    return preferences_.getUInt(key, fallback);
  }

  bool put_string(const char* key, const std::string& value) override {
    return preferences_.putString(key, value.c_str()) == value.size();
  }

  bool put_uint(const char* key, std::uint32_t value) override {
    return preferences_.putUInt(key, value) == sizeof(value);
  }

 private:
  Preferences& preferences_;
};

TFT_eSPI display;
Adafruit_seesaw encoder;
Adafruit_NeoPixel pixels(10, NUDGE_LED_PIN, NEO_GRB + NEO_KHZ800);
SparkFunVEML7700 ambient_sensor;
QwiicBuzzer buzzer;
Preferences preferences;
std::unique_ptr<PreferencesJournalStore> journal_storage;
std::unique_ptr<nudge::PendingEventStore> pending_event_store;
std::unique_ptr<nudge::FocusSession> focus_session;
std::deque<PendingMessage> pending_events;
BLECharacteristic* state_characteristic = nullptr;
BLECharacteristic* event_characteristic = nullptr;
volatile bool ble_connected = false;
bool encoder_available = false;
bool ambient_sensor_available = false;
bool buzzer_available = false;
bool backlight_pwm_available = false;
bool backlight_digital_on = true;
bool button_down = false;
bool long_press_handled = false;
std::uint32_t button_down_at = 0;
std::uint32_t last_render_at = 0;
std::uint32_t last_ambient_sample_at = 0;
std::uint32_t completed_at = 0;
std::int32_t encoder_position = 0;
std::uint64_t epoch_anchor_ms = 0;
std::uint32_t monotonic_anchor_ms = 0;
std::string device_id;
QueueHandle_t command_queue = nullptr;
nudge::AmbientBrightnessController brightness_controller;
nudge::BrightnessLevels brightness{55, 32, false};
nudge::DeviceContext device_context;

bool save_device_context(const nudge::DeviceContext& context) {
  const auto& snapshot = context.snapshot();
  JsonDocument document;
  document["contextVersion"] = 1;
  document["contextRevision"] = snapshot.revision;
  document["selectedRoomId"] = snapshot.selected_room_id;
  document["personalGoal"] = snapshot.personal_goal_label;
  document["soundEnabled"] = snapshot.sound_enabled;
  auto character = document["character"].to<JsonObject>();
  character["name"] = snapshot.character.name;
  character["level"] = snapshot.character.level;
  character["stage"] = snapshot.character.stage;
  auto rooms = document["rooms"].to<JsonArray>();
  for (const auto& room : snapshot.rooms) {
    auto output = rooms.add<JsonObject>();
    output["id"] = room.id;
    output["label"] = room.label;
    output["goal"] = room.goal_label;
  }
  std::string json;
  serializeJson(document, json);
  return preferences.putString("ctx_json", json.c_str()) == json.size();
}

bool parse_device_context(JsonVariantConst input,
                          nudge::DeviceContext& target) {
  if (!input.is<JsonObjectConst>() ||
      input["contextVersion"].as<int>() != 1 ||
      input["contextRevision"].as<std::uint64_t>() == 0 ||
      !input["rooms"].is<JsonArrayConst>() ||
      !input["character"].is<JsonObjectConst>()) {
    return false;
  }
  nudge::DeviceContextSnapshot candidate;
  candidate.revision = input["contextRevision"].as<std::uint64_t>();
  candidate.selected_room_id = (input["selectedRoomId"] | "");
  candidate.personal_goal_label = (input["personalGoal"] | "");
  candidate.sound_enabled = input["soundEnabled"] | true;
  candidate.character.name = (input["character"]["name"] | "");
  candidate.character.level = input["character"]["level"] | 0;
  candidate.character.stage = input["character"]["stage"] | 0;
  for (JsonObjectConst room : input["rooms"].as<JsonArrayConst>()) {
    candidate.rooms.push_back(nudge::DeviceRoomContext{
        room["id"] | "", room["label"] | "", room["goal"] | ""});
  }
  return candidate.revision > target.snapshot().revision &&
         target.replace(candidate);
}

void load_device_context() {
  const auto stored = preferences.getString("ctx_json", "");
  JsonDocument document;
  if (!stored.isEmpty() && deserializeJson(document, stored) ==
                               DeserializationError::Ok &&
      parse_device_context(document.as<JsonVariantConst>(), device_context)) {
    return;
  }
  device_context.replace(nudge::DeviceContextSnapshot{
      {}, "", "25 min", nudge::DeviceCharacterContext{"Nudge", 1, 1}, true});
}

void play_cue(nudge::DeviceCue cue) {
  if (!buzzer_available || !device_context.snapshot().sound_enabled ||
      cue == nudge::DeviceCue::none) {
    return;
  }
  std::uint16_t frequency = 1200;
  std::uint16_t duration = 70;
  switch (cue) {
    case nudge::DeviceCue::start:
    case nudge::DeviceCue::resume:
      frequency = 1700;
      break;
    case nudge::DeviceCue::pause:
      frequency = 900;
      break;
    case nudge::DeviceCue::complete:
      frequency = 2200;
      duration = 120;
      break;
    case nudge::DeviceCue::room_changed:
      frequency = 1400;
      duration = 45;
      break;
    case nudge::DeviceCue::error:
      frequency = 520;
      duration = 120;
      break;
    case nudge::DeviceCue::none:
      return;
  }
  buzzer.configureBuzzer(frequency, duration, SFE_QWIIC_BUZZER_VOLUME_LOW);
}

void configure_backlight() {
  pinMode(NUDGE_BACKLIGHT_PIN, OUTPUT);
#if NUDGE_BACKLIGHT_PWM
  backlight_pwm_available =
      ledcSetup(kBacklightPwmChannel, 5000, 8) > 0.0;
  if (backlight_pwm_available) {
    ledcAttachPin(NUDGE_BACKLIGHT_PIN, kBacklightPwmChannel);
  }
#endif
  if (!backlight_pwm_available) digitalWrite(NUDGE_BACKLIGHT_PIN, HIGH);
}

void apply_backlight() {
  if (backlight_pwm_available) {
    const auto duty = static_cast<std::uint8_t>(
        (static_cast<std::uint16_t>(brightness.display_percent) * 255U) /
        100U);
    ledcWrite(kBacklightPwmChannel, duty);
    return;
  }
  // If this Round Display revision cannot dim D6 reliably, retain useful
  // ambient behavior with a wide on/off hysteresis instead of flickering.
  if (brightness.display_percent <= 22) backlight_digital_on = false;
  if (brightness.display_percent >= 32) backlight_digital_on = true;
  digitalWrite(NUDGE_BACKLIGHT_PIN, backlight_digital_on ? HIGH : LOW);
}

std::uint64_t epoch_now() {
  if (epoch_anchor_ms == 0) return 0;
  return epoch_anchor_ms + (millis() - monotonic_anchor_ms);
}

bool save_pending_events(const std::deque<PendingMessage>& events,
                         std::uint32_t sequence_high_water) {
  nudge::PendingEventSnapshot snapshot;
  snapshot.sequence_high_water = sequence_high_water;
  for (const auto& event : events) snapshot.event_json.push_back(event.json);
  return pending_event_store->commit(snapshot);
}

std::uint32_t load_pending_events() {
  const auto snapshot = pending_event_store->load();
  std::uint32_t sequence_high_water = snapshot.sequence_high_water;
  for (const auto& json : snapshot.event_json) {
    JsonDocument document;
    if (!json.empty() && deserializeJson(document, json) == DeserializationError::Ok) {
      const char* event_id = document["eventId"] | "";
      const std::uint32_t sequence = document["sequence"] | 0U;
      if (*event_id != '\0' && sequence > 0) {
        pending_events.push_back(
            PendingMessage{event_id, json, sequence});
        sequence_high_water = std::max(sequence_high_water, sequence);
      }
    }
  }
  return sequence_high_water;
}

void expose_pending_head() {
  if (pending_events.empty()) {
    event_characteristic->setValue("");
  } else {
    event_characteristic->setValue(pending_events.front().json);
  }
}

void publish_state() {
  if (state_characteristic == nullptr || focus_session == nullptr) return;
  const auto snapshot = focus_session->snapshot(millis());
  JsonDocument document;
  document["v"] = nudge::kDeviceProtocolVersion;
  document["phase"] = nudge::phase_name(snapshot.phase);
  document["remaining"] = snapshot.remaining_seconds;
  document["pending"] = pending_events.size();
  document["selectedRoomId"] = device_context.snapshot().selected_room_id;
  document["contextRevision"] = device_context.snapshot().revision;
  std::string payload;
  serializeJson(document, payload);
  state_characteristic->setValue(payload);
  if (ble_connected) state_characteristic->notify();
  expose_pending_head();
}

std::vector<std::string> pending_event_json() {
  std::vector<std::string> result;
  result.reserve(pending_events.size());
  for (const auto& event : pending_events) result.push_back(event.json);
  return result;
}

void apply_transition(const nudge::FocusTransitionOperation& operation,
                      nudge::DeviceCue cue = nudge::DeviceCue::none) {
  if (pending_events.size() >= kMaximumPendingEvents) {
    publish_state();
    return;
  }
  const auto transition = nudge::apply_durable_focus_transition(
      *focus_session, *pending_event_store, pending_event_json(), operation);
  if (transition.accepted() && transition.event.has_value()) {
    const auto& event = *transition.event;
    pending_events.push_back(PendingMessage{
        event.event_id, nudge::encode_activity_event(event), event.sequence});
    if (event.event_type == nudge::ActivityEventType::completed) {
      completed_at = millis();
    }
    play_cue(cue);
  }
  publish_state();
}

void acknowledge_event(const char* event_id) {
  if (pending_events.empty() || pending_events.front().event_id != event_id) {
    return;
  }
  auto candidate = pending_events;
  candidate.pop_front();
  if (!save_pending_events(candidate, focus_session->sequence())) return;
  pending_events = std::move(candidate);
  publish_state();
}

void handle_command(const String& payload) {
  JsonDocument command;
  if (deserializeJson(command, payload) != DeserializationError::Ok ||
      command["protocolVersion"].as<std::uint32_t>() !=
          nudge::kDeviceProtocolVersion) {
    return;
  }
  const char* type = command["type"] | "";
  if (strcmp(type, "configure") == 0) {
    const char* session_id = command["sessionId"] | "";
    const char* correlation_id = command["activityCorrelationId"] | "";
    const std::uint32_t duration = command["durationSeconds"] | 0;
    const std::uint64_t epoch = command["clockEpochMs"] | 0ULL;
    if (epoch == 0) return;
    // The encoder is the final source of the user's room selection. The loop
    // samples and persists it before dispatching any queued command, closing
    // the race while the App waits for the Cloud correlation.
    const auto* selected_room = device_context.selected_room();
    const char* room_context_id =
        selected_room == nullptr ? "" : selected_room->id.c_str();
    auto candidate = *focus_session;
    const auto transition = candidate.configure(
        nudge::FocusConfiguration{session_id, correlation_id, duration,
                                  room_context_id});
    if (transition.accepted()) {
      *focus_session = std::move(candidate);
      epoch_anchor_ms = epoch;
      monotonic_anchor_ms = millis();
    }
    publish_state();
  } else if (strcmp(type, "context") == 0) {
    auto candidate = device_context;
    if (parse_device_context(command.as<JsonVariantConst>(), candidate) &&
        save_device_context(candidate)) {
      device_context = std::move(candidate);
      play_cue(nudge::DeviceCue::room_changed);
      publish_state();
    }
  } else if (strcmp(type, "sound") == 0 && command["enabled"].is<bool>()) {
    auto candidate = device_context;
    auto snapshot = candidate.snapshot();
    const auto revision = command["contextRevision"].as<std::uint64_t>();
    if (revision <= snapshot.revision) return;
    snapshot.sound_enabled = command["enabled"].as<bool>();
    snapshot.revision = revision;
    if (candidate.replace(snapshot) && save_device_context(candidate)) {
      device_context = std::move(candidate);
      publish_state();
    }
  } else if (strcmp(type, "start") == 0) {
    const auto now = millis();
    const auto epoch = epoch_now();
    apply_transition(
        [now, epoch](auto& session) { return session.start(now, epoch); },
        nudge::DeviceCue::start);
  } else if (strcmp(type, "pause") == 0) {
    const auto now = millis();
    const auto epoch = epoch_now();
    apply_transition(
        [now, epoch](auto& session) { return session.pause(now, epoch); },
        nudge::DeviceCue::pause);
  } else if (strcmp(type, "resume") == 0) {
    const auto now = millis();
    const auto epoch = epoch_now();
    apply_transition(
        [now, epoch](auto& session) { return session.resume(now, epoch); },
        nudge::DeviceCue::resume);
  } else if (strcmp(type, "complete") == 0) {
    const auto now = millis();
    const auto epoch = epoch_now();
    apply_transition(
        [now, epoch](auto& session) { return session.complete(now, epoch); },
        nudge::DeviceCue::complete);
  } else if (strcmp(type, "ack") == 0) {
    acknowledge_event(command["eventId"] | "");
  }
}

class CommandCallbacks final : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    CommandMessage command{};
    if (command_queue == nullptr || value.empty() ||
        value.size() > 512) {
      return;
    }
    strlcpy(command.payload, value.c_str(), sizeof(command.payload));
    xQueueSend(command_queue, &command, 0);
  }
};

class ServerCallbacks final : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    ble_connected = true;
  }

  void onDisconnect(BLEServer*) override {
    ble_connected = false;
    BLEDevice::startAdvertising();
  }
};

void configure_ble() {
  BLEDevice::init(("Nudge " + device_id).c_str());
  BLEDevice::setMTU(517);
  auto* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  auto* service = server->createService(kServiceUuid);
  auto* command = service->createCharacteristic(
      kCommandUuid, BLECharacteristic::PROPERTY_WRITE);
  command->setCallbacks(new CommandCallbacks());
  state_characteristic = service->createCharacteristic(
      kStateUuid,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  state_characteristic->addDescriptor(new BLE2902());
  event_characteristic = service->createCharacteristic(
      kEventUuid, BLECharacteristic::PROPERTY_READ);
  service->start();
  auto* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(kServiceUuid);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void render_leds(const nudge::FocusSnapshot& snapshot) {
  const auto completed_for = snapshot.phase == nudge::FocusPhase::completed
                                 ? millis() - completed_at
                                 : 0;
  const auto state = nudge::visual_state(
      ble_connected, snapshot.phase, completed_for);
  const auto frame = nudge::light_frame(
      state, snapshot.elapsed_seconds, snapshot.duration_seconds,
      pixels.numPixels());
  const auto color = pixels.Color(frame.active_color.red,
                                  frame.active_color.green,
                                  frame.active_color.blue);
  const auto background = pixels.Color(frame.background_color.red,
                                       frame.background_color.green,
                                       frame.background_color.blue);
  pixels.setBrightness(brightness.led_level);
  for (std::uint16_t index = 0; index < pixels.numPixels(); ++index) {
    pixels.setPixelColor(index, index < frame.lit_pixels ? color : background);
  }
  pixels.show();
}

void render_display(const nudge::FocusSnapshot& snapshot) {
  display.fillScreen(TFT_BLACK);
  display.setTextDatum(MC_DATUM);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  const auto completed_for = snapshot.phase == nudge::FocusPhase::completed
                                 ? millis() - completed_at
                                 : 0;
  const auto state = nudge::visual_state(
      ble_connected, snapshot.phase, completed_for);
  display.drawString(nudge::visual_state_name(state), 120, 54, 4);
  const String remaining = String(snapshot.remaining_seconds / 60) + ":" +
                           (snapshot.remaining_seconds % 60 < 10 ? "0" : "") +
                           String(snapshot.remaining_seconds % 60);
  display.drawString(remaining, 120, 100, 6);
  const auto* room = device_context.selected_room();
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.drawString(room == nullptr ? "PERSONAL" : room->label.c_str(), 120,
                     145, 2);
  const auto& context = device_context.snapshot();
  const String character = String(context.character.name.c_str()) + " Lv." +
                           String(context.character.level) + " S" +
                           String(context.character.stage);
  display.drawString(character, 120, 166, 2);
  const char* goal = room == nullptr ? context.personal_goal_label.c_str()
                                     : room->goal_label.c_str();
  display.drawString(goal, 120, 187, 2);
  display.setTextColor(pending_events.empty() ? TFT_DARKGREEN : TFT_ORANGE,
                       TFT_BLACK);
  display.drawString(pending_events.empty() ? "SYNCED" : "PENDING", 120, 211,
                     2);
}

void update_ambient_brightness() {
  if (millis() - last_ambient_sample_at < kAmbientSampleMs) return;
  last_ambient_sample_at = millis();
  float lux = -1.0F;
  const bool valid = ambient_sensor_available &&
                     ambient_sensor.getLux(lux) == ksfTkErrOk;
  brightness = brightness_controller.update(lux, valid);
  apply_backlight();
}

void handle_encoder_rotation() {
  if (!encoder_available) return;
  const auto next_position = encoder.getEncoderPosition();
  const auto delta = next_position - encoder_position;
  if (delta == 0) return;
  encoder_position = next_position;
  const auto phase = focus_session->snapshot(millis()).phase;
  if (phase == nudge::FocusPhase::running ||
      phase == nudge::FocusPhase::paused) {
    return;
  }
  auto candidate = device_context;
  if (!candidate.rotate(delta > 0 ? 1 : -1)) return;

  auto focus_candidate = *focus_session;
  if (phase == nudge::FocusPhase::idle) {
    auto configuration = focus_candidate.configuration();
    const auto* room = candidate.selected_room();
    configuration.room_context_id = room == nullptr ? "" : room->id;
    if (!focus_candidate.configure(configuration).accepted()) return;
  }
  if (save_device_context(candidate)) {
    device_context = std::move(candidate);
    if (phase == nudge::FocusPhase::idle) {
      *focus_session = std::move(focus_candidate);
    }
    play_cue(nudge::DeviceCue::room_changed);
    publish_state();
  }
}

void handle_encoder_button() {
  if (!encoder_available) return;
  const bool pressed = !encoder.digitalRead(kEncoderSwitchPin);
  if (pressed && !button_down) {
    button_down = true;
    long_press_handled = false;
    button_down_at = millis();
  } else if (pressed && button_down && !long_press_handled &&
             millis() - button_down_at >= kLongPressMs) {
    long_press_handled = true;
    if (pending_events.size() < kMaximumPendingEvents) {
      const auto now = millis();
      const auto epoch = epoch_now();
      apply_transition(
          [now, epoch](auto& session) { return session.complete(now, epoch); },
          nudge::DeviceCue::complete);
    }
  } else if (!pressed && button_down) {
    button_down = false;
    if (long_press_handled) return;
    // Preserve one queue slot for the eventual terminal completion event.
    if (pending_events.size() >= kMaximumPendingEvents - 1) return;
    const auto phase = focus_session->snapshot(millis()).phase;
    if (phase == nudge::FocusPhase::idle) {
      const auto now = millis();
      const auto epoch = epoch_now();
      apply_transition(
          [now, epoch](auto& session) { return session.start(now, epoch); },
          nudge::DeviceCue::start);
    } else if (phase == nudge::FocusPhase::running) {
      const auto now = millis();
      const auto epoch = epoch_now();
      apply_transition(
          [now, epoch](auto& session) { return session.pause(now, epoch); },
          nudge::DeviceCue::pause);
    } else if (phase == nudge::FocusPhase::paused) {
      const auto now = millis();
      const auto epoch = epoch_now();
      apply_transition(
          [now, epoch](auto& session) { return session.resume(now, epoch); },
          nudge::DeviceCue::resume);
    }
  }
}

std::string build_device_id() {
  const auto mac = ESP.getEfuseMac();
  char value[24];
  snprintf(value, sizeof(value), "nudge-%04llx%08llx",
           static_cast<unsigned long long>((mac >> 32U) & 0xFFFFU),
           static_cast<unsigned long long>(mac & 0xFFFFFFFFU));
  return value;
}

}  // namespace

void setup() {
  Serial.begin(115200);
  Wire.begin();
  preferences.begin("nudge-device", false);
  load_device_context();
  journal_storage = std::make_unique<PreferencesJournalStore>(preferences);
  pending_event_store =
      std::make_unique<nudge::PendingEventStore>(*journal_storage);
  device_id = build_device_id();
  const auto loaded_queue_sequence = load_pending_events();
  focus_session = std::make_unique<nudge::FocusSession>(
      device_id, loaded_queue_sequence);
  command_queue = xQueueCreate(8, sizeof(CommandMessage));

  display.begin();
  display.setRotation(0);
  configure_backlight();
  apply_backlight();
  pixels.begin();
  pixels.setBrightness(40);
  pixels.clear();
  pixels.show();

  encoder_available = encoder.begin(kEncoderAddress);
  if (encoder_available) {
    encoder.pinMode(kEncoderSwitchPin, INPUT_PULLUP);
    encoder_position = encoder.getEncoderPosition();
  }
  ambient_sensor_available = ambient_sensor.begin();
  buzzer_available = buzzer.begin();
  configure_ble();
  publish_state();
}

void loop() {
  // Sample and persist the physical selector before any BLE or button command
  // can configure/start a session. This makes the knob the authoritative room
  // choice even when rotation and a lifecycle action arrive in the same loop.
  handle_encoder_rotation();
  CommandMessage command{};
  while (command_queue != nullptr &&
         xQueueReceive(command_queue, &command, 0) == pdTRUE) {
    const String payload(command.payload);
    JsonDocument document;
    const bool valid_json =
        deserializeJson(document, payload) == DeserializationError::Ok;
    const char* type = valid_json ? document["type"] | "" : "";
    const bool emits_event = strcmp(type, "start") == 0 ||
                             strcmp(type, "pause") == 0 ||
                             strcmp(type, "resume") == 0 ||
                             strcmp(type, "complete") == 0;
    const bool terminal_event = strcmp(type, "complete") == 0;
    const auto capacity_limit = terminal_event ? kMaximumPendingEvents
                                               : kMaximumPendingEvents - 1;
    if (!emits_event || pending_events.size() < capacity_limit) {
      handle_command(payload);
    }
  }
  if (pending_events.size() < kMaximumPendingEvents) {
    const auto now = millis();
    if (focus_session->snapshot(now).phase == nudge::FocusPhase::running &&
        focus_session->snapshot(now).remaining_seconds == 0) {
      const auto epoch = epoch_now();
      apply_transition([now, epoch](auto& session) {
        const auto event = session.tick(now, epoch);
        return event.has_value()
                   ? nudge::Transition{nudge::TransitionStatus::accepted, event}
                   : nudge::Transition{
                         nudge::TransitionStatus::invalid_transition, {}};
      }, nudge::DeviceCue::complete);
    }
  }
  handle_encoder_button();
  update_ambient_brightness();
  if (millis() - last_render_at >= 500) {
    last_render_at = millis();
    const auto snapshot = focus_session->snapshot(millis());
    render_leds(snapshot);
    render_display(snapshot);
    publish_state();
  }
  delay(10);
}

#endif  // ARDUINO
