#include "demo/ble_protocol.h"
#include "demo/generated_contract.h"
#include <cstdio>
namespace demo {
namespace {
class Reader {
 public:
  Reader(const char* p,std::size_t n):p_(p),end_(p+n){}
  void ws(){while(p_!=end_ && (*p_==' '||*p_=='\r'||*p_=='\n'||*p_=='\t'))++p_;}
  bool token(char c){ws();if(p_==end_||*p_!=c)return false;++p_;return true;}
  bool word(std::string& s){
    if (!token('"')) return false;
    s.clear();
    while(p_!=end_ && *p_!='"'){if(*p_<' '||*p_>'~'||*p_=='\\'||s.size()>=16)return false;s+=*p_++;}
    return token('"');
  }
  bool done(){ws();return p_==end_;}
 private:const char* p_;const char* end_;
};
}
Command parseDemoCommand(const char* bytes,std::size_t size,bool enabled){
  if(!enabled||!bytes||!size||size>96)return Command::none;
  Reader r(bytes,size);if(!r.token('{'))return Command::none;
  unsigned seen=0;Command action=Command::none;
  for(int i=0;i<3;++i){
    std::string key,value;if(!r.word(key)||!r.token(':'))return Command::none;
    unsigned bit=0;
    if(key=="v"){bit=1;if(!r.token('1'))return Command::none;}
    else if(key=="type"){bit=2;if(!r.word(value)||value!="demo")return Command::none;}
    else if(key=="action"){
      bit=4;if(!r.word(value))return Command::none;
      if(value=="next")action=Command::next;else if(value=="restart")action=Command::restart;else if(value=="startFocus")action=Command::start;else return Command::none;
    }else return Command::none;
    if (seen & bit) return Command::none;
    seen |= bit;
    if(!r.token(i==2?'}':','))return Command::none;
  }
  return seen==7&&r.done()?action:Command::none;
}
std::string encodeDemoState(Device device,Scene scene){
  const unsigned id=static_cast<unsigned>(scene);if(id>7)return {};
  char out[96];std::snprintf(out,sizeof(out),"{\"v\":1,\"mode\":\"demo\",\"device\":\"%s\",\"scene\":\"%s\",\"index\":%u}",device==Device::orbit?"orbit":"station",contract::kScenes[id],id);return out;
}
}
