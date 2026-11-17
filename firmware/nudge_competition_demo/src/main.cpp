#ifdef ARDUINO
#include <Arduino.h>
#include "demo/core.h"
#include "demo/drawing.h"
#include "demo/optional_arduino.h"
#include "demo/station_arduino.h"

#ifndef NUDGE_ANIMATION
#define NUDGE_ANIMATION 1
#endif
#ifndef NUDGE_DISPLAY_TEST
#define NUDGE_DISPLAY_TEST 0
#endif

#ifdef NUDGE_DEVICE_ORBIT
#include <TFT_eSPI.h>
namespace {
TFT_eSPI screen;
TFT_eSprite buffer(&screen);
template <typename Surface>
class TftCanvas final : public demo::Canvas {
 public:
  explicit TftCanvas(Surface& surface) : target(surface) {}
  Surface& target;
  void clear(std::uint16_t ink) override { target.fillScreen(ink); }
  void rect(int x, int y, int w, int h, std::uint16_t ink) override { target.fillRect(x, y, w, h, ink); }
  void line(int x, int y, int x2, int y2, std::uint16_t ink) override { target.drawLine(x, y, x2, y2, ink); }
  void circle(int x, int y, int r, std::uint16_t ink) override { target.fillCircle(x, y, r, ink); }
  void text(int x, int y, const char* value, int size, std::uint16_t ink) override {
    target.setTextFont(1);
    target.setTextSize(size);
    target.setTextColor(ink, demo::color::background);
    target.setCursor(x, y);
    target.print(value);
  }
};
TftCanvas<TFT_eSPI> canvas(screen);
TftCanvas<TFT_eSprite> bufferedCanvas(buffer);
class OrbitDisplay final : public demo::DisplayPort {
 public:
  bool begin() override {
    screen.init();
    screen.setRotation(0);
    screen.setTextWrap(false);
    pwm_ = ledcSetup(7,5000,8)>0;
    if(pwm_)ledcAttachPin(TFT_BL,7);
    else Serial.println("orbit backlight PWM unavailable; fixed ON");
    brightness(55);
    buffer.setColorDepth(16);
    buffered_ = buffer.createSprite(240, 240) != nullptr;
    buffer.setTextWrap(false);
    Serial.println(buffered_ ? "display buffer ok" : "display buffer unavailable; direct static fallback");
    Serial.println("display driver init issued; physical panel UNVERIFIED");
    return screen.width() == 240 && screen.height() == 240;
  }
  void render(const demo::Frame& frame, bool entered) override {
    demo::Canvas& target = entered && buffered_ ? static_cast<demo::Canvas&>(bufferedCanvas) : canvas;
    painter_.render(target, frame, entered);
    if (entered && buffered_) buffer.pushSprite(0, 0);
  }
  void showFatal(const char* code) override { Serial.println(code); }
  void brightness(unsigned percent) {
    percent=percent>80?80:percent<30?30:percent;
    if(percent==brightness_)return;
    brightness_=percent;
    if(pwm_)ledcWrite(7,percent*255/100);else digitalWrite(TFT_BL,HIGH);
  }
 private:
  bool buffered_ = false;
  bool pwm_ = false;
  unsigned brightness_ = 0;
  demo::Painter painter_{demo::Device::orbit, NUDGE_ANIMATION != 0};
} display;
constexpr const char* device = "orbit";
}
#else
namespace {
demo::DisplayPort& display=demo::stationDisplay();
constexpr const char* device = "station";
}
#endif

namespace {
#ifdef NUDGE_P0A
demo::Scenario scenario(demo::Mode::p0a);
#else
demo::Scenario scenario(demo::Mode::p0b);
#endif
demo::Runtime runtime(scenario, display);
std::uint32_t lastFrame = 0;
std::uint32_t loggedGeneration = ~0U;
int previousColor = -1;
bool calibrated = false;
}
void setup() {
  Serial.begin(115200);  // Never wait for a host/Serial connection.
  Serial.printf("NUDGE_DEMO boot device=%s build=%s\n", device, NUDGE_BUILD_ID);
  Serial.println("offline autoplay; GPIO profile and P1 acceptance gates enforced");
  runtime.begin(millis());
  demo::beginOptionals(runtime.displayAvailable());
  // Display initialization can consume time. Start the visible Boot dwell
  // afterwards so a slow init cannot make the first loop skip Boot entirely.
  scenario.restart(millis());
}
void loop() {
  const std::uint32_t now = millis();
  demo::Command command = demo::Command::none;
  for (int i = 0; i < 16 && Serial.available(); ++i) {
    const char ch=static_cast<char>(Serial.read());
    if(ch=='M' || ch=='m'){demo::toggleOptionalMute();continue;}
    command = demo::serialCommand(ch);
    if (command != demo::Command::none) break;
  }
  demo::updateOptionals(scenario.frame(now),now);
  const auto physical=demo::takeOptionalCommand();
  if(command==demo::Command::none || physical==demo::Command::restart)command=physical;
  const int delta=demo::takeOptionalRotation();
  if(command!=demo::Command::restart)scenario.rotateTask(delta,now);
#ifdef NUDGE_DEVICE_ORBIT
  if(runtime.displayAvailable())display.brightness(demo::optionalBrightness());
  if (NUDGE_DISPLAY_TEST == 1) {
    const int index = static_cast<int>((now / 2000U) % 5U);
    if (index != previousColor) {
      static constexpr std::uint16_t colors[] = {0xF800, 0x07E0, 0x001F, 0x0000, 0xFFFF};
      screen.fillScreen(colors[index]);
      Serial.printf("panel color %d UNVERIFIED\n", index);
      previousColor = index;
    }
    return;
  }
  if (NUDGE_DISPLAY_TEST == 2) {
    if (!calibrated) { demo::paintCalibration(canvas); calibrated = true; }
    return;
  }
#endif
#ifdef NUDGE_DEVICE_STATION
  demo::setStationBrightness(demo::optionalBrightness());
  if(NUDGE_DISPLAY_TEST!=0){demo::stationDiagnostics(NUDGE_DISPLAY_TEST,now);return;}
#endif
  if (command != demo::Command::none || now - lastFrame >= 50U) {
    runtime.update(now, command);
    lastFrame = now;
    if (loggedGeneration != scenario.generation()) {
      Serial.printf("scene %u %s\n", static_cast<unsigned>(scenario.scene()), demo::sceneName(scenario.scene()));
      loggedGeneration = scenario.generation();
    }
  }
}
#endif
