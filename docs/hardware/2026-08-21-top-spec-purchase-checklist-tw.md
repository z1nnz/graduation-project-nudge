# Nudge 最高規格實機：台灣優先採購清單

查核日期：2026-08-21（Asia/Taipei）
預算：成品零件、基本耗材、外殼與合理運費合計控制在 NT$5,000 內；工具為可重複使用資產，建議先向學校實驗室借用，不列入單台成本。

> 本清單只有一套主方案。請依「精確品名／料號」下單，不要自行換成 XIAO ESP32-S3 Sense、WS2812、一般雙向電平轉換板或 5V 旋鈕。價格與庫存是查核當下快照，結帳前仍須看頁面與運費。

## 1. 直接下單：主機與互動模組

| 勾選 | 數量 | 精確商品與連結 | 2026-08-21 頁面狀態 | 用途／不可買錯之處 |
|---|---:|---|---|---|
| [ ] | 1 | [Seeed Studio Round Display for XIAO，SKU 104030087（物聯汪汪／iOPEN Mall）](https://mall.iopenmall.tw/005107/index.php?action=product_detail&prod_no=P0510700650775) | 台灣境內預購，NT$630 含稅，可結帳；下單前先問實際交期 | 1.28 吋 240×240 圓屏。主選螢幕，不能用不同 PCB 尺寸直接代替外殼孔位。若交期無法接受，才用[ Seeed 原廠海外備援](https://www.seeedstudio.com/1-28-Round-Touch-Display-for-Seeed-Studio-XIAO-p-5638.html)。 |
| [ ] | 1 | [Seeed Studio XIAO ESP32-S3，貨號 113991114（TaiwanIOT）](https://www.taiwaniot.com.tw/product/seeed-studio-xiao-esp32s3-%E9%96%8B%E7%99%BC%E6%9D%BF/) | NT$300 未稅、尚有庫存；下單時加選「焊接針腳」NT$42 未稅 | 微控制器、BLE 與韌體主機。買普通 S3，**不要買 Sense 版**。一定加購焊針，才能穩定插入圓屏。 |
| [ ] | 1 | [Adafruit I2C STEMMA QT Rotary Encoder Breakout with Encoder，PID 5880（DigiKey Taiwan）](https://www.digikey.tw/zh/products/detail/adafruit-industries-llc/5880/22596384) | NT$292；查核頁面顯示 563 件 | I2C 可按壓旋鈕，預設位址 0x36。請確認是含已焊旋鈕的 PID 5880。 |
| [ ] | 1 | [Adafruit Slim Rubber Rotary Encoder Knob，PID 5093（DigiKey Taiwan）](https://www.digikey.tw/zh/products/detail/adafruit-industries-llc/5093/14652773) | 約 NT$28；與旋鈕同單 | 適配 6 mm D 軸的旋鈕帽。 |
| [ ] | 1 | [SparkFun Qwiic Buzzer，BOB-24474（TaiwanIOT）](https://www.taiwaniot.com.tw/product/sparkfun%E7%BE%8E%E5%9C%8B%E8%A3%BD-qwiic-buzzer-%E8%9C%82%E9%B3%B4%E5%99%A8-i2c%E5%82%B3%E8%BC%B8/) | 查核頁面 NT$300 未稅、尚有庫存 | 3.3V、I2C 0x34，提供開始／暫停／完成短提示音；不是喇叭，不能播語音。 |
| [ ] | 1 | [SparkFun Ambient Light Sensor VEML7700 Qwiic，SEN-29211（TaiwanIOT）](https://www.taiwaniot.com.tw/product/sparkfun-ambient-light-sensor-veml7700-qwiic/) | NT$300 未稅、尚有庫存 | 3.3V、I2C 0x10，自動調整螢幕與 LED 亮度；外殼必須留採光窗。 |

## 2. 直接下單：燈光、電氣保護與配線

| 勾選 | 數量 | 精確商品與連結 | 查核狀態／預算 | 用途／不可省略之處 |
|---|---:|---|---|---|
| [ ] | 1 | [Grove RGB LED Stick，10 × WS2813 Mini，SKU 104020131（DigiKey Taiwan）](https://www.digikey.tw/en/products/detail/seeed-technology-co-ltd/104020131/10451878) | NT$193；查核頁面顯示 239 件 | 展示級柔光進度條。5V 供電、D2 資料；本版不使用 microSD。 |
| [ ] | 2 | [Texas Instruments SN74AHCT125N，14-PDIP，DigiKey 296-4655-5-ND](https://www.digikey.tw/zh/products/detail/texas-instruments/SN74AHCT125N/375798) | 約 NT$34／顆；第二顆是備品 | 把 ESP32 的 3.3V LED 資料正式轉成 5V。**最高規格版不可省略，也不要改買慢速 BSS138 雙向 I2C 轉換板。** |
| [ ] | 1 | [Qwiic Cable Kit，KIT-15081（TaiwanIOT）](https://www.taiwaniot.com.tw/product/qwiic-cable-kit-%E9%80%A3%E6%8E%A5%E7%B7%9A%E5%A5%97%E4%BB%B6-sparkfun%E5%8E%9F%E5%BB%A0/) | NT$300 未稅、尚有庫存 | 內含多種長度及 Qwiic 轉公／母杜邦線，用來串接旋鈕、光感與蜂鳴器。買此套後不必再買單條 Qwiic 線。 |
| [ ] | 1 包 | [Grove Universal 4-pin 20 cm cable，5 條包裝，SKU 110990031（TaiwanIOT）](https://www.taiwaniot.com.tw/product/grove-4pin-20cm-%E7%84%A1%E6%89%A3%E6%AF%8D%E5%B0%8D%E6%AF%8D%E9%80%A3%E6%8E%A5%E7%B7%9A-5%E6%A2%9D%EF%BC%89/) | NT$100 未稅、尚有庫存 | LED Stick 的 5V、GND、DIN 配線；必要時剪一條做尾線。 |
| [ ] | 1 | [830 孔麵包板與杜邦線分類（傑森創工）](https://www.jmaker.com.tw/collections/%E6%9D%9C%E9%82%A6%E7%B7%9A-%E9%BA%B5%E5%8C%85%E7%B7%9A-%E6%8E%92%E9%87%9D-%E9%BA%B5%E5%8C%85%E6%9D%BF) | 830 孔約 NT$60–80；另買公對公跳線一組 | 到貨後先做免焊原型，不要第一天就把所有零件焊死。 |
| [ ] | 1 | [9 × 15 cm 2.54 mm 洞洞板（傑森創工）](https://www.jmaker.com.tw/products/product453) | NT$15 | 裸板驗證全過後才裁切、焊成展示機內部配線板。 |
| [ ] | 各 2–5 | 0.1 µF 陶瓷電容、1000 µF／6.3V 以上電解電容、330–470 Ω 電阻、24–28 AWG 線、熱縮套管 | 在地電子材料行購買，預留 NT$150–250 | 0.1 µF 放在 AHCT 電源旁；大電容放在 LED 5V 入口；資料線串 330–470 Ω。電解電容有極性，不能接反。 |

## 3. 直接下單：供電與機構

| 勾選 | 數量 | 精確商品與連結 | 查核狀態／預算 | 用途 |
|---|---:|---|---|---|
| [ ] | 1 | [USB-A to USB-C 1 m 資料傳輸線（傑森創工）](https://www.jmaker.com.tw/products/type-c%E8%BD%89%E8%BC%B8%E7%B7%9A-%E5%8F%AF%E7%94%A8%E6%96%BC%E5%90%84%E6%AC%BEtype-c%E7%9A%84%E9%96%8B%E7%99%BC%E6%9D%BF) | NT$45、可加入購物車；頁面明示可上傳開發板程式 | 燒錄與供電。若已有確認能傳資料的線可不買；只有充電功能的線不能燒錄。 |
| [ ] | 1 | [Toshiba 5V／2A USB-A 電源（傑森創工）](https://www.jmaker.com.tw/products/product336) | NT$120、可加入購物車 | 展示時的穩定桌上供電；第一版不裝鋰電池。 |
| [ ] | 1 組 | [PLAB 台灣 PLA 代客 3D 列印](https://www.plab.com.tw/service/category/3d-printing-services) | NT$150／小時、最低 NT$500；實際依 STL 報價 | 不透明主殼＋乳白半透明導光件；先印便宜試裝殼，再印展示殼。預算抓 NT$800–1,200。 |
| [ ] | 1 批 | M2 螺絲、M2 熱熔銅柱／尼龍柱、薄泡棉膠、束線帶 | 五金行／電子材料行，預留 NT$100–150 | 可維修固定；不要用熱熔膠把所有板件永久封死。 |

## 4. 建議借用；沒有才購買的工具

這些不是裝進機器裡的單台成本。優先向學校實驗室或組員借，避免工具把 NT$5,000 產品預算吃掉。

| 工具 | 最低需求 | 參考連結 |
|---|---|---|
| 數位萬用電表 | 必須有 DC 電壓、電阻與通斷蜂鳴；上電前檢查 5V／3.3V／GND 是否短路 | [DT9205A 基本款（傑森創工，查核 NT$240）](https://www.jmaker.com.tw/products/product366)；想長期使用可買 [HT118A 自動量程款（查核 NT$885）](https://www.jmaker.com.tw/products/ht118a-%E5%B0%88%E6%A5%AD%E5%85%A8%E5%8A%9F%E8%83%BD%E9%9B%BB%E8%A1%A8-%E8%90%AC%E7%94%A8%E8%A1%A8-%E8%A1%A8%E9%87%9D%E6%8F%92%E4%BD%8D%E6%8F%90%E7%A4%BA-%E9%9B%99%E8%89%B2lcd-%E8%87%AA%E5%8B%95%E9%87%8F%E7%A8%8B-%E5%8F%AF%E6%B8%AC%E6%BA%AB%E5%BA%A6) |
| 可調溫烙鐵組 | 約 300–350°C、細烙鐵頭、烙鐵架、含助焊劑焊錫、吸錫帶／吸錫器 | 建議直接借學校電子實驗室的合格工具，不買無溫控 USB 小烙鐵。 |
| 斜口鉗、剝線鉗、尖嘴鉗 | 能處理 24–28 AWG 線 | 學校工具箱即可。 |
| 卡尺 | 0.1 mm 讀值即可 | 到貨後量 PCB、開孔、旋鈕與 USB 插頭，再定稿 STL。 |

## 5. 預算與下單拆單

| 訂單 | 建議一起買 | 預估 |
|---|---|---:|
| iOPEN Mall | Round Display | NT$630 + 運費 |
| TaiwanIOT | XIAO S3＋焊針、Buzzer、VEML7700、Qwiic Cable Kit、Grove 線 | 約 NT$1,400–1,500 含稅；頁面常有滿千運費條件，結帳確認 |
| DigiKey Taiwan | 旋鈕、旋鈕帽、WS2813 Stick、2 顆 SN74AHCT125N | 約 NT$580–650 + 國際小額訂單運費 |
| 傑森創工／材料行 | USB 線、5V/2A 電源、麵包板、跳線、洞洞板、電容／電阻／線材／固定件 | 約 NT$500–700 |
| 台灣 3D 列印 | 試裝殼＋展示殼／導光件 | 約 NT$800–1,200 |
| **預估落地總額** | 不含可借用工具 | **約 NT$4,200–4,900** |

## 6. 最安全的下單順序

1. 先訊息詢問 iOPEN 的 `104030087` 真實到貨日；可接受才下單。
2. 同日下 TaiwanIOT，XIAO 務必勾「焊接針腳」。
3. DigiKey 四類料件放同一單；不要漏掉 `SN74AHCT125N`。
4. 先買麵包板和測試線，**外殼先不要印**。
5. 裸板逐項驗收、量實際尺寸後，再把 STL 送印；這能避免花兩次完整外殼費。

## 7. 明確不要買

- XIAO ESP32-S3 **Sense**（多了相機／麥克風，且機構不同）。
- 一般 WS2812 裸板或 12／16 LED 大圓環（若換料，現有外殼、電源與驗收全要重做）。
- BSS138 類「四路雙向 I2C 電平轉換板」拿來驅動 WS2813（邊緣速度與用途不對）。
- KY-040 5V 旋鈕、一般 GPIO 蜂鳴器（圓屏已占用大量 GPIO）。
- 鋰電池、升壓板、相機、麥克風、CO2、IMU、溫濕度感測器（不屬於第一台桌上專注夥伴的驗收範圍）。
