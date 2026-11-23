#include "demo/drawing.h"
namespace demo {
void CharacterPainter::render(Canvas& c,const Frame& f,bool entered,int x,int y,int size,bool animate) {
  const auto index=static_cast<unsigned>(f.scene);
  if(index>7)return;
  const auto pose=contract::kScenePoses[index];
  // One gentle 900ms motion; Focus is always still. No timers/delays here.
  const int phase=animate && pose!=contract::Pose::focus && f.elapsedMs<900 ? f.elapsedMs/300 : 2;
  if(!entered && pose_==static_cast<int>(pose) && phase_==phase)return;
  pose_=static_cast<int>(pose);phase_=phase;
  c.rect(x,y,size,size,color::background);
  const int dy=phase==1?-1:0;
  const auto asset=contract::asset(pose);
  for(std::size_t i=0;i<asset.size;++i){
    const auto& m=asset.marks[i];
    const int px=x+m.x*size/64,py=y+m.y*size/64+dy;
    if(m.kind=='c')c.circle(px,py,m.a*size/64>0?m.a*size/64:1,m.ink);
    else c.line(px,py,x+m.a*size/64,y+m.b*size/64+dy,m.ink);
  }
}
}
