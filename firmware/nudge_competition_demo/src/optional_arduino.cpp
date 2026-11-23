#ifdef ARDUINO
#include <Arduino.h>
#include "demo/optional_arduino.h"
#include "demo/hardware_profile.h"
#include "demo/peripherals.h"
#if NUDGE_BUILD_OPTIONALS
#include <Adafruit_NeoPixel.h>
#include <Adafruit_seesaw.h>
#include <SparkFun_VEML7700_Arduino_Library.h>
#include <SparkFun_Qwiic_Buzzer_Arduino_Library.h>
#include <Wire.h>
#endif
namespace demo {
namespace {
Command input=Command::none;
int rotation=0;
unsigned brightness=55;
bool muted=false;
void log(const char* name,const char* state){Serial.printf("optional %s %s\n",name,state);}
#if NUDGE_BUILD_OPTIONALS
const auto& p=hardwareProfile();
PeripheralGroup group;
bool busReady=false;
bool probe(std::uint8_t address){Wire.beginTransmission(address);return Wire.endTransmission()==0;}
class Button final:public OptionalPeripheral {
 public:
  const char* name()const override{return "button";}
  bool begin()override{
    if(!p.button || !optionalPinAllowed(p,p.buttonPin) || p.buttonPin==p.sda || p.buttonPin==p.scl)return false;
    pinMode(p.buttonPin,INPUT_PULLUP);return true;
  }
  bool update(const Frame&,std::uint32_t now)override{const auto c=press_.update(digitalRead(p.buttonPin)==LOW,now);if(c!=Command::none)input=c;return true;}
 private:DebouncedPress press_;
} button;
class Encoder final:public OptionalPeripheral {
 public:
  const char* name()const override{return "encoder";}
  bool begin()override{
#ifndef NUDGE_DEVICE_STATION
    return false;
#else
    if(!p.encoder || !busReady || !probe(0x36) || !device_.begin(0x36))return false;
    device_.pinMode(24,INPUT_PULLUP);previous_=device_.getEncoderPosition();return true;
#endif
  }
  bool update(const Frame& f,std::uint32_t now)override{
    if(now-last_<20U)return true;last_=now;
    if(!probe(0x36))return false;
    const auto position=device_.getEncoderPosition();
    int delta=0;const bool valid=encoderDelta(position,previous_,delta);previous_=position;
    if(!valid)return false;
    rotation=delta;
    const auto action=(f.scene==Scene::home || f.scene==Scene::ready)?Command::start:Command::next;
    const auto c=press_.update(!device_.digitalRead(24),now,action);if(c!=Command::none)input=c;
    return true;
  }
 private:Adafruit_seesaw device_;std::int32_t previous_=0;std::uint32_t last_=0;DebouncedPress press_;
} encoder;
class Led final:public OptionalPeripheral {
 public:
  const char* name()const override{return "led";}
  bool begin()override{
    if(!p.led || !p.ledSignalPathReady || !optionalPinAllowed(p,p.ledPin) || p.ledPin==p.sda || p.ledPin==p.scl || (p.button && p.ledPin==p.buttonPin))return false;
    pixels_.setPin(p.ledPin);pixels_.updateLength(10);pixels_.begin();pixels_.clear();pixels_.show();return true;
  }
  bool update(const Frame& f,std::uint32_t)override{
    const auto out=ledOutput(f);
    if(out.count==previous_.count && out.rgb==previous_.rgb && out.brightness==previous_.brightness)return true;
    pixels_.setBrightness(out.brightness);for(unsigned i=0;i<10;++i)pixels_.setPixelColor(i,i<out.count?out.rgb:0);pixels_.show();previous_=out;return true;
  }
 private:Adafruit_NeoPixel pixels_;LedOutput previous_{99,0,0};
} led;
class Light final:public OptionalPeripheral {
 public:
  const char* name()const override{return "light";}
  bool begin()override{return p.light && busReady && probe(0x10) && device_.begin();}
  bool update(const Frame&,std::uint32_t now)override{
    if(now-last_<1000U)return true;last_=now;
    float lux=-1;
    if(!probe(0x10) || device_.getLux(lux)!=ksfTkErrOk){brightness=55;return false;}
    brightness=model_.update(lux,true,now);return true;
  }
 private:SparkFunVEML7700 device_;ThreeLevelLight model_;std::uint32_t last_=0;
} light;
class Buzzer final:public OptionalPeripheral {
 public:
  const char* name()const override{return "buzzer";}
  bool begin()override{return p.buzzer && busReady && device_.begin() && device_.off()==ksfTkErrOk;}
  bool update(const Frame& f,std::uint32_t now)override{
    if(muted!=previousMute_){previousMute_=muted;model_.setMuted(muted);if(device_.off()!=ksfTkErrOk)return false;}
    const auto tone=model_.update(f,now);if(!tone.frequency)return true;
    return device_.configureBuzzer(tone.frequency,tone.durationMs,SFE_QWIIC_BUZZER_VOLUME_LOW)==ksfTkErrOk;
  }
 private:QwiicBuzzer device_;BuzzerPlan model_;bool previousMute_=false;
} buzzer;
#endif
}
void beginOptionals(bool displayAvailable) {
#if NUDGE_BUILD_OPTIONALS
  const bool allowed=p1Allowed(p,displayAvailable);
  // No Wire.begin, pinMode or device begin happens before ALL gates pass.
  if(allowed && (p.encoder || p.light || p.buzzer) && i2cPinsAllowed(p)){
    busReady=Wire.begin(p.sda,p.scl,100000);Wire.setTimeOut(20);
  }
  group.add(button);group.add(encoder);group.add(led);group.add(light);group.add(buzzer);group.begin(allowed,log);
#else
  (void)displayAvailable;log("button/encoder/led/light/buzzer","compiled out; autoplay continues");
#endif
}
void updateOptionals(const Frame& f,std::uint32_t now){
#if NUDGE_BUILD_OPTIONALS
  group.update(f,now);
#else
  (void)f;(void)now;
#endif
}
Command takeOptionalCommand(){const auto c=input;input=Command::none;return c;}
int takeOptionalRotation(){const int r=rotation;rotation=0;return r;}
unsigned optionalBrightness(){return brightness;}
void toggleOptionalMute(){muted=!muted;Serial.printf("optional mute %s\n",muted?"ON":"OFF");}
}
#endif
