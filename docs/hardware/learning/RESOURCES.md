# Nudge 嵌入式專注裝置 Resources

## Knowledge

- [Espressif: ESP32-S3 Datasheet](https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf)
  MCU、GPIO、3.3V 邏輯、記憶體與 BLE 的第一手規格。用於：判斷腳位、電壓與控制器能力。
- [Seeed: XIAO ESP32-S3 Getting Started](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/)
  XIAO 板級接腳、燒錄與啟動模式。用於：第一次連線、燒錄失敗與 boot/reset 操作。
- [Seeed: Round Display for XIAO Usage](https://wiki.seeedstudio.com/seeedstudio_round_display_usage/)
  圓屏 SPI、I2C 與 D0–D10 佔用。用於：接線前確認哪個 GPIO 還可使用。
- [SparkFun: Qwiic Connect System](https://www.sparkfun.com/qwiic)
  Qwiic 的 3.3V、JST-SH 與 I2C 菊鏈概念。用於：理解旋鈕、光感與蜂鳴器為何能共用兩條資料線。
- [Adafruit: I2C QT Rotary Encoder Guide](https://learn.adafruit.com/adafruit-i2c-qt-rotary-encoder)
  PID 5880 旋鈕與按鍵的官方接線及測試。用於：單模組 bring-up。
- [Adafruit: NeoPixel Überguide](https://learn.adafruit.com/adafruit-neopixel-uberguide/basic-connections)
  5V LED、共地、資料電阻、去耦與 3.3V 位準轉換。用於：安全接 WS2813。
- [PlatformIO: Core CLI](https://docs.platformio.org/en/latest/core/index.html)
  專案編譯、上傳、序列監看與套件管理。用於：重現本專案韌體建置。
- [Bluetooth SIG: GATT Overview](https://www.bluetooth.com/specifications/specs/gatt-specification-supplement-6/)
  BLE service、characteristic、read/write/notify 的規範背景。用於：理解 App 與裝置不是在「傳普通網路封包」。
- [專案：原廠整合研究](../2026-08-21-official-integration-research.md)
  本機所選零件、I2C 位址、電源與尚待實機驗證事項。用於：避免用泛用教學取代本機規格。

## Wisdom (Communities)

- [PlatformIO Community](https://community.platformio.org/)
  有完整編譯輸出、板型與 library 版本時再提問；適合處理可重現的工具鏈問題。
- [Seeed Studio Forum](https://forum.seeedstudio.com/)
  適合詢問 Round Display 版次、D6 背光 PWM 與 XIAO 實物差異。
- 校內電子／嵌入式實驗室助教
  用於第一次焊接、短路檢查、示波器觀察與電源異常；實物安全問題優先找現場人員。

## Gaps

- Round Display 不同實物版次的 D6 PWM 穩定性只能到貨後量測。
- 多個 Qwiic 模組並聯後的實際上拉電阻與訊號品質只能在完整線長確定後量測。
