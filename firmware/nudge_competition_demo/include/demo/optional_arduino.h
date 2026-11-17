#pragma once
#ifdef ARDUINO
#include "demo/core.h"
namespace demo {
void beginOptionals(bool displayAvailable);
void updateOptionals(const Frame& frame,std::uint32_t now);
Command takeOptionalCommand();
int takeOptionalRotation();
unsigned optionalBrightness();
void toggleOptionalMute();
}
#endif
