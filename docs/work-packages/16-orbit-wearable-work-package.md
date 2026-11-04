# 16｜Nudge Orbit 圓形穿戴裝置完整開發工作包

## 執行方式

每個 Phase 是一個或數個小 PR；只有 Exit gate 通過才進下一階段。任何「看起來有
亮」都不能跳過 serial、冷開機與負向測試。組員須在 Issue 回填結果、照片、log、
firmware hash 和未驗證項目。

## Phase 0｜硬體身分與安全盤點

### 做什麼

- 建立 Orbit hardware identity card。
- 拍主控、圓屏、排針、USB、開關與接頭正反面照片。
- 核對 XIAO ESP32-S3、Round Display SKU/board revision、原廠 pin map。
- 用萬用電表做未上電短路／GND continuity；確認插入方向與排針密合。
- 記錄當次 serial port、VID/PID 和 PlatformIO board。

### 為什麼

同名模組可能有不同版次；方向、接觸、背光與 pin config 都可能造成「只亮白光／
局部亮」。先固定硬體身分，後續測試才可重現。

### Exit gate

- [ ] 身分卡完整且有官方文件。
- [ ] 不透過 LCD 正面施力；插拔力量落在 PCB／插座。
- [ ] 沒有短路、反插、鬆脫或未知 5V signal。

## Phase 1｜USB、boot 與 serial 最小測試

### 做什麼

韌體只做 `Serial.begin`、boot counter、reset reason 和每秒 heartbeat。建立 BOOT/RESET
恢復步驟，確認普通上電和 bootloader 上傳都可重現。

### 原理與目的

USB 枚舉、flash upload 和 MCU 執行是第一層；這一層不初始化螢幕，能把「板子沒
跑」與「顯示路徑有問題」分開。

### 測試

- 冷插拔 10 次、按 reset 10 次、上傳 3 次。
- log 包含 firmware version、build hash、reset reason。
- 若 port 改變，腳本重新枚舉，不硬編 `/dev/cu.usbmodem101`。

### Exit gate

- [ ] 20 秒 heartbeat 無 reset/disconnect。
- [ ] BOOT recovery 由另一位組員照文件成功一次。

## Phase 2｜圓屏獨立 display smoke

### 做什麼

建立最小 GC9A01 probe：D6 固定 HIGH；依官方 pin/driver 初始化；在每步前後輸出
`BOOT`、`SPI BEGIN`、`DISPLAY READY`、顏色名稱；循環紅綠藍白黑、十字線、方向
箭頭與中央文字。

### 原理與目的

背光亮只代表光源，SPI 能送資料才代表像素可控制。serial marker 能定位卡在 driver
前、SPI、初始化或 render，不把成功上傳誤判成顯示成功。

### 測試

- 冷開機 10 次，畫面和 marker 一致。
- 低 SPI clock 與正式 clock 各測一輪。
- 固定 HIGH 通過後再測 D6 off/on；PWM 另列可選 gate。
- 觸摸／按壓外殼時畫面不可因接觸不良改變。

### Exit gate

- [ ] 六色、方向和文字直接目視／影片證據。
- [ ] 若失敗，Issue 保留多個可否證假設，不直接判定 LCD 壞。

## Phase 3｜觸控與 RTC bring-up

### 做什麼

- I²C scan，確認 Round Display 板載裝置實際 address。
- 輸出 raw touch coordinate、press/release、swipe distance 和 debounce 後事件。
- 校正 rotation 與觸控座標轉換，四個方位和中心各測 20 次。
- RTC 寫入已知時間、斷電／重開讀取；記錄是否有備援電源及誤差。

### 原理與目的

顯示 rotation 與觸控座標可能不同；未校正會讓 UI 看得到卻點不到。RTC 只提供
watch face/time continuity，不取代活動倒數的 monotonic clock。

### Exit gate

- [ ] 100 次觸控命中率、誤觸和邊緣 dead zone 有量化紀錄。
- [ ] RTC/epoch/monotonic 三者責任寫入註解與文件。
- [ ] 觸控故障時 App fallback 仍能操作。

## Phase 4｜Orbit Display/Input Adapter

### 做什麼

- 依 `14-shared-firmware-architecture.md` 實作 `OrbitDisplayAdapter`、
  `OrbitTouchAdapter`、`OrbitClockAdapter`。
- renderer 只接受 `PresentationFrame`，不讀 BLE JSON 或修改 FocusSession。
- 建立 round clipping/safe-area、字體資產、CJK/fallback glyph 檢查。
- 做 watch/ready/active/paused/waiting/accepted/recovery/fault 畫面。

### 為什麼

將硬體差異收進 Adapter，核心 transition 與 Station 共用；UI 改版不會碰 journal
或 BLE ordering。

### 測試

- native frame mapping tests。
- render golden：關鍵文字、safe area、rotation、長字截斷。
- 20 分鐘動畫/refresh 壓力，不 watchdog reset。

### Exit gate

- [ ] 所有畫面都可由 fake core state 重現。
- [ ] 沒有產品規則寫在 touch handler 或 renderer。

## Phase 5｜共用 lifecycle、context 與 durability

### 做什麼

接上 common core：context exact revision、configure、start/pause/resume/complete、
monotonic countdown、stable sequence/event ID、最多八筆 queue、雙槽 NVS journal。

### 原理與目的

腕上裝置最容易遇到斷線和斷電；先把事件寫入 flash 再 notify，配合 stable ID，
才能讓 App 重試而不重複 reward。

### 測試

- 每一 transition 的合法／非法組合。
- pause 不計時；timer wrap/long duration/epoch jump。
- 在 journal commit 各階段模擬 reset、CRC/corruption、queue full。
- lost ACK 重送同 event ID；wrong-head ACK 不移除。

### Exit gate

- [ ] native tests 全綠。
- [ ] 實機 20 次隨機斷電仍恢復一致 queue/phase。

## Phase 6｜BLE protocol v2 與 App profile

### 做什麼

- 新增 read-only device profile/capabilities。
- 保留 v1 service UUID 相容策略；state/event/command 契約有版本測試。
- Android App 以 capability 顯示 Orbit 設定，只送一個 safe context。
- exact context revision 後 ready；取得 correlation/control lease 後 configure。

### 原理與目的

GATT write success 只表示資料送到 BLE stack，不代表 NVS 已保存。revision round-trip
才是 durable acceptance；profile 讓 App 不靠名稱猜裝置能力。

### 測試

- MTU 太小、oversize UTF-8、unknown version、stale revision、disconnect mid-write。
- 錯帳號、撤銷 assignment、stale lease、room scope 不符。
- App killed/restart，Orbit 保留 queue 且不開始第二個 session。

### Exit gate

- [ ] 真實 Android 連線、重連、replay 和 exact revision 有證據。
- [ ] PWA/iOS Simulator 成功不算 BLE 實機證據。

## Phase 7｜App → Cloud Ledger E2E

### 做什麼

1. Web 指派 Orbit 給測試帳號。
2. App 同步 context，建立 5 分鐘 personal session。
3. Orbit 完成事件；在 ACK 前斷線並重連。
4. App durable enqueue，ACK，Cloud 產生單一 Receipt/Reward。
5. App/Web 讀到相同角色狀態。
6. 撤銷 assignment 後確認不能開始新 session。

### Exit gate

- [ ] event/correlation/Receipt safe reference 可對照。
- [ ] lost ACK 只重送、不重複 coin/XP。
- [ ] 清理結果完整，沒有測試帳號／資料殘留。

## Phase 8｜穿戴外觀與 USB 驗收

### 做什麼

- 先做無電池外殼：螢幕開口、USB、reset/boot 維修、可拆腕帶、應力釋放。
- 配戴 30 分鐘檢查邊角、重量、腕帶、散熱和觸控。
- USB 兩小時 soak：反覆亮屏、BLE、NVS、活動，不過熱／brownout。

### Exit gate

- [ ] 可安全作展示穿戴概念。
- [ ] 文件明確標示 USB prototype、非防水、非全天候裝置。

## Phase 9｜可選電池版（獨立里程碑）

只有 Phase 0–8 全通過才開始。先完成電池料號、保護、極性、充電電流、低壓關機、
溫升、膨脹空間、24 小時續航和運輸／保存規範。充電測試不戴在手上；任何膨脹、
異味、異常溫升立即斷電並隔離。

## 最終交付

- source、PlatformIO lock、firmware binary/hash、flash 指令。
- hardware identity、pin/driver、display/touch calibration、電源報告。
- host/build/real-device/E2E 測試紀錄與影片。
- 使用者操作卡、故障恢復、已知限制、回復 firmware。
- `device-verified` 只能對本次硬體 revision + firmware + App commit 組合使用。
