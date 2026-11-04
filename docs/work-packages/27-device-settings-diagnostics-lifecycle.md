# 27｜裝置設定、診斷、更新、重設與生命週期

## 目標

裝置不是只在第一次展示能用，而是能被配對、理解、修復、更新、撤銷和安全轉移。
所有高風險動作由 App/Cloud 協調；Orbit/Station 提供狀態與自檢，不讓使用者透過
螢幕意外刪除 pending evidence。

## App「我的裝置」

每台卡片顯示：

- nickname、Orbit/Station profile、online/last seen。
- assignment 狀態、目前 controller、allowed rooms count。
- firmware/protocol、capabilities、更新相容性。
- context/lease revision、pending count、last Cloud accepted。
- battery/brightness/quiet 等只有 capability 存在的設定。
- fault summary 與 self-test 入口。

不顯示 raw UID、device secret、完整 BLE characteristic payload。

## 首次配對流程

1. 使用者登入 App，開啟 Bluetooth/附近裝置權限。
2. App 只掃描 Nudge service；顯示安全短代號與 profile。
3. 讀 Cloud assignment；未指派不能靠 BLE 自稱 owner。
4. profile/firmware/protocol 相容性檢查。
5. 送 context，等待 exact revision。
6. 執行互動 self-test。
7. 設定 nickname、quiet、預設 duration/room。
8. 顯示 ready 與恢復方法。

任一步失敗保留可重試位置，不要求重做全部流程。

## Self-test

### 共用

- device profile、serial/firmware、NVS health、BLE characteristics、clock。
- display color/text、input event、context readback。
- 非破壞性 test namespace，不碰正式 journal queue。

### Orbit

- touch center/edges、swipe、RTC、D6 backlight、可選 battery sense。

### Station

- square display、encoder、I²C addresses、ambient raw/filtered、LED low brightness、
  buzzer quiet-aware cue、5V/3.3V reset reason。

Self-test result 包含 `passed/degraded/failed/notSupported`；optional feature degraded 不
等於整台失敗，storage/authorization failure 必須 fail closed。

## Fault taxonomy

| Fault family | 範例 | 行為 |
| --- | --- | --- |
| display | init/render timeout | serial 可觀察；核心可否繼續依需求 |
| input | touch/encoder unavailable | App fallback，禁止誤 transition |
| sensor | ambient missing | 固定亮度 degraded |
| indicator | LED/buzzer missing | display 核心繼續 |
| storage | journal commit/corruption | 禁止新 transition，保護 queue |
| transport | BLE disconnect/MTU | 重連重送，不刪 queue |
| authorization | revoked/stale lease | fail closed/locked |
| compatibility | protocol/firmware old | update required |
| power | brownout/low battery | 降低 presentation，保護 commit |

每個 fault 有 code、severity、user message key、first/last seen、count；serial 可含技術
細節，Cloud/App audit 只傳必要摘要。

## Firmware 更新階段

### v1：USB serial

- 保存已知良好 binary、SHA-256、PlatformIO lock、flash/recovery 指令。
- update 前 App 提醒同步 pending；queue 未空不自動刷寫。
- 更新後讀 profile/version、跑 smoke/self-test、驗證 NVS migration。
- 失敗可 BOOT recovery 回前版。

### P2：signed OTA

需要裝置 claim/key、signed manifest、hash、rollback protection、A/B partition、電量／
供電 gate、Cloud rollout/rollback、版本相容。未完成以上不得把一般 HTTP binary
下載稱為安全 OTA。

## NVS schema migration

- 每份 context/journal/settings 有 schema version 和 CRC／validity。
- 新 firmware 先 read-old → validate → write-new slot → verify → activate。
- 失敗保留 old slot，不在 boot loop 反覆寫。
- downgrade 能讀或明確 factory recovery；不可默默解讀錯欄位。

## Reset 類型

### Soft restart

重啟 firmware，不清 context、assignment、queue。

### Settings reset

清 presentation preference，保留 assignment 和 pending queue。

### Assignment revoke

Cloud 停止新 control；不等於可跨帳號轉移。

### Verified wipe

先證明 queue empty/handled，再由 owner-authorized command 清除 assignment context、
presentation cache、settings，產生 wipe receipt；完成後才可解除 transfer lock。

裝置 UI 不提供未驗證的「清除全部」捷徑。

## 裝置轉移

1. 原帳號 revoke。
2. App 讀 pending；若不空先同步或處理 failed evidence。
3. Cloud 發 owner-bound wipe challenge。
4. 裝置執行 wipe、重開、回報 receipt/profile fresh state。
5. Cloud 驗證 receipt，解除 PII-free transfer lock。
6. 新帳號重新 assignment/pair/context/self-test。

## 維修與備份

- 接線、BOM、hardware revision、firmware binary、工具版本可追溯。
- 更換螢幕／主控後視為新 hardware identity，重新 peripheral/device acceptance。
- 不從舊裝置複製 device secret/NVS image 到新裝置。
- 送修前 owner 執行 verified wipe；無法開機則 Cloud 保持 transfer lock。

## 測試

- 配對每一步失敗和續接。
- optional/critical fault matrix。
- update with empty/nonempty queue、power loss、corrupt image、downgrade。
- NVS schema migration interruption。
- reset 類型不越權清資料。
- revoke/wipe/transfer race、帳號刪除與 transfer lock。

## 交付

- App flow、fault catalog、self-test schema、版本相容表。
- USB flash/recovery/runbook、known-good binaries/hash。
- wipe/transfer ADR 與 Cloud audit policy（實作前）。
