#include "demo/drawing.h"
#include "demo/orbit_assets.h"
#include <cassert>
#include <cstring>
#include <iostream>

using namespace demo;
struct BoundedCanvas : Canvas {
  int clears=0,rects=0,lines=0;
  bool demo=false,coinClaim=false;
  void clear(std::uint16_t) override { ++clears; }
  void rect(int x,int y,int w,int h,std::uint16_t) override {
    assert(x>=0 && y>=0 && w>0 && h>0 && x+w<=240 && y+h<=240);
    ++rects;
  }
  void line(int x,int y,int xx,int yy,std::uint16_t) override {
    assert(x>=0 && y>=0 && xx>=0 && yy>=0 && x<240 && y<240 && xx<240 && yy<240);
    ++lines;
  }
  void circle(int x,int y,int r,std::uint16_t) override {
    assert(x-r>=0 && y-r>=0 && x+r<240 && y+r<240);
  }
  void text(int x,int y,const char* t,int size,std::uint16_t) override {
    assert(x>=0 && y>=0 && x+static_cast<int>(std::strlen(t))*6*size<=240 && y+8*size<=240);
    demo |= std::strstr(t,"DEMO")!=nullptr;
    coinClaim |= std::strstr(t,"XP +")!=nullptr || std::strstr(t,"SYNCED")!=nullptr;
  }
};
int main() {
  // Test public paint output, not the layout's private helper implementation.
  for (unsigned i=0;i<8;++i) {
    BoundedCanvas c; Painter p(Device::orbit,false);
    Frame f{static_cast<Scene>(i),0,20000,0,20,&data()};
    p.render(c,f,true);
    assert(c.demo && !c.coinClaim && c.clears==1);
    // Non-summary scenes contain the compiled App illustration, not seven sprout marks.
    if(f.scene!=Scene::summary) assert(c.rects>1000);
    const int before=c.rects;
    p.render(c,f,false);
    assert(c.rects==before && c.clears==1);
  }
  BoundedCanvas c; Painter p(Device::orbit);
  Frame f{Scene::focus,0,20000,0,20,&data()};
  p.render(c,f,true);
  const int full=c.rects;
  f.remainingSeconds=9; f.progress=550;
  p.render(c,f,false);
  // Countdown changes repaint only its own small area, not all character pixels.
  assert(c.rects==full+1 && c.clears==1 && c.lines>0);
  f.progress=65535;
  p.render(c,f,false); // Malformed progress cannot paint beyond the ring.
  assert(c.clears==1);
  // Resource budget is deliberately bounded for the ESP32 flash-resident subset.
  static_assert(sizeof(orbit_assets::heroRuns)+sizeof(orbit_assets::focusHeroRuns)<50000);
  std::cout<<"PASS: App art, TC labels, eight bounded scenes, honest demo, incremental focus\n";
}
