#pragma once
#ifdef ARDUINO
#include "demo/core.h"
namespace demo {
void beginDemoBle(bool displayAvailable);
Command takeDemoBleCommand();
void publishDemoBle(const Frame& frame);
}
#endif
