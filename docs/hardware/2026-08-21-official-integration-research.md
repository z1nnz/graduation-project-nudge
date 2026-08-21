# Nudge 高規格實體裝置：原廠整合依據

查核日期：2026-08-21（Asia/Taipei）
範圍：只查原廠文件、原廠程式庫與元件資料；不查價格或庫存。

## 已確認的匯流排配置

| 裝置 | 供電／邏輯 | 預設 I2C 位址 | 韌體介面與實作結論 |
| --- | --- | --- | --- |
| SparkFun Qwiic Buzzer BOB-24474 | 原廠建議乾淨的 3.3V，I2C 邏輯也是 3.3V；最大音量約會取用 95mA | `0x34`，可由軟體變更 | 使用 `SparkFun_Qwiic_Buzzer_Arduino_Library.h`、`QwiicBuzzer::begin()`、`configureBuzzer(frequency, duration, volume)`；也有 `on()`、`off()` 與 `playSoundEffect()`。裝置缺席時要降級為靜音，不能像原廠範例一樣讓主程式永久停住。[硬體說明](https://docs.sparkfun.com/SparkFun_Qwiic_Buzzer/hardware_overview/) · [Arduino 程式庫與 API](https://docs.sparkfun.com/SparkFun_Qwiic_Buzzer_Arduino_Library/) |
| SparkFun VEML7700 Ambient Light Sensor | Qwiic 為 3.3V；晶片供電範圍 2.5–3.6V；量測時最大約 45µA@3.3V | `0x10` | v2 程式庫使用 `SparkFun_VEML7700_Arduino_Library.h`、`SparkFunVEML7700::begin()` 及 `getLux()`。v2 與早期 v1 並非完全相容，所以 PlatformIO 必須固定經實際編譯驗證的 v2 版本。感測器缺席或讀值錯誤時保留安全預設亮度。[硬體說明](https://docs.sparkfun.com/SparkFun_Ambient_Light_Sensor-VEML7700/hardware_overview/) · [v2 程式庫](https://github.com/sparkfun/SparkFun_VEML7700_Arduino_Library) · [類別 API](https://docs.sparkfun.com/SparkFun_VEML7700_Arduino_Library/class_spark_fun_v_e_m_l7700.html) |
| Adafruit I2C QT Rotary Encoder PID 5880 | `VIN` 可接 3–5V；SDA/SCL 有位準轉換，可配合 3–5V 邏輯 | `0x36`；A0/A1/A2 可改到 `0x37`–`0x3D` | Arduino 使用 `Adafruit_seesaw`：`begin(0x36)`、`getEncoderPosition()` 或 `getEncoderDelta()`。按鍵是 seesaw pin `24`，設為 `INPUT_PULLUP` 後以低電位判斷按下；必須做軟體去彈跳。可檢查產品韌體 ID `4991`，但檢查失敗時應回報硬體錯誤，而非鎖死整台裝置。[Adafruit 原廠指南](https://cdn-learn.adafruit.com/downloads/pdf/adafruit-i2c-qt-rotary-encoder.pdf) · [Arduino 官方範例](https://github.com/adafruit/Adafruit_Seesaw/blob/master/examples/encoder/encoder_basic/encoder_basic.ino) |

上述三個位址 `0x10`、`0x34`、`0x36` 不衝突，可共用 Round Display 的 D4/SDA 與 D5/SCL。Round Display 的觸控本身也在這條 I2C 匯流排上；Seeed 原始碼定義其位址為 `0x2e`。[Seeed Round Display 原始碼](https://github.com/Seeed-Studio/Seeed_Arduino_RoundDisplay/blob/main/src/lv_xiao_round_screen.h)

## Round Display for XIAO 接腳與電源限制

Seeed 原廠資料確認的占用如下：

| XIAO 接腳 | Round Display 用途 | Nudge 限制 |
| --- | --- | --- |
| D0/A0 | 電池電壓讀取 | 不另接周邊；只有新版 KE 功能開關接通時才連到量測電路。 |
| D1 | LCD CS | 專用。 |
| D2 | microSD CS | Nudge 若拿來驅動外部 LED，就必須停用 microSD 且不可插卡。 |
| D3 | LCD DC | 專用。 |
| D4 / D5 | SDA / SCL；觸控與 RTC 共用 | Qwiic 感測器、蜂鳴器與旋鈕共用這一組。 |
| D6 | 螢幕背光 | 新版板子的 KE 功能開關必須接通，背光控制才會連到 D6。 |
| D7 | 觸控中斷 | 專用。 |
| D8 / D9 / D10 | SPI SCK / MISO / MOSI | LCD 與 microSD 共用，不另接周邊。 |

Round Display 原廠規格列出 USB Type-C 5V/35mA、3.7V 電池模式 37mA、約 485mA 充電電流；這些是圓屏擴充板規格，不能當成 XIAO、LED、蜂鳴器與全部周邊的整機功耗。圓屏支援 3.7V 鋰電池並可經 XIAO USB 充電，但此原型先以穩定 USB 供電驗收，避免把電池安全、充電與續航混入第一輪裝置 E2E。圓屏主電源開關在直接由 XIAO 供電時不能切斷 XIAO；只有透過圓屏上的電池供電時才控制整機。[Seeed 入門規格](https://wiki.seeedstudio.com/get_start_round_display/) · [Seeed 硬體使用說明](https://wiki.seeedstudio.com/seeedstudio_round_display_usage/)

Seeed 的 Round Display 程式庫把背光定義為 D6，初始化時只做 `digitalWrite(D6, HIGH)`。原廠文件沒有承諾 ESP32-S3 上以 PWM 調光的有效頻率、線性或最低穩定占空比。因此環境光自動調光可在顯示初始化後對 D6 使用 ESP32 LEDC/PWM，但必須列為實機驗證項目，並保留「只開／關」的降級模式。[Seeed Round Display 顯示驅動](https://github.com/Seeed-Studio/Seeed_Arduino_RoundDisplay/blob/main/src/lv_xiao_round_screen.h)

## Grove 10×WS2813 Mini LED 棒

Seeed 原廠模組頁確認：10 顆 WS2813 Mini、單一數位訊號、模組標示可在 3.3V 或 5V 運作；每一 RGB channel 標示為 16mA，並明確警告不支援熱插拔。依規格推算，10 顆全白的理論通道上限是 `10 × 3 × 16mA = 480mA`，實際值仍須量測。[Seeed Grove LED Stick 官方 Wiki](https://wiki.seeedstudio.com/Grove-RGB_LED_Stick-10-WS2813_Mini/)

但 Seeed 同頁提供的 Worldsemi WS2813-Mini 資料表把典型 VDD 條件列為 4.5–5.5V，且 `VIH(min) = 0.7 × VDD`；在 5V 供電下，高電位門檻就是 3.5V。這表示 ESP32-S3 的 3.3V data 並不是 5V LED 供電時的規格保證。模組頁的「3.3V/5V operating voltage」與晶片資料表之間存在張力，不能把它延伸解讀成「3.3V data 驅動 5V LED 保證相容」。[Seeed 提供的 WS2813-Mini 資料表](https://files.seeedstudio.com/wiki/Grove-RGB_LED_Stick-10-WS2813_Mini/res/WS2813-Mini.pdf)

因此高規格原型採以下安全邊界：

1. LED 棒由獨立的 5V 電源支路供電，與 XIAO 共地；不從 XIAO 的 3.3V 腳拉取 LED 大電流。
2. ESP32-S3 的 3.3V data 經 74AHCT125／74HCT 系列轉為 5V 邏輯後再進 LED `SIG`。
3. 韌體限制全域亮度與最大同時點亮強度；上電、斷電與重新插接都先停止輸出，不做熱插拔。
4. D2 只有在 microSD 完全停用、未插卡時才能作為 LED data；否則要重新配置可用 GPIO／外接 GPIO 擴充方案。

## I2C 與電源的整機風險

- Qwiic Buzzer 與 VEML7700 各自帶有 2.2kΩ SDA/SCL pull-up，Encoder 指南標示 10kΩ pull-up，Round Display 上又已有觸控與 RTC。多組 pull-up 並聯可能過強。SparkFun 對 Buzzer 的原廠建議是多裝置時只保留一組 pull-up；實機組裝前應量測等效電阻並依板上 jumper 移除多餘 pull-up，不能直接把所有 jumper 原封不動串上。
- Buzzer 最大音量約 95mA，不能只依「Qwiic 插得上」推定 XIAO／圓屏 3.3V rail 一定有足夠餘量。初次驗收先用低音量短 cue，量測 3.3V rail、總電流與 ESP32 重啟情形；若壓降或重啟，改用獨立、乾淨的 3.3V regulator 並共地。
- VEML7700 要從外殼獨立透光孔讀環境光，不能直視 LED 導光條或螢幕背光，否則會形成「自己變亮→感測更亮→自己變暗」的回授。韌體還要使用平滑、遲滯、亮度上下限與感測器失效 fallback。

## 韌體實作前的硬性驗收

1. I2C 掃描可同時看到 `0x10`、`0x34`、`0x36`，以及圓屏既有周邊；任何選配裝置缺席時核心專注計時仍能啟動。
2. 旋鈕正反轉、按下、長按皆通過去彈跳測試；重開機後選取狀態可恢復。
3. VEML7700 以遮光、室內、強光三段測試，亮度變化平滑且不閃爍；D6 PWM 若不穩定，自動降級為門檻式開／關。
4. Buzzer 的提示都使用短 cue、音量上限與安靜模式；連續運作不讓 3.3V rail 壓降、不使 ESP32 重啟。
5. LED 以 5V + 邏輯位準轉換器測試，示波器／邏輯分析儀或至少長時間壓力測試確認資料穩定；禁止熱插拔。
6. 全白最大亮度、蜂鳴器最大允許音量與螢幕高亮三者同時運作時，量測 5V 輸入總電流、3.3V rail 與溫升，再決定正式韌體上限。

## 仍待實機確認

- D6 背光在此批 Round Display 硬體上的 PWM 線性、可用頻率與最低穩定亮度。
- XIAO ESP32-S3 + Round Display 的 3.3V rail 在蜂鳴器與全部 I2C 模組同時運作時的餘量。
- 所購買 Grove LED Stick 批次在 5V 供電時的資料輸入門檻；在完成測量前，5V 位準轉換器不可省略。
- 多塊 Qwiic 板並聯後的總 pull-up 與 400kHz 匯流排品質；若品質不穩，先降到 100kHz 並調整 pull-up。
