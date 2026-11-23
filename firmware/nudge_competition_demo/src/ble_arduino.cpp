#ifdef ARDUINO
#include <Arduino.h>
#include "demo/ble_arduino.h"
#include "demo/ble_protocol.h"
#include "demo/generated_contract.h"
#include "demo/hardware_profile.h"
#if NUDGE_BUILD_DEMO_BLE && NUDGE_DEMO
#include <BLEDevice.h>
#include <BLE2902.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <atomic>
namespace demo { namespace {
QueueHandle_t commands=nullptr;
BLECharacteristic* state=nullptr;
BLEServer* server=nullptr;
std::atomic<bool> connected{false},restartAdvertising{false};
class ServerCallbacks final:public BLEServerCallbacks {
  void onConnect(BLEServer*)override{if(commands)xQueueReset(commands);connected=true;}
  void onDisconnect(BLEServer*)override{connected=false;if(commands)xQueueReset(commands);restartAdvertising=true;}
} serverCallbacks;
class CommandCallbacks final:public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic)override{
    if(!connected||!commands)return;
    const auto value=characteristic->getValue();
    const auto command=parseDemoCommand(value.data(),value.size(),true);
    if(command!=Command::none)xQueueSend(commands,&command,0);  // Full queue drops input; never blocks the render task.
  }
} commandCallbacks;
}
void beginDemoBle(bool displayAvailable){
  if(!bleAllowed(hardwareProfile(),displayAvailable)){Serial.println("demo BLE gated OFF; offline autoplay");return;}
  if(ESP.getFreeHeap()<131072){Serial.println("demo BLE skipped: low heap; offline autoplay");return;}
  commands=xQueueCreate(4,sizeof(Command));if(!commands){Serial.println("demo BLE queue unavailable; offline autoplay");return;}
#ifdef NUDGE_DEVICE_ORBIT
  constexpr unsigned device=0;
#else
  constexpr unsigned device=1;
#endif
  BLEDevice::init(contract::kDeviceNames[device]);BLEDevice::setMTU(185);
  if(!BLEDevice::getInitialized()){vQueueDelete(commands);commands=nullptr;return;}
  server=BLEDevice::createServer();if(!server){vQueueDelete(commands);commands=nullptr;return;}
  server->setCallbacks(&serverCallbacks);
  auto* service=server->createService(contract::kServiceUuid);
  if(!service){Serial.println("demo BLE service unavailable; offline autoplay");return;}
  auto* command=service->createCharacteristic(contract::kCommandUuid,BLECharacteristic::PROPERTY_WRITE);
  if(!command)return;
  command->setCallbacks(&commandCallbacks);
  state=service->createCharacteristic(contract::kStateUuid,BLECharacteristic::PROPERTY_READ|BLECharacteristic::PROPERTY_NOTIFY);
  if(!state)return;
  state->addDescriptor(new BLE2902());
  const auto initial=encodeDemoState(device==0?Device::orbit:Device::station,Scene::boot);state->setValue(initial);
  service->start();auto* adv=BLEDevice::getAdvertising();if(!adv)return;
  // Explicit packets avoid the library default copying the UUID into the scan
  // response as well: UUID+full name together would exceed its 31-byte limit.
  BLEAdvertisementData packet,response;
  packet.setFlags(0x06);packet.setCompleteServices(BLEUUID(contract::kServiceUuid));
  response.setName(contract::kDeviceNames[device]);
  adv->setAdvertisementData(packet);adv->setScanResponseData(response);
  adv->setScanResponse(true);adv->start();Serial.println("demo BLE advertising; physical link UNVERIFIED");
}
Command takeDemoBleCommand(){
  if(restartAdvertising.exchange(false)&&server)server->startAdvertising();
  Command c=Command::none;if(commands&&connected)xQueueReceive(commands,&c,0);return c;
}
void publishDemoBle(const Frame& f){
  if(!state)return;
#ifdef NUDGE_DEVICE_ORBIT
  const auto payload=encodeDemoState(Device::orbit,f.scene);
#else
  const auto payload=encodeDemoState(Device::station,f.scene);
#endif
  static std::string previous;if(previous==payload)return;previous=payload;state->setValue(payload);if(connected)state->notify();
}
}
#else
namespace demo {
void beginDemoBle(bool){Serial.println("demo BLE compiled out; offline autoplay");}
Command takeDemoBleCommand(){return Command::none;}
void publishDemoBle(const Frame&){}
}
#endif
#endif
