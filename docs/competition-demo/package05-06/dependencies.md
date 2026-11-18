# 固定來源與資源紀錄

本輪 2026-11-17 查閱官方 repository，將依賴固定到下列 commit；不是追蹤浮動 master。
PlatformIO 平台 espressif32 6.12.0、Core 6.1.19，Seeed_GFX 沿用 #23。
相依版本／實際 RAM、Flash 與 compiler 訊息以 build log 為準。

| 套件 | 固定官方 source |
| --- | --- |
| Adafruit ST7735/ST7789 | [d568339](https://github.com/adafruit/Adafruit-ST7735-Library/tree/d568339f957380ceb05dda57f6712c2704a6394f) |
| Adafruit GFX | [f256ef6](https://github.com/adafruit/Adafruit-GFX-Library/tree/f256ef6b0f248711a0cd354be0da5ccd224808c3) |
| Adafruit BusIO | [3b83642](https://github.com/adafruit/Adafruit_BusIO/tree/3b8364267c3ee6e16bad91bc2101aefbd5b5915f) |
| Adafruit seesaw | [829c4ec](https://github.com/adafruit/Adafruit_Seesaw/tree/829c4ecc056b130d73394d88fa4bf7de2ccbed5d) |
| Adafruit NeoPixel | [56b9d7e](https://github.com/adafruit/Adafruit_NeoPixel/tree/56b9d7e435926eee5eef5e89ad30ea9b3eb7768b) |
| SparkFun VEML7700 | [1693613](https://github.com/sparkfun/SparkFun_VEML7700_Arduino_Library/tree/16936136f72ba14dc72dad936cc50d384dfc28db) |
| SparkFun Qwiic Buzzer | [b717328](https://github.com/sparkfun/SparkFun_Qwiic_Buzzer_Arduino_Library/tree/b7173282af4f18bf3c052f5f619cd80953d913fe) |
| Seeed_GFX | [0b13b21](https://github.com/Seeed-Studio/Seeed_GFX/tree/0b13b21f284c9bce3351b394bbd871b688d6aec7) |

Station 依據 [Waveshare SKU 17344](https://www.waveshare.com/2inch-LCD-Module.htm) 的 ST7789／240×320／SPI 身分，
採 [Adafruit 的 SPIClass adapter API](https://adafruit.github.io/Adafruit-ST7735-Library/html/class_adafruit___s_t7789.html) 移植。
外露 GPIO 數字對照依 [XIAO ESP32S3 原廠 pin map](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/#hardware-overview)；D 標示不等於 GPIO 數字。
這不是經 Waveshare 驗證的 XIAO 插接例；沒有挪用其 UNO pin map，也未把 driver begin 當 panel ACK。

自製角色、勾選、進度與格線都是程式幾何圖形，沒有外來圖片或生成式圖像。
字型是上游 GFX 的 Classic ASCII 字型，保留原始授權；SVG 只以 monospace 近似。
原始 libraries 不內嵌複製到本 repo；透過固定 source 可取得其原始碼與各檔案授權。
主要授權依據包括 [GFX license](https://github.com/adafruit/Adafruit-GFX-Library/blob/f256ef6b0f248711a0cd354be0da5ccd224808c3/license.txt)、
[BusIO LICENSE](https://github.com/adafruit/Adafruit_BusIO/blob/3b8364267c3ee6e16bad91bc2101aefbd5b5915f/LICENSE)、
[VEML7700 LICENSE](https://github.com/sparkfun/SparkFun_VEML7700_Arduino_Library/blob/16936136f72ba14dc72dad936cc50d384dfc28db/LICENSE.md)、
[Buzzer LICENSE](https://github.com/sparkfun/SparkFun_Qwiic_Buzzer_Arduino_Library/blob/b7173282af4f18bf3c052f5f619cd80953d913fe/LICENSE.md)，
其餘套件請保留上述固定 source 中的檔頭／授權說明。
