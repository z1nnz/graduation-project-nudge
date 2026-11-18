#pragma once
#include "demo/core.h"
#include <array>
#include <cstddef>
namespace demo {
class DebouncedPress {
 public:
  Command update(bool pressed,std::uint32_t now,Command shortAction=Command::next);
 private:
  bool initialized_=false,raw_=false,stable_=false,armed_=false,longSent_=false;
  std::uint32_t changed_=0,down_=0;
};
class ThreeLevelLight {
 public:
  unsigned update(float lux,bool valid,std::uint32_t now);
 private:
  bool initialized_=false,sampled_=false;
  float filtered_=100;
  unsigned percent_=55;
  std::uint32_t sampledAt_=0;
};
struct LedOutput { unsigned count; std::uint32_t rgb; unsigned brightness; };
LedOutput ledOutput(const Frame& f);
bool encoderDelta(std::int32_t current,std::int32_t previous,int& delta);
struct Tone { unsigned frequency=0,durationMs=0; };
class BuzzerPlan {
 public:
  Tone update(const Frame& f,std::uint32_t now);
  void setMuted(bool muted) { muted_=muted; pending_=false; }
  bool muted() const { return muted_; }
 private:
  bool muted_=false,seen_=false,pending_=false;
  Scene previous_=Scene::boot;
  std::uint32_t secondAt_=0;
};
// false from either begin or update disables that port for this boot; no retry loop.
struct OptionalPeripheral {
  virtual bool begin()=0;
  virtual bool update(const Frame& f,std::uint32_t now)=0;
  virtual const char* name() const=0;
  virtual ~OptionalPeripheral()=default;
};
using PeripheralLog = void (*)(const char*,const char*);
class PeripheralGroup {
 public:
  void add(OptionalPeripheral& port);
  void begin(bool allowed,PeripheralLog log);
  void update(const Frame& f,std::uint32_t now);
  bool active(std::size_t index) const { return index<size_ && active_[index]; }
 private:
  std::array<OptionalPeripheral*,5> ports_{};
  std::array<bool,5> active_{};
  std::size_t size_=0;
  PeripheralLog log_=nullptr;
};
}
