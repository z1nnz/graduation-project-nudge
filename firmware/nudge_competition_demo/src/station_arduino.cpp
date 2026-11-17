#if defined(ARDUINO) && defined(NUDGE_DEVICE_STATION)
#include <Arduino.h>
#include <Adafruit_ST7789.h>
#include <SPI.h>
#include <memory>
#include <new>
#include "demo/station_arduino.h"
#include "demo/hardware_profile.h"
#include "demo/station.h"
namespace demo {
namespace {
template<class Surface>class AdafruitCanvas final:public Canvas {
 public:
  explicit AdafruitCanvas(Surface& s):s_(s){}
  void clear(std::uint16_t c)override{s_.fillScreen(c);}
  void rect(int x,int y,int w,int h,std::uint16_t c)override{s_.fillRect(x,y,w,h,c);}
  void line(int x,int y,int x2,int y2,std::uint16_t c)override{s_.drawLine(x,y,x2,y2,c);}
  void circle(int x,int y,int r,std::uint16_t c)override{s_.fillCircle(x,y,r,c);}
  void text(int x,int y,const char* v,int size,std::uint16_t c)override{s_.setTextSize(size);s_.setTextColor(c,color::background);s_.setCursor(x,y);s_.print(v);}
 private:Surface& s_;
};
class StationDisplay final:public DisplayPort {
 public:
  bool begin()override{
    const auto& p=hardwareProfile();
    if(const auto* error=lcdProfileError(p)){Serial.println(error);return false;}
    // Nothing above this line constructs SPI, touches a GPIO or initializes LCD.
    spi_.reset(new(std::nothrow)SPIClass(HSPI));if(!spi_)return false;
    spi_->begin(p.clock,-1,p.mosi,p.cs);
    screen_.reset(new(std::nothrow)Adafruit_ST7789(spi_.get(),p.cs,p.dc,p.reset));if(!screen_)return false;
    screen_->init(240,320,SPI_MODE0);screen_->setSPISpeed(16000000);screen_->setRotation(p.rotation);screen_->invertDisplay(p.invertColors);screen_->setTextWrap(false);
    ready_=screen_->width()==240 && screen_->height()==320;
    if(!ready_)return false;
    pinMode(p.backlight,OUTPUT);pwm_=ledcSetup(7,5000,8)>0;if(pwm_)ledcAttachPin(p.backlight,7);else Serial.println("backlight PWM unavailable; fixed ON");
    brightness(55);
    buffer_.reset(new(std::nothrow)GFXcanvas16(240,320));
    if(buffer_ && !buffer_->getBuffer())buffer_.reset();
    if(buffer_)buffer_->setTextWrap(false);
    Serial.println(buffer_?"station RGB565 buffer allocated":"station direct drawing fallback");
    Serial.println("ST7789 init issued; physical panel UNVERIFIED");return true;
  }
  void render(const Frame& f,bool entered)override{
    if(!ready_)return;
    if(entered && buffer_){AdafruitCanvas<GFXcanvas16> c(*buffer_);painter_.render(c,f,true);screen_->drawRGBBitmap(0,0,buffer_->getBuffer(),240,320);}
    else{AdafruitCanvas<Adafruit_ST7789> c(*screen_);painter_.render(c,f,entered);}
  }
  void showFatal(const char* code)override{Serial.println(code);}
  void brightness(unsigned percent){
    if(!ready_ || percent==brightness_)return;
    brightness_=percent>80?80:percent<30?30:percent;
    if(pwm_)ledcWrite(7,brightness_*255/100);else digitalWrite(hardwareProfile().backlight,HIGH);
  }
  void diagnostic(unsigned mode,std::uint32_t now){
    if(!ready_)return;
    if(mode==1){const int index=(now/2000U)%5U;if(index!=color_){const std::uint16_t colors[]={0xF800,0x07E0,0x001F,0,0xFFFF};screen_->fillScreen(colors[index]);color_=index;Serial.printf("station color %d UNVERIFIED\n",index);}}
    else if(mode==2 && !calibrated_){AdafruitCanvas<Adafruit_ST7789> c(*screen_);paintStationCalibration(c,hardwareProfile().rotation);calibrated_=true;}
  }
 private:
  bool ready_=false,pwm_=false,calibrated_=false;
  unsigned brightness_=0;
  int color_=-1;
  std::unique_ptr<SPIClass> spi_;
  std::unique_ptr<Adafruit_ST7789> screen_;
  std::unique_ptr<GFXcanvas16> buffer_;
  StationPainter painter_{NUDGE_BUILD_ID};
} display;
}
DisplayPort& stationDisplay(){return display;}
void stationDiagnostics(unsigned mode,std::uint32_t now){display.diagnostic(mode,now);}
void setStationBrightness(unsigned percent){display.brightness(percent);}
}
#endif
