#pragma once
#ifdef ARDUINO
#include "demo/core.h"
namespace demo {
DisplayPort& stationDisplay();
void stationDiagnostics(unsigned mode,std::uint32_t now);
void setStationBrightness(unsigned percent);
}
#endif
