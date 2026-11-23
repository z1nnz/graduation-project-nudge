#pragma once
#include "demo/core.h"
#include <cstddef>
#include <string>
namespace demo {
// Deliberately narrow ASCII JSON grammar: 3 unique known fields, no escapes,
// no duplicate/extra keys, exact integer v=1. Payload maximum 96 bytes.
Command parseDemoCommand(const char* bytes,std::size_t size,bool demoEnabled);
std::string encodeDemoState(Device device,Scene scene);
}
