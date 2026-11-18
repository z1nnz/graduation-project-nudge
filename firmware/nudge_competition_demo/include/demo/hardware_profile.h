#pragma once
namespace demo {
struct HardwareProfile {
  bool orbit = false;
  bool independentStationConfirmed = false;
  bool lcdWiringConfirmed = false;
  int mosi = -1, clock = -1, cs = -1, dc = -1, reset = -1, backlight = -1;
  unsigned rotation = 0;
  bool invertColors = true;  // ST7789 library default; confirm with the color test.
  bool orbitP0aAccepted = false, stationP0aAccepted = false, armP1 = false;
  bool peripheralWiringConfirmed = false;
  int sda = -1, scl = -1, buttonPin = -1, ledPin = -1;
  bool button = false, encoder = false, led = false, light = false, buzzer = false;
  bool ledSignalPathReady = false;
  bool orbitP0bAccepted=false,stationP0bAccepted=false,visualsAccepted=false;
  bool tenReplaysAccepted=false,armBle=false;
};
bool exposedGpio(int pin);
const char* lcdProfileError(const HardwareProfile& p);
bool p1Allowed(const HardwareProfile& p, bool displayAvailable);
bool bleAllowed(const HardwareProfile& p,bool displayAvailable);
bool optionalPinAllowed(const HardwareProfile& p, int pin);
bool i2cPinsAllowed(const HardwareProfile& p);
const HardwareProfile& hardwareProfile();
}
