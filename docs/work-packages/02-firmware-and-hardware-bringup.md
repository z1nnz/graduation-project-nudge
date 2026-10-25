# 02｜韌體與硬體 Bring-up 工作包

## 目標與完成定義

讓 Nudge Focus Companion 從「可編譯、可燒錄」前進到「每個硬體子系統都有可
重現證據」。本工作包完成時，另一位組員照同一套接線和指令，也能得到同樣的
螢幕、輸入、燈光、環境光與聲音結果。

成功燒錄只證明 USB、serial transport 與 MCU 執行，不能單獨證明背光、SPI、
GC9A01 rendering 或排針接觸正常。

## 已知硬體契約

| 子系統 | 介面／腳位 | 備註 |
| --- | --- | --- |
| Round Display GC9A01 | D8 SCLK、D9 MISO、D10 MOSI、D1 CS、D3 DC | 無獨立 reset |
| 背光 | D6 | 診斷先固定 HIGH，再測 PWM |
| I2C | D4 SDA、D5 SCL | Encoder `0x36`、Buzzer `0x34`、VEML7700 `0x10` |
| WS2813 LED stick | D2 經 74AHCT125/HCT | 5V 電源、共地、microSD 停用 |
| 主控 | XIAO ESP32-S3 | PlatformIO target `seeed_xiao_esp32s3` |

## 切片 A｜螢幕獨立診斷（P0）

### 要做什麼

建立或整理一個不含 BLE、NVS、I2C、LED、房間資料的最小顯示 probe。它必須在
每個硬體階段前後輸出唯一 serial marker，並循環顯示全螢幕紅、綠、藍、白、
黑及中央文字／十字線。

### 怎麼做

1. 先記錄 macOS 當次枚舉出的 `/dev/cu.usbmodem*`，不要硬編舊 port。
2. 開機第一行先輸出 `BOOT`，在初始化 SPI 前輸出 `SPI BEGIN`，完成 display
   init 後輸出 `DISPLAY READY`，每次換色輸出顏色名稱。
3. 診斷版先把 D6 固定 HIGH，關閉背光 PWM 變因。
4. 以低 SPI clock 跑一輪，再用正式 driver 設定跑一輪；兩輪都保留版本資訊。
5. 拍攝能同時對到 serial marker 與螢幕顏色的短影片或逐張照片。
6. 若無畫面，依序檢查供電、方向、排針接觸、D6、SPI、driver；不要直接判定
   面板壞掉。必要時用另一塊已知正常主控／面板交叉測試。

### 修改位置

- 獨立 probe 放在 `firmware/` 下自己的 PlatformIO project，不要把診斷碼永久
  混入正式狀態機。
- 正式成功後，只把必要的 pin、driver、頻率和背光策略帶回
  `firmware/nudge_focus_device/src/`。
- 把可重現結果記入 `docs/acceptance/`，不要只留在聊天或個人終端。

### 驗收

- [ ] 冷開機連續 10 次都有完整 marker，沒有 boot loop。
- [ ] 六種畫面肉眼可辨且填滿預期區域，十字線方向正確。
- [ ] 固定 HIGH 成功後再測 D6 PWM 低／中／高三檔。
- [ ] 失敗時記錄停在哪一個 marker，而不是只寫「沒亮」。

## 切片 B｜周邊分別驗收（P0）

### 執行順序

1. I2C scanner 同時看到 `0x10`、`0x34`、`0x36`。
2. 旋鈕左右轉與短按／長按分別輸出事件；去彈跳不重複觸發。
3. 遮光、一般室內、強光三段量測 VEML7700，驗證 EWMA 與 fallback。
4. 蜂鳴器只播放短 cue，靜音偏好立即生效，缺席時不阻擋計時。
5. LED 經 5V level shifter 顯示 offline、ready、active、paused、complete、rest。

### 電氣安全

- 禁止由 GPIO 或 3V3 rail 供應 LED 大電流。
- 所有模組與 5V 支路共地；禁止帶電熱插拔。
- 組裝後量測 USB 輸入和 3.3V rail；檢查 Qwiic pull-up 並聯後的等效阻值。
- 高亮螢幕、LED、蜂鳴器同時工作至少 30 分鐘，記錄溫升、重啟和 brownout。

### 驗收

- [ ] 拔掉任一可選 I2C 體驗元件，核心計時仍能啟動。
- [ ] 環境光失效時亮度回到安全固定值。
- [ ] LED 長時間運作無資料亂碼、過熱或主控重啟。
- [ ] microSD 停用且沒有插卡，避免和 D2 衝突。

## 切片 C｜正式韌體回整（P0）

### 要做什麼

把已證明的 driver 設定回整至 `firmware/nudge_focus_device`，保留 portable C++
狀態機與 Arduino Adapter 的邊界。顯示、感測器和音效失敗不可破壞事件 journal、
BLE queue 或專注計時。

### 必測行為

- configure、start、pause、resume、manual complete、timed complete。
- 暫停時間不計入正式專注時間。
- 事件 ID 為 `{deviceId}:{sessionId}:{eventType}:{sequence}`。
- sequence 與最多八筆未 ACK 事件跨斷電保存。
- 只有 queue head 的完全相符 ACK 能移除事件。
- context/quiet setting 必須 NVS 成功並回報相同 `contextRevision`。
- 當次 configure 凍結旋鈕最新選擇；沒有選房就是個人活動。

### 測試

```bash
make -C firmware/nudge_focus_device test
pio run --project-dir firmware/nudge_focus_device
pio run --project-dir firmware/nudge_focus_device --target upload
pio device monitor --baud 115200
```

## 給執行者的交付內容

- pin/driver/clock 的最終表格及 firmware commit hash。
- 每個子系統的 pass/fail 表，附原始 serial log。
- 接線正反面清楚照片、最小顯示影片、30 分鐘壓力測試結果。
- 未解假設與下一個可否證測試。
- 若更換螢幕或主控，保留原零件交叉測試結果，不能只寫「換掉就好了」。

## 不在本工作包

- 裝置 claim、簽章 OTA、Wi-Fi Cloud ingestion。
- 外殼美化先於供電和可靠性驗收。
- 直接讓韌體寫 Firestore、幣值、XP 或房間成果。
