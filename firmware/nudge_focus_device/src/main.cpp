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

#include <deque>
#include <memory>
#include <string>

#include "driver.h"
#include <TFT_eSPI.h>
#include "nudge/focus_session.h"
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
};

struct CommandMessage {
  char payload[512];
};

TFT_eSPI display;
Adafruit_seesaw encoder;
Adafruit_NeoPixel pixels(10, NUDGE_LED_PIN, NEO_GRB + NEO_KHZ800);
Preferences preferences;
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

void save_pending_events() {
  preferences.putUChar("eventCount", pending_events.size());
  for (std::size_t index = 0; index < kMaximumPendingEvents; ++index) {
    const String key = "event" + String(index);
    if (index < pending_events.size()) {
      preferences.putString(key.c_str(), pending_events[index].json.c_str());
    } else {
      preferences.remove(key.c_str());
    }
  }
}

void load_pending_events() {
  const auto count = std::min<std::size_t>(preferences.getUChar("eventCount", 0),
                                           kMaximumPendingEvents);
  for (std::size_t index = 0; index < count; ++index) {
    const String key = "event" + String(index);
    const String json = preferences.getString(key.c_str(), "");
    JsonDocument document;
    if (!json.isEmpty() && deserializeJson(document, json) == DeserializationError::Ok) {
      const char* event_id = document["eventId"] | "";
      if (*event_id != '\0') {
        pending_events.push_back(PendingMessage{event_id, json.c_str()});
      }
    }
  }
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
  pending_events.push_back(
      PendingMessage{event.event_id, nudge::encode_activity_event(event)});
  preferences.putUInt("sequence", focus_session->sequence());
  save_pending_events();
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
  pending_events.pop_front();
  save_pending_events();
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
    if (pending_events.size() >= kMaximumPendingEvents) return;
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
  device_id = build_device_id();
  focus_session = std::make_unique<nudge::FocusSession>(
      device_id, preferences.getUInt("sequence", 0));
  load_pending_events();
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
    const bool emits_event =
        deserializeJson(document, payload) == DeserializationError::Ok &&
        document["type"].is<const char*>() &&
        strcmp(document["type"].as<const char*>(), "configure") != 0 &&
        strcmp(document["type"].as<const char*>(), "ack") != 0;
    if (!emits_event || pending_events.size() < kMaximumPendingEvents) {
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
