#include "demo/peripherals.h"
#include "demo/generated_contract.h"
#include <algorithm>
#include <cmath>
namespace demo {
namespace {
std::uint32_t rgb(std::uint16_t c){return ((c>>11)*255U/31<<16)|(((c>>5)&63)*255U/63<<8)|((c&31)*255U/31);}
}
Command DebouncedPress::update(bool pressed,std::uint32_t now,Command shortAction) {
  if(!initialized_){initialized_=true;raw_=pressed;changed_=now;armed_=!pressed;}
  if(pressed!=raw_){raw_=pressed;changed_=now;}
  if(!raw_ && !stable_ && now-changed_>=40U)armed_=true;
  if(raw_!=stable_ && now-changed_>=40U) {
    stable_=raw_;
    if(stable_){down_=now;longSent_=false;}
    else {
      const bool emit=armed_ && !longSent_;armed_=true;
      if(emit)return shortAction;
    }
  }
  if(stable_ && armed_ && !longSent_ && now-down_>=1200U){longSent_=true;return Command::restart;}
  return Command::none;
}
unsigned ThreeLevelLight::update(float lux,bool valid,std::uint32_t now) {
  if(sampled_ && now-sampledAt_<1000U)return percent_;
  sampled_=true;sampledAt_=now;
  if(!valid || !std::isfinite(lux) || lux<0 || lux>200000){initialized_=false;percent_=55;return percent_;}
  if(!initialized_){filtered_=lux;initialized_=true;}else filtered_=filtered_*0.75F+lux*0.25F;
  if(percent_==30){if(filtered_>120)percent_=55;}
  else if(percent_==80){if(filtered_<400)percent_=55;}
  else if(filtered_<80)percent_=30;
  else if(filtered_>600)percent_=80;
  return percent_;
}
LedOutput ledOutput(const Frame& f) {
  if(f.scene==Scene::focus)return {std::min(10U,static_cast<unsigned>(f.progress)*10/1000),rgb(color::primary),16};
  if((f.scene==Scene::complete || f.scene==Scene::growth) && f.elapsedMs<2000)return {10,rgb(color::complete),16};
  return {10,rgb(color::primary),4};
}
bool encoderDelta(std::int32_t current,std::int32_t previous,int& out) {
  std::int64_t delta=static_cast<std::int64_t>(current)-previous;
  if(delta>2147483647LL)delta-=4294967296LL;
  if(delta< -2147483648LL)delta+=4294967296LL;
  if(delta>12 || delta< -12){out=0;return false;}
  out=static_cast<int>(delta);return true;
}
Tone BuzzerPlan::update(const Frame& f,std::uint32_t now) {
  const bool entered=!seen_ || previous_!=f.scene;seen_=true;previous_=f.scene;
  if(muted_)return {};
  if(entered) {
    pending_=false;
    if(f.scene==Scene::focus)return {1700,60};
    if(f.scene==Scene::complete){pending_=true;secondAt_=now;return {1800,50};}
  }
  if(pending_ && now-secondAt_>=80){pending_=false;return {2200,50};}
  return {};
}
void PeripheralGroup::add(OptionalPeripheral& p) { if(size_<ports_.size())ports_[size_++]=&p; }
void PeripheralGroup::begin(bool allowed,PeripheralLog log) {
  log_=log;
  for(std::size_t i=0;i<size_;++i){active_[i]=allowed && ports_[i]->begin();if(log_)log_(ports_[i]->name(),!allowed?"gated":active_[i]?"software init issued; physical unverified":"skipped");}
}
void PeripheralGroup::update(const Frame& f,std::uint32_t now) {
  for(std::size_t i=0;i<size_;++i)if(active_[i] && !ports_[i]->update(f,now)){active_[i]=false;if(log_)log_(ports_[i]->name(),"disabled after failure; autoplay continues");}
}
}
