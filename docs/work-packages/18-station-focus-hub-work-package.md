# 18｜Nudge Station 方形桌上專注中樞完整開發工作包

## 執行方式

Station 周邊較多，必須「一個子系統一次」：電源 → serial → 方屏 → I²C → 旋鈕 →
光感 → LED → buzzer → 共用核心 → BLE。全部一次接上再除錯，無法知道哪個 rail、
address、pin 或 driver 造成失敗。

## Phase 0｜方形硬體身分與電源設計

### 做什麼

- 完成 ESP32 和方形螢幕 identity card，確認 driver/interface/pin/logic/backlight。
- 建立 pin budget：display、touch/SD、I²C、LED data、boot-strapping pin、USB/JTAG。
- 畫電源方塊圖：USB 5V、3.3V regulator、LED 5V、common ground、level shifter。
- 每個周邊標註供電、logic、address、peak current、pull-up。
- 先在麵包板／可靠接線測試，不焊死到洞洞板。

### 為什麼

方屏型號未知是最大風險；不同 driver 和板型可能使用完全不同介面。5V LED 的
data threshold、ESP32 strapping pin 和 backlight 電流若猜錯，可能不只是黑屏，還
可能造成不開機或損壞。

### Exit gate

- [ ] pin budget 沒有衝突，D2/microSD 等共享用途有明確決策。
- [ ] 上電前 continuity/short check 通過。
- [ ] level shifter、共地、去耦和電源支路畫入原理圖。

## Phase 1｜ESP32 serial baseline

和 Orbit Phase 1 相同：只測 USB、boot、reset reason、heartbeat。建立 Station 專屬
PlatformIO env，firmware log 包含 `hardwareProfile=station_square_v1`。

### Exit gate

- [ ] 冷插拔 10 次、reset 10 次、heartbeat 20 秒無異常。
- [ ] 不接任何周邊也可正常 boot。

## Phase 2｜方屏獨立 smoke

### 做什麼

- 使用 Gate 0 確認的官方 driver/pin，不抄圓屏設定。
- 背光與 pixel path 分開測試；serial marker 覆蓋 SPI/parallel init 每一步。
- 顯示紅綠藍白黑、棋盤、四角編號、rotation、文字、長字截斷。
- 若含 touch，再獨立做座標校正；不把 touch 當 display 成功條件。

### Exit gate

- [ ] 10 次冷開機和 30 分鐘畫面壓力測試。
- [ ] resolution、color order、rotation、refresh limit 寫入 Adapter config。
- [ ] 可由另一位組員重現。

## Phase 3｜I²C bus bring-up

### 做什麼

1. 只接 encoder，掃到 `0x36`。
2. 再接 VEML7700，掃到 `0x10`。
3. 再接 buzzer，掃到 `0x34`。
4. 量測 SDA/SCL idle voltage 和 pull-up 等效阻值；必要時依原廠 jumper 移除多餘
   pull-up。
5. 每拔掉一個周邊，核心 boot/display 仍正常。

### 原理與目的

I²C 用兩條 shared bus 加 address 區分裝置；address 不衝突不代表電氣一定健康。
並聯過多 pull-up 會讓匯流排負載變重，所以要量測而不是只看 scanner。

### Exit gate

- [ ] 三 address 同時穩定掃到 100 次，沒有 bus lock。
- [ ] 任一 optional sensor 缺席只產生 fault/capability 變化，不 crash。

## Phase 4｜旋鈕 Input Adapter

### 做什麼

- 讀 raw position/switch，實作 delta、debounce、短按、長按、按住不重複。
- 將 `InputEvent` 放進 queue，由 core 依當前 phase 解讀；ISR/I²C callback 不直接改
  FocusSession。
- ready 時旋轉選 personal/allowed room；active 時旋轉預設不改 room。

### 測試

- 左右各 500 detents、快速旋轉、按住旋轉、bounce、I²C 暫時失敗。
- configure race：App 等 Cloud correlation 時轉動，dispatch 前凍結最新選擇。

### Exit gate

- [ ] 無重複 lifecycle、無越界 room、無 callback race。

## Phase 5｜環境光與亮度 Adapter

### 做什麼

- dark/indoor/bright 三段量測，建立 raw lux baseline。
- 1 秒採樣、EWMA、hysteresis、min/max；輸出 display/LED brightness frame。
- sensor timeout/outlier 使用固定安全 fallback，不自動停活動。
- 外殼採光窗完成後重校，因外殼會改變 lux。

### Exit gate

- [ ] 手遮 1 秒不造成亮度閃爍；持續環境改變在合理時間平滑調整。
- [ ] sensor 拔除／I²C 錯誤可繼續計時。

## Phase 6｜LED 電氣與 Indicator Adapter

### 做什麼

- 5V rail 供 LED，ESP32 data 經 74AHCT/HCT level shifter，共地。
- 先一顆／低亮，再全 10 顆；量測 idle、全白限制亮度和動畫 peak current。
- 實作 offline/ready/active/paused/complete/rest 和 progress；不使用高頻刺眼閃爍。
- 導光件裝上後調整 gamma/brightness，不以裸燈效果作最終設定。

### Exit gate

- [ ] 30 分鐘 worst-case animation 無 data corruption、過熱、brownout。
- [ ] 拔掉 LED，display/focus/BLE 仍可用。

## Phase 7｜Buzzer Adapter

### 做什麼

只保留 start/pause/resume/complete/error 的短 cue；quiet setting 和 quiet hours 優先。
非阻塞播放，不在 loop 中 delay；缺席或錯誤不影響 lifecycle。

### Exit gate

- [ ] App 關閉聲音後 exact context revision 生效。
- [ ] 100 次 cue 不阻塞 input/display/BLE。

## Phase 8｜Station 畫面與 common core

### 做什麼

- 實作 `StationDisplayAdapter`，只 render `PresentationFrame`。
- 接入 common lifecycle/context/journal/control lease。
- ready/active/paused/local-saved/waiting-app/cloud-accepted/rest/fault 狀態清楚。
- display、LED、buzzer 由同一 frame 衍生，避免三套 switch 各自分歧。

### Exit gate

- [ ] optional 周邊組合矩陣：全部有、各自缺席、display only。
- [ ] 20 次任意斷電後 phase/queue 一致。
- [ ] pending 與 Cloud accepted 不使用同一慶祝畫面。

## Phase 9｜BLE、App 與 Cloud E2E

### 做什麼

1. Web 指派 Station 與一個 allowed room。
2. App 讀 profile/capabilities，送 context exact revision。
3. 旋鈕選房，Cloud correlation + lease 後 configure。
4. start/pause/resume/complete；ACK 前斷線一次。
5. 重連後 durable enqueue、ACK、單一 Receipt/Reward/room contribution。
6. 再做 personal session，確認不自動散布到房間。
7. revoke assignment，既有連線在 command 前 fail closed。

### Exit gate

- [ ] App/Web/room/character 一致，event/correlation/Receipt 可追蹤。
- [ ] stale lease、wrong room、wrong user、wrong-head ACK 全被拒絕。

## Phase 10｜外殼、供電與長時間驗收

### 做什麼

- 紙板／3D 草模先驗證螢幕視角、旋鈕手感、導光、感測窗、聲孔和 USB。
- 焊接前保存 breadboard working baseline；洞洞板逐網 continuity check。
- 高亮 display + LED + buzzer + BLE + NVS 連續 2 小時；量測 5V、3.3V、溫升、reset。
- 24 小時 idle/定期連線 soak，記錄 reconnect、queue、memory 和 watchdog。

### Exit gate

- [ ] 無裸露短路風險、線材有應力釋放、外殼可維修。
- [ ] 另一位組員能依操作卡完成兩種 session 和故障恢復。

## 最終交付

- hardware identity、pin budget、原理圖、接線照、BOM revision。
- source、PlatformIO lock、firmware binary/hash、flash/recovery 指令。
- 每個 Phase 的 log、量測、照片／影片、測試結果和已知限制。
- App/Cloud E2E evidence、資料清理、rollback firmware。
- 只有同一 hardware revision + firmware + App commit 的組合可標 `device-verified`。
