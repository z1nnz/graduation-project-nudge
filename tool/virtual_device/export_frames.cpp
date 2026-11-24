// Export the existing firmware Canvas calls; no second implementation of scenes.
#include "demo/drawing.h"
#include "demo/station.h"
#include <fstream>
#include <string>
class Commands final : public demo::Canvas {
 public:
  std::ofstream out;
  bool comma=false;
  explicit Commands(const std::string& file):out(file){out<<"[";}
  ~Commands(){out<<"]";}
  void sep(){if(comma)out<<',';comma=true;}
  void clear(std::uint16_t c)override{rect(0,0,240,320,c);}
  void rect(int x,int y,int w,int h,std::uint16_t c)override{sep();out<<"[\"rect\","<<x<<','<<y<<','<<w<<','<<h<<','<<c<<']';}
  void line(int x,int y,int x2,int y2,std::uint16_t c)override{sep();out<<"[\"line\","<<x<<','<<y<<','<<x2<<','<<y2<<','<<c<<']';}
  void circle(int x,int y,int r,std::uint16_t c)override{sep();out<<"[\"circle\","<<x<<','<<y<<','<<r<<','<<c<<']';}
  void text(int x,int y,const char* value,int size,std::uint16_t c)override{sep();out<<"[\"text\","<<x<<','<<y<<",\"";for(auto p=value;*p;++p){if(*p=='"'||*p=='\\')out<<'\\';out<<*p;}out<<"\","<<size<<','<<c<<']';}
};
int main(int argc,char** argv){
 if(argc!=2)return 2;
 for(bool station:{false,true})for(int variant=0;variant<25;variant++){
  demo::DemoData values=demo::data();const bool idle=variant<2,complete=variant>=2&&variant<4;values.focusMinutes=variant%2?50:25;
  const unsigned remaining=variant>=4?static_cast<unsigned>(variant-4):20;
  const auto scene=idle?demo::Scene::home:complete?demo::Scene::complete:demo::Scene::focus;
  const auto key=idle?"idle-"+std::to_string(values.focusMinutes):complete?"complete-"+std::to_string(values.focusMinutes):"focus-"+std::to_string(remaining);
  Commands c(std::string(argv[1])+"/"+(station?"station-":"orbit-")+key+".json");
  demo::Frame f{scene,0,20000,static_cast<std::uint16_t>((20-remaining)*50),remaining,&values};
  if(station){demo::StationPainter painter("WEB DEMO",false);painter.render(c,f,true);}else{demo::Painter painter(demo::Device::orbit);painter.render(c,f,true);}
 }
}
