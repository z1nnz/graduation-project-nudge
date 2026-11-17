#include "demo/station.h"
#include "demo/hardware_profile.h"
#include "demo/peripherals.h"
#include <cassert>
#include <cmath>
#include <limits>
#include <string>
#include <vector>
#include <iostream>
using namespace demo;
namespace {
struct CanvasLog:Canvas {
  int clears=0,marks=0;std::vector<std::string> textValues;
  void clear(std::uint16_t)override{++clears;}
  void rect(int x,int y,int w,int h,std::uint16_t)override{assert(x>=0 && y>=0 && x+w<=240 && y+h<=320);++marks;}
  void line(int x,int y,int x2,int y2,std::uint16_t)override{assert(x>=0&&x<240&&x2>=0&&x2<240&&y>=0&&y<320&&y2>=0&&y2<320);++marks;}
  void circle(int x,int y,int r,std::uint16_t)override{assert(x-r>=0&&x+r<240&&y-r>=0&&y+r<320);++marks;}
  void text(int x,int y,const char* s,int size,std::uint16_t)override{
    std::string v(s);assert(x>=8&&y>=8&&x+static_cast<int>(v.size())*6*size<=232&&y+8*size<=312);textValues.push_back(v);
  }
  bool has(const std::string& s)const{for(const auto& v:textValues)if(v.find(s)!=std::string::npos)return true;return false;}
};
struct Port:OptionalPeripheral {
  bool start=true,healthy=true;int begins=0,updates=0;
  const char* name()const override{return "fake";}
  bool begin()override{++begins;return start;}
  bool update(const Frame&,std::uint32_t)override{++updates;return healthy;}
};
struct Display:DisplayPort {int renders=0;bool begin()override{return true;}void render(const Frame&,bool)override{++renders;}void showFatal(const char*)override{assert(false);}};
Frame frame(Scene s){return {s,0,20000,0,20,&data()};}
}
int main(){
  // Synthetic host-only assignment, NOT a wiring recommendation.
  HardwareProfile p;assert(lcdProfileError(p));assert(!p1Allowed(p,true));
  p.independentStationConfirmed=p.lcdWiringConfirmed=true;
  p.mosi=1;p.clock=2;p.cs=3;p.dc=4;p.reset=7;p.backlight=8;
  assert(!lcdProfileError(p));p.clock=p.cs;assert(lcdProfileError(p));p.clock=2;
  p.rotation=1;assert(lcdProfileError(p));p.rotation=2;assert(!lcdProfileError(p));
  p.clock=19;assert(lcdProfileError(p));p.clock=2;
  p.armP1=p.orbitP0aAccepted=p.stationP0aAccepted=p.peripheralWiringConfirmed=true;
  assert(p1Allowed(p,true)&&!p1Allowed(p,false));p.stationP0aAccepted=false;assert(!p1Allowed(p,true));p.stationP0aAccepted=true;
  assert(!optionalPinAllowed(p,4));p.sda=5;p.scl=6;assert(i2cPinsAllowed(p));p.scl=5;assert(!i2cPinsAllowed(p));
  HardwareProfile orbit;orbit.orbit=true;assert(!optionalPinAllowed(orbit,9)&&!optionalPinAllowed(orbit,43)&&optionalPinAllowed(orbit,5));
  assert(lcdProfileError(hardwareProfile()) && !p1Allowed(hardwareProfile(),true));
  // All eight scenes fit the actual 240x320 viewport with readable labels.
  std::vector<std::vector<std::string>> scenes;
  for(unsigned i=0;i<8;++i){CanvasLog c;StationPainter painter("123456789abc");painter.render(c,frame(static_cast<Scene>(i)),true);assert(c.clears==1&&c.has("DEMO"));scenes.push_back(c.textValues);}
  for(unsigned i=0;i<8;++i)for(unsigned j=0;j<i;++j)assert(scenes[i]!=scenes[j]);
  CanvasLog c;StationPainter painter;auto f=frame(Scene::ready);painter.render(c,f,true);assert(c.has("PROJECT")&&c.has("READ 25 MIN")&&c.has("WALK 3000"));
  CanvasLog support;StationPainter supportPainter;supportPainter.render(support,frame(Scene::encouragement),true);assert(support.has("ROOM 3/5")&&support.has("YOU START / STOP"));
  CanvasLog cal;paintStationCalibration(cal);assert(cal.has("240 x 320"));
  CanvasLog focus;StationPainter focusPainter;f=frame(Scene::focus);focusPainter.render(focus,f,true);const int marks=focus.marks;
  focusPainter.render(focus,f,false);assert(focus.marks==marks&&focus.clears==1);
  f.progress=500;f.remainingSeconds=10;focusPainter.render(focus,f,false);assert(focus.has("00:10")&&focus.clears==1);
  CanvasLog selected;StationPainter selectedPainter;f.taskIndex=2;selectedPainter.render(selected,f,true);assert(selected.has("WALK 3000"));
  // Selection, confirmation, reset and no-input fallback use the same core.
  Scenario scenario;scenario.restart(0);scenario.tick(1500);scenario.rotateTask(-1,1600);assert(scenario.frame(1600).taskIndex==2);
  scenario.startFocus(1700);assert(scenario.scene()==Scene::focus);scenario.rotateTask(1,1800);assert(scenario.frame(1800).taskIndex==2);
  scenario.restart(2000);assert(scenario.frame(2000).taskIndex==0);scenario.tick(3500);scenario.tick(7500);scenario.tick(10500);assert(scenario.scene()==Scene::focus&&scenario.frame(10500).taskIndex==0);
  // 40ms debounce: bounces do not advance; a release produces exactly one short action.
  DebouncedPress press;assert(press.update(false,0)==Command::none);press.update(true,100);press.update(false,110);press.update(true,120);
  assert(press.update(true,159)==Command::none);press.update(true,160);press.update(false,200);
  assert(press.update(false,239)==Command::none);assert(press.update(false,240)==Command::next);assert(press.update(false,300)==Command::none);
  press.update(true,400);press.update(true,440);assert(press.update(true,1639)==Command::none);assert(press.update(true,1640)==Command::restart);
  assert(press.update(true,1900)==Command::none);press.update(false,2000);assert(press.update(false,2040)==Command::none);
  DebouncedPress held;held.update(true,0);held.update(false,20);held.update(false,60);held.update(true,100);held.update(true,140);held.update(false,200);assert(held.update(false,240,Command::start)==Command::start);
  DebouncedPress wrap;wrap.update(false,0xFFFFFF00U);wrap.update(true,0xFFFFFF10U);wrap.update(true,0xFFFFFF38U);assert(wrap.update(true,999)==Command::none);assert(wrap.update(true,1000)==Command::restart);
  // One sample/second, EWMA + hysteresis, immediate fixed fallback on invalid data.
  ThreeLevelLight light;assert(light.update(0,true,0)==30);assert(light.update(10000,true,500)==30);
  assert(light.update(std::numeric_limits<float>::quiet_NaN(),true,1000)==55);
  assert(light.update(1000,true,2000)==80);assert(light.update(999,true,3000)==80);assert(light.update(-1,true,4000)==55);
  assert(light.update(100,true,5000)==55);assert(light.update(115,true,6000)==55);assert(light.update(90,true,7000)==55);
  assert(light.update(0,false,8000)==55);
  int delta=0;assert(encoderDelta(2,1,delta)&&delta==1);assert(encoderDelta(1,2,delta)&&delta==-1);
  assert(encoderDelta(std::numeric_limits<std::int32_t>::min(),std::numeric_limits<std::int32_t>::max(),delta)&&delta==1);
  assert(!encoderDelta(200000,0,delta)&&delta==0);
  f=frame(Scene::focus);f.progress=500;assert(ledOutput(f).count==5&&ledOutput(f).brightness<=16);
  f=frame(Scene::complete);assert(ledOutput(f).brightness==16);f.elapsedMs=2000;assert(ledOutput(f).brightness==4);
  f=frame(Scene::growth);f.elapsedMs=2001;assert(ledOutput(f).brightness==4);
  BuzzerPlan tone;f=frame(Scene::home);assert(!tone.update(f,0).frequency);f=frame(Scene::focus);assert(tone.update(f,10).frequency==1700);assert(!tone.update(f,20).frequency);
  f=frame(Scene::complete);assert(tone.update(f,100).frequency==1800);assert(!tone.update(f,179).frequency);assert(tone.update(f,180).frequency==2200);assert(!tone.update(f,200).frequency);
  tone.setMuted(true);f=frame(Scene::focus);assert(!tone.update(f,300).frequency);tone.setMuted(false);assert(!tone.update(f,310).frequency);
  // Gating calls no driver at all. Each missing/faulty port is isolated, not retried.
  Port first,second;PeripheralGroup group;group.add(first);group.add(second);group.begin(false,nullptr);assert(first.begins==0&&second.begins==0);
  first.start=false;group.begin(true,nullptr);assert(!group.active(0)&&group.active(1));second.healthy=false;group.update(f,0);assert(!group.active(1));group.update(f,10);assert(second.updates==1);
  Display display;Scenario offline(Mode::p0a);Runtime runtime(offline,display);runtime.begin(0);
  for(std::uint32_t now=0;now<100000;now+=50){group.update(offline.frame(now),now);runtime.update(now);}
  assert(display.renders>1000&&first.updates==0&&second.updates==1);
  for(unsigned failed=0;failed<5;++failed){
    Port ports[5];PeripheralGroup isolated;for(auto& port:ports)isolated.add(port);
    ports[failed].start=false;isolated.begin(true,nullptr);
    Scenario autoDemo(Mode::p0a);Display screen;Runtime demo(autoDemo,screen);demo.begin(0);
    for(std::uint32_t now=0;now<100000;now+=50){isolated.update(autoDemo.frame(now),now);demo.update(now);}
    assert(!isolated.active(failed)&&ports[failed].updates==0&&screen.renders>1000);
    for(unsigned j=0;j<5;++j)if(j!=failed)assert(ports[j].updates>1000);
  }
  std::cout<<"PASS: station eight scenes, bounds, task selection, GPIO/P1 gates, debounce, light, LED, mute, failure isolation\n";
}
