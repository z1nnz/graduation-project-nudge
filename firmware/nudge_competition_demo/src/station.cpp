#include "demo/station.h"
#include <cstdio>
#include <initializer_list>
namespace demo {
namespace {
void label(Canvas& c,int y,const char* s,int size=2,std::uint16_t ink=color::text) { c.text(16,y,s,size,ink); }

}
void StationPainter::render(Canvas& c,const Frame& f,bool entered) {
  const auto& d=*f.values;char text[40];
  const char* task=d.taskLabels[f.taskIndex<3?f.taskIndex:0];
  if(entered) {
    second_=progress_=-1;c.clear(color::background);
    label(c,16,"NUDGE STATION",2,color::ready);
    label(c,288,"DEMO / OFFLINE",2,color::muted);
    c.line(12,44,228,44,color::muted);
    switch(f.scene) {
      case Scene::boot:
        label(c,64,"DESK COMPANION");
        // A short build id fits in the lower right without competing with DEMO.
        std::snprintf(text,sizeof(text),"%.12s",buildId_);c.text(152,270,text,1,color::muted);break;
      case Scene::home:
        label(c,60,"NEXT",2,color::primary);label(c,90,task,3);
        std::snprintf(text,sizeof(text),"%d MIN FOCUS",d.focusMinutes);label(c,128,text);

        std::snprintf(text,sizeof(text),"TODAY %d/3",d.todayFocusCount);label(c,248,text);break;
      case Scene::ready:
        label(c,60,"CHOOSE A TASK",2,color::ready);
        for(unsigned i=0;i<3;++i) {
          if(i==f.taskIndex)c.rect(12,96+46*i,4,34,color::primary);
          c.text(20,104+46*i,d.taskLabels[i],2,color::text);
        }
        label(c,248,"AUTO: FIRST TASK",2,color::muted);break;
      case Scene::focus:
        label(c,60,task,2,color::primary);label(c,138,"20 SEC PREVIEW",2,color::muted);
        c.rect(16,250,208,12,color::muted);break;
      case Scene::encouragement:
        std::snprintf(text,sizeof(text),"ROOM %d/%d",d.activeMembers,d.totalMembers);
        label(c,60,text,3,color::support);label(c,108,"KEEP GOING");
        label(c,140,"WE ARE HERE");
        label(c,250,"YOU START / STOP",2,color::support);break;
      case Scene::complete:
        label(c,60,"FOCUS COMPLETE",2,color::complete);
        std::snprintf(text,sizeof(text),"%d MIN",d.focusMinutes);label(c,102,text,3);
        c.line(172,184,183,195,color::complete);c.line(183,195,207,168,color::complete);break;
      case Scene::growth:
        std::snprintf(text,sizeof(text),"SPROUT LEVEL %d",d.characterLevel);label(c,60,text);
        std::snprintf(text,sizeof(text),"DEMO XP +%d",d.demoXp);label(c,248,text,2,color::complete);break;
      case Scene::summary:
        label(c,60,"TODAY",3,color::ready);
        std::snprintf(text,sizeof(text),"TASKS %d/3",d.todayFocusCount);label(c,116,text);
        std::snprintf(text,sizeof(text),"FOCUS %d MIN",d.todayFocusMinutes);label(c,162,text);
        std::snprintf(text,sizeof(text),"SCORE %d",d.disciplineScore);label(c,208,text);
        label(c,254,"HOME IN 8 SEC",2,color::muted);break;
    }
  }
  if(f.scene==Scene::focus) {
    if(second_!=static_cast<int>(f.remainingSeconds)) {
      c.rect(16,98,208,36,color::background);
      std::snprintf(text,sizeof(text),"%02u:%02u",f.remainingSeconds/60,f.remainingSeconds%60);label(c,100,text,4);
      second_=static_cast<int>(f.remainingSeconds);
    }
    const int progress=f.progress*208/1000;
    if(progress>progress_) {
      const int from=progress_<0?0:progress_;
      c.rect(16+from,250,progress-from,12,color::primary);progress_=progress;
    }
  }
  if(f.scene!=Scene::summary){
    const bool ready=f.scene==Scene::ready;
    character_.render(c,f,entered,ready?192:80,ready?48:156,ready?32:80,animate_);
  }
}
void paintStationCalibration(Canvas& c,unsigned rotation) {
  c.clear(color::background);
  for(int margin:{8,12}) {
    c.line(margin,margin,239-margin,margin,color::ready);c.line(margin,319-margin,239-margin,319-margin,color::ready);
    c.line(margin,margin,margin,319-margin,color::ready);c.line(239-margin,margin,239-margin,319-margin,color::ready);
  }
  label(c,32,"NUDGE STATION");label(c,82,"240 x 320");label(c,128,"123",4);label(c,180,"16PX LABEL",2);label(c,220,"8PX REFERENCE",1);
  char text[24];std::snprintf(text,sizeof(text),"ROTATION %u",rotation);label(c,260,text,2,color::muted);
}
}
