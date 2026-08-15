#ifdef ARDUINO

#include <Adafruit_NeoPixel.h>
#include <Adafruit_seesaw.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <Preferences.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

#include <algorithm>
#include <deque>
#include <memory>
#include <string>

#include "driver.h"
#include <TFT_eSPI.h>
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

struct PendingMessage {
  std::string event_id;
  std::string json;
  std::uint32_t sequence;
};

struct CommandMessage {
  char payload[512];
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
Preferences preferences;
std::unique_ptr<PreferencesJournalStore> journal_storage;
std::unique_ptr<nudge::PendingEventStore> pending_event_store;
std::unique_ptr<nudge::FocusSession> focus_session;
std::deque<PendingMessage> pending_events;
BLECharacteristic* state_characteristic = nullptr;
BLECharacteristic* event_characteristic = nullptr;
volatile bool ble_connected = false;
bool encoder_available = false;
bool button_down = false;
bool long_press_handled = false;
std::uint32_t button_down_at = 0;
std::uint32_t last_render_at = 0;
std::uint64_t epoch_anchor_ms = 0;
std::uint32_t monotonic_anchor_ms = 0;
std::string device_id;
QueueHandle_t command_queue = nullptr;

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
  std::string payload;
  serializeJson(document, payload);
  state_characteristic->setValue(payload);
  if (ble_connected) state_characteristic->notify();
  expose_pending_head();
}

void queue_event(const nudge::ActivityEvent& event) {
  if (pending_events.size() >= kMaximumPendingEvents) {
    // Callers reserve capacity before changing session state. Keep this guard
    // as a final fail-closed boundary.
    publish_state();
    return;
  }
  auto candidate = pending_events;
  candidate.push_back(
      PendingMessage{event.event_id, nudge::encode_activity_event(event),
                     event.sequence});
  if (!save_pending_events(candidate, focus_session->sequence())) return;
  pending_events = std::move(candidate);
  publish_state();
}

void apply_transition(const nudge::Transition& transition) {
  if (transition.accepted() && transition.event.has_value()) {
    queue_event(*transition.event);
  } else {
    publish_state();
  }
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
    const auto transition = focus_session->configure(
        nudge::FocusConfiguration{session_id, correlation_id, duration});
    if (transition.accepted()) {
      epoch_anchor_ms = epoch;
      monotonic_anchor_ms = millis();
    }
    apply_transition(transition);
  } else if (strcmp(type, "start") == 0) {
    apply_transition(focus_session->start(millis(), epoch_now()));
  } else if (strcmp(type, "pause") == 0) {
    apply_transition(focus_session->pause(millis(), epoch_now()));
  } else if (strcmp(type, "resume") == 0) {
    apply_transition(focus_session->resume(millis(), epoch_now()));
  } else if (strcmp(type, "complete") == 0) {
    apply_transition(focus_session->complete(millis(), epoch_now()));
  } else if (strcmp(type, "ack") == 0) {
    acknowledge_event(command["eventId"] | "");
  }
}

class CommandCallbacks final : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const std::string value = characteristic->getValue();
    CommandMessage command{};
    if (command_queue == nullptr || value.empty() ||
        value.size() >= sizeof(command.payload)) {
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
  BLEDevice::setMTU(247);
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
  std::uint32_t color = pixels.Color(12, 6, 24);
  if (snapshot.phase == nudge::FocusPhase::running) {
    color = pixels.Color(0, 24, 64);
  } else if (snapshot.phase == nudge::FocusPhase::paused) {
    color = pixels.Color(64, 28, 0);
  } else if (snapshot.phase == nudge::FocusPhase::completed) {
    color = pixels.Color(0, 64, 20);
  }
  const auto lit = snapshot.duration_seconds == 0
                       ? 0
                       : (snapshot.elapsed_seconds * pixels.numPixels()) /
                             snapshot.duration_seconds;
  for (std::uint16_t index = 0; index < pixels.numPixels(); ++index) {
    pixels.setPixelColor(index, index < lit ? color : pixels.Color(2, 2, 3));
  }
  pixels.show();
}

void render_display(const nudge::FocusSnapshot& snapshot) {
  display.fillScreen(TFT_BLACK);
  display.setTextDatum(MC_DATUM);
  display.setTextColor(TFT_WHITE, TFT_BLACK);
  display.drawString(nudge::phase_name(snapshot.phase), 120, 78, 4);
  const String remaining = String(snapshot.remaining_seconds / 60) + ":" +
                           (snapshot.remaining_seconds % 60 < 10 ? "0" : "") +
                           String(snapshot.remaining_seconds % 60);
  display.drawString(remaining, 120, 122, 6);
  display.setTextColor(pending_events.empty() ? TFT_DARKGREEN : TFT_ORANGE,
                       TFT_BLACK);
  display.drawString(pending_events.empty() ? "SYNCED" : "PENDING", 120, 172,
                     2);
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
      apply_transition(focus_session->complete(millis(), epoch_now()));
    }
  } else if (!pressed && button_down) {
    button_down = false;
    if (long_press_handled) return;
    // Preserve one queue slot for the eventual terminal completion event.
    if (pending_events.size() >= kMaximumPendingEvents - 1) return;
    const auto phase = focus_session->snapshot(millis()).phase;
    if (phase == nudge::FocusPhase::idle) {
      apply_transition(focus_session->start(millis(), epoch_now()));
    } else if (phase == nudge::FocusPhase::running) {
      apply_transition(focus_session->pause(millis(), epoch_now()));
    } else if (phase == nudge::FocusPhase::paused) {
      apply_transition(focus_session->resume(millis(), epoch_now()));
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
  pixels.begin();
  pixels.setBrightness(40);
  pixels.clear();
  pixels.show();

  encoder_available = encoder.begin(kEncoderAddress);
  if (encoder_available) {
    encoder.pinMode(kEncoderSwitchPin, INPUT_PULLUP);
  }
  configure_ble();
  publish_state();
}

void loop() {
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
    if (const auto event = focus_session->tick(millis(), epoch_now());
        event.has_value()) {
      queue_event(*event);
    }
  }
  handle_encoder_button();
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
