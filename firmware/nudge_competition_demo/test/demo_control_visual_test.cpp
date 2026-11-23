#include "demo/ble_protocol.h"
#include "demo/drawing.h"
#include "demo/hardware_profile.h"
#include <cassert>
#include <cstring>
#include <iostream>
#include <set>
#include <sstream>
using namespace demo;
struct Capture:Canvas{
  int clears=0,marks=0;std::ostringstream signature;
  void clear(std::uint16_t)override{++clears;}
  void rect(int x,int y,int w,int h,std::uint16_t)override{assert(x>=0&&y>=0&&x+w<=240&&y+h<=320);++marks;}
  void line(int x,int y,int a,int b,std::uint16_t ink)override{assert(x>=0&&x<240&&y>=0&&y<320&&a>=0&&a<240&&b>=0&&b<320);signature<<'l'<<x<<','<<y<<','<<a<<','<<b<<','<<ink<<';';++marks;}
  void circle(int x,int y,int r,std::uint16_t ink)override{assert(x-r>=0&&x+r<240&&y-r>=0&&y+r<320);signature<<'c'<<x<<','<<y<<','<<r<<','<<ink<<';';++marks;}
  void text(int,int,const char*,int,std::uint16_t)override{}
};
int main(){
  const char* next="{\"v\":1,\"type\":\"demo\",\"action\":\"next\"}";
  assert(parseDemoCommand(next,std::strlen(next),true)==Command::next);
  assert(parseDemoCommand(next,std::strlen(next),false)==Command::none);
  const char* restart=" { \"action\":\"restart\",\"type\":\"demo\",\"v\":1 } ";
  assert(parseDemoCommand(restart,std::strlen(restart),true)==Command::restart);
  const char* start="{\"v\":1,\"type\":\"demo\",\"action\":\"startFocus\"}";
  assert(parseDemoCommand(start,std::strlen(start),true)==Command::start);
  for(const char* bad:{"{}","{\"v\":2,\"type\":\"demo\",\"action\":\"next\"}","{\"v\":1.0,\"type\":\"demo\",\"action\":\"next\"}","{\"v\":1,\"v\":1,\"action\":\"next\"}","{\"v\":1,\"type\":\"demo\",\"action\":\"complete\"}","{\"v\":1,\"type\":\"demo\",\"action\":\"next\",\"userId\":\"real\"}","{\"v\":1,\"type\":\"activity\",\"action\":\"next\"}","{\"v\":1,\"type\":\"demo\",\"action\":\"next\"}garbage"})assert(parseDemoCommand(bad,std::strlen(bad),true)==Command::none);
  std::string large(97,' ');assert(parseDemoCommand(large.data(),large.size(),true)==Command::none);
  for(unsigned i=0;i<8;++i)for(auto device:{Device::orbit,Device::station}){
    const auto json=encodeDemoState(device,static_cast<Scene>(i));assert(json.size()<96);
    assert(json.find("\"mode\":\"demo\"")!=std::string::npos&&json.find(contract::kScenes[i])!=std::string::npos);
    assert(json.find("user")==std::string::npos&&json.find("health")==std::string::npos);
  }
  HardwareProfile p;assert(!bleAllowed(p,true));
  p.armBle=p.orbitP0bAccepted=p.stationP0bAccepted=p.visualsAccepted=p.tenReplaysAccepted=true;
  assert(bleAllowed(p,true)&&!bleAllowed(p,false));p.tenReplaysAccepted=false;assert(!bleAllowed(p,true));
  std::set<std::string> poses;
  for(unsigned i=1;i<=6;++i){
    Capture c;CharacterPainter painter;Frame f{static_cast<Scene>(i),0,20000,0,20,&data()};
    painter.render(c,f,true,80,100,64,false);poses.insert(c.signature.str());const int count=c.marks;
    f.elapsedMs=300;painter.render(c,f,false,80,100,64,false);assert(c.marks==count);
  }
  assert(poses.size()==6);
  Capture still;CharacterPainter painter;Frame focus{Scene::focus,0,20000,0,20,&data()};
  painter.render(still,focus,true,80,100,64,true);const int count=still.marks;
  for(unsigned t=300;t<20000;t+=300){focus.elapsedMs=t;painter.render(still,focus,false,80,100,64,true);}assert(still.marks==count);
  Capture animated;CharacterPainter motion;Frame home{Scene::home,0,4000,0,4,&data()};motion.render(animated,home,true,80,100,64,true);
  home.elapsedMs=300;motion.render(animated,home,false,80,100,64,true);const int moved=animated.marks;
  home.elapsedMs=900;motion.render(animated,home,false,80,100,64,true);assert(animated.marks>moved);const int final=animated.marks;
  home.elapsedMs=3000;motion.render(animated,home,false,80,100,64,true);assert(animated.marks==final&&animated.clears==0);
  Scenario s;s.restart(0);for(unsigned i=0;i<10;++i){const auto before=s.generation();s.next(i*100);assert(s.generation()==before+1);}for(unsigned i=0;i<5;++i){s.restart(2000+i*100);assert(s.scene()==Scene::boot);}
  std::cout<<"PASS: demo protocol, P2 gate, six shared poses, animation off/static Focus, command isolation\n";
}
