#pragma once
// Copy to include/local_hardware_profile.h ONLY after the actual independent
// Station board, LCD signals, supply and existing connectors have been checked.
// This template deliberately supplies NO wiring recommendation.
#define NUDGE_LOCAL_HARDWARE_PROFILE 1
namespace demo {
inline HardwareProfile makeLocalHardwareProfile() {
  HardwareProfile p;
  // Fill p.mosi/clock/cs/dc/reset/backlight with confirmed ESP32 GPIO numbers.
  // Then set independentStationConfirmed and lcdWiringConfirmed.
  // P1 stays off until BOTH physical P0-A acceptance records exist.
  // Enable only one purchased module at a time, using confirmed existing wiring.
  return p;
}
}
