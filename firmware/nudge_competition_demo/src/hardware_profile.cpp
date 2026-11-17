#include "demo/hardware_profile.h"
#if __has_include("local_hardware_profile.h")
#include "local_hardware_profile.h"
#endif
namespace demo {
bool exposedGpio(int pin) { return (pin >= 1 && pin <= 9) || pin == 43 || pin == 44; }
const char* lcdProfileError(const HardwareProfile& p) {
  if (!p.independentStationConfirmed || !p.lcdWiringConfirmed) return "STATION_PINMAP_UNCONFIRMED";
  const int pins[] = {p.mosi, p.clock, p.cs, p.dc, p.reset, p.backlight};
  for (unsigned i = 0; i < 6; ++i) {
    if (!exposedGpio(pins[i])) return "STATION_PIN_INVALID";
    for (unsigned j = 0; j < i; ++j) if (pins[i] == pins[j]) return "STATION_PIN_CONFLICT";
  }
  if (p.rotation != 0 && p.rotation != 2) return "STATION_PORTRAIT_REQUIRED";
  return nullptr;
}
bool p1Allowed(const HardwareProfile& p, bool displayAvailable) {
  return displayAvailable && p.armP1 && p.orbitP0aAccepted && p.stationP0aAccepted && p.peripheralWiringConfirmed;
}
bool optionalPinAllowed(const HardwareProfile& p, int pin) {
  if (!exposedGpio(pin)) return false;
  if(p.orbit){const int reserved[]={2,4,7,8,9,43,44};for(int used:reserved)if(pin==used)return false;}
  const int lcd[] = {p.mosi,p.clock,p.cs,p.dc,p.reset,p.backlight};
  for (int used : lcd) if (pin == used) return false;
  return true;
}
bool i2cPinsAllowed(const HardwareProfile& p) {
  return optionalPinAllowed(p,p.sda) && optionalPinAllowed(p,p.scl) && p.sda != p.scl;
}
const HardwareProfile& hardwareProfile() {
#ifdef NUDGE_LOCAL_HARDWARE_PROFILE
  static HardwareProfile p = makeLocalHardwareProfile();
#else
  static HardwareProfile p;
#endif
#ifdef NUDGE_DEVICE_ORBIT
  p.orbit=true;
#endif
  return p;
}
}
