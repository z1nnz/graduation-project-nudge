# 19｜Orbit／Station 雙裝置測試與驗收矩陣

## 目的

把「程式測過」「板子有亮」「整機可用」「Cloud 已正式接受」分成不同證據層級。
任何一層成功都不能自動推論下一層成功。

## 證據層級

| 層級 | 能宣稱 | 不能宣稱 |
| --- | --- | --- |
| host-verified | portable core 行為在電腦測試通過 | ESP32 build／實體周邊正常 |
| build-verified | 指定 PlatformIO env 可乾淨編譯 | 已燒錄／畫面正常 |
| board-verified | ESP32 可上傳、serial 穩定 | display/sensor/BLE 正常 |
| peripheral-verified | 一個指定周邊在指定接線可重現 | 完整產品或 Cloud 閉環 |
| device-verified | 指定硬體 revision + firmware + App 可完成實機案例 | 商用安全／其他板版次 |
| production-verified | 真實 Cloud E2E 且 cleanup 完整 | signed physical proof／醫療能力 |

## A. 靜態與 host 測試

### 共用核心

- configure/start/pause/resume/manual/timed complete。
- 暫停時間排除、monotonic rollover、epoch jump。
- illegal transition、queue full、event sequence high-water。
- context revision strictly increasing、room max、safe string bound。
- journal A/B slot、CRC/corruption、partial commit、power-loss recovery。
- exact queue-head ACK、lost ACK replay、duplicate Cloud Receipt。
- control lease acquire/renew/expire/transfer/stale revision。
- PresentationFrame 對各 phase、fault 和 capability 組合。

### 命令

```bash
make -C firmware/nudge_device_core test
pio run --project-dir firmware/nudge_orbit
pio run --project-dir firmware/nudge_station
flutter test test/nudge_device_protocol_test.dart
flutter test test/nudge_device_bridge_test.dart
flutter test test/nudge_device_coordinator_test.dart
flutter test test/nudge_device_runtime_test.dart
```

若重構尚未建立新目錄，先使用現有 `firmware/nudge_focus_device` 命令並在 PR 說明
對應路徑；不能為了讓文件命令看似有效而一次大搬家。

## B. 硬體 bring-up 矩陣

| 測試 | Orbit | Station | 通過條件 |
| --- | --- | --- | --- |
| USB/serial cold boot ×10 | 必須 | 必須 | 每次完整 marker，無 boot loop |
| Display colors/orientation | GC9A01 | Gate 0 driver | 六色、角落、文字、rotation 正確 |
| Input ×100/500 | touch ×100 | encoder ×500 | 無重複 lifecycle／誤觸有統計 |
| I²C scan | 板載 touch/RTC | 0x10/0x34/0x36 | address 穩定、缺席不 crash |
| Backlight | D6 high/PWM fallback | 依方屏規格 | 不閃爍、不過流 |
| LED | 不適用 | level-shifted WS2813 | 30 分鐘無 brownout/data error |
| Buzzer | 不適用 | Qwiic | quiet 有效、非阻塞 |
| Ambient | 不適用/未確認 | VEML7700 | 三段光照平順、fault fallback |
| RTC | 必須確認 | 選配 | 只供 wall time，不影響 countdown |

## C. Fault injection

每項至少做一次自動或可重現實機測試：

- upload 中斷與 BOOT recovery。
- display init timeout；display 缺席時 serial fault 仍可觀察。
- I²C device 拔除／NACK／bus lock。
- NVS write fail、corrupted context、journal slot 壞一份。
- BLE 在 command 中斷、notify 後 ACK 前中斷、手機藍牙重啟。
- App killed、登出、換帳號、assignment revoke。
- Cloud offline、App Check reject、room Membership 過期。
- Orbit/Station 同時請求 control，同一 session 只有一個 owner。
- firmware v1/v2、App 新舊版本相容／明確阻擋。

## D. Activity E2E 案例

### Case 1｜Orbit personal

1. 指派 Orbit，context revision accepted。
2. 開始 5 分鐘 personal focus。
3. pause/resume，完成後在 ACK 前斷線。
4. 重連，App durable enqueue，Cloud 只有一個 Receipt/Reward。
5. App/Web 顯示相同角色結果。

### Case 2｜Station room

1. 指派 Station 與一個 allowed room。
2. 旋鈕選房，configure 凍結選擇。
3. 完成並形成單一 room contribution。
4. 同一 evidence 不對其他 allowed rooms 自動 fan-out。

### Case 3｜雙裝置衝突

1. Orbit 已持有 active session lease。
2. Station 嘗試控制同一 session，必須 read-only/rejected。
3. App 明確 transfer；Orbit 收到較新 lease revision 後 idle。
4. Station 接手；Cloud lifecycle 保持單一 session。

### Case 4｜撤銷與轉移

1. 每台都建立一筆 pending event。
2. revoke 後不可直接跨帳號 reassign。
3. 只有 verified empty queue + wipe receipt 才解除 transfer lock。

## E. 電氣與壓力

### Station

- 2 小時高亮 display + LED 動畫 + buzzer cue + BLE + NVS。
- 量測 USB input、5V/3.3V rail、level shifter、ESP32/LED 溫度與 reset count。
- 24 小時 idle/periodic reconnect；pending、heap、watchdog 無惡化。

### Orbit USB 版

- 2 小時 display/touch/BLE/NVS；配戴概念 30 分鐘檢查熱與機構。
- 不做防水宣稱；未通過 battery gate 不作續航宣稱。

### Orbit 電池版

- 獨立記錄 charge/discharge、峰值、低電壓、溫升和 24 小時以上實測。
- 充電不配戴；任何電池異常立即停止，不能為趕展示跳過。

## F. 資安、隱私與權限

- BLE event 不信任 actor/role/room；App 依當下 Cloud assignment/Membership 驗證。
- 裝置不保存 email、token、家庭健康明細、聊天或完整 Ledger。
- 錯帳號、removed member、ended family link、stale room scope 全部 fail closed。
- serial/照片/驗收 JSON 去識別化，不把 token、密碼和 UID 上傳 PR。
- v1 不含 device signature，不宣稱防偽實體行為證明。

## G. Release acceptance record

每台建立一份：

```markdown
# Device acceptance

- Product: Orbit / Station
- Hardware identity/revision:
- App commit:
- Firmware commit + binary SHA-256:
- Protocol/profile version:
- Android model/OS:
- Tester/date:

## Automated tests
## Peripheral evidence
## Fault injection
## E2E event/correlation/Receipt safe references
## Power/thermal/soak
## Cleanup
## Passed claims
## Explicitly unverified claims
```

## 最終 Gate

- [ ] 兩台各自 device-verified。
- [ ] Case 1–4 全部通過。
- [ ] App、Cloud、Web 無第二套 reward/outcome 真相。
- [ ] 組員之外的人可照文件重刷、重連、操作與恢復。
- [ ] 展示版 binary、source、BOM、接線、外殼和證據可還原。
