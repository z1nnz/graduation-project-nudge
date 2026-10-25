# 03｜裝置協定與 Android BLE 工作包

## 目標

完成一條可靠且可稽核的實機路徑：Web 指派裝置，Android App 取得正式指派並
連線，裝置執行活動，App 耐久收件，Cloud 冪等結算，Web／自律房／角色成果
看到相同結果。

裝置是活動來源 Adapter，不是身分或權限來源。它不能在 BLE payload 宣告
`actorUserId`、家庭角色、團體角色或房間權限。

## 既有 Seam

| 責任 | 主要位置 |
| --- | --- |
| JSON 協定與驗證 | `lib/services/nudge_device_protocol.dart` |
| transport-neutral bridge | `lib/services/nudge_device_bridge.dart` |
| App 協調與 lifecycle | `lib/services/nudge_device_coordinator.dart` |
| 執行期／模擬器 | `lib/services/nudge_device_runtime.dart`、`nudge_device_simulator.dart` |
| Cloud 指派讀取 | `lib/services/firestore_device_assignment_repository.dart` |
| Android native adapter | `android/app/src/main/kotlin/` |
| 韌體 BLE／queue | `firmware/nudge_focus_device/` |
| Cloud 管理指派 | `functions/src/device-assignment-service.js` |

不要繞過這些 Seam 讓畫面直接操作 GATT 或 Firestore。

## 切片 A｜配對與可理解的連線狀態（P0）

### 要做什麼

- App 只列出符合 Nudge service UUID 的裝置，顯示安全的裝置代號與訊號強度。
- 連線狀態至少區分：未授權、掃描中、找到未指派、連線中、同步中、可用、
  已撤銷、重連中、需重設。
- Android 權限被拒時提供系統設定入口與原因，不陷入無限 spinner。
- 連到裝置後先驗證 Cloud assignment，再送使用者 context。

### 驗收

- [ ] 錯誤帳號無法控制已指派裝置。
- [ ] 撤銷指派會使既有連線在下一個 lifecycle command 前斷開。
- [ ] App 重啟及手機藍牙重啟後可恢復，不會建立第二個 session。

## 切片 B｜版本與持久化握手（P0）

### 要做什麼

1. App 產生單調遞增 `contextRevision`。
2. context 只含 Cloud 允許的最多三個房間、個人目標、已核准角色快照與音效偏好。
3. 韌體寫入 NVS 後在 state notification 回報相同 revision。
4. App 只在 exact revision 相符時進入 ready；較舊、跳號或未知 protocol version
   必須明確失敗。
5. 連線 MTU 太小放不下完整 v1 command 時 fail closed；不要偷偷截斷 JSON。

### 測試

- 舊 revision、未來 revision、重送同 revision、NVS 寫入失敗、斷線後重連。
- context 超過最大房間數、UTF-8 邊界、未知欄位、未知 protocol version。
- negotiated payload 小於 command 時 App 顯示可理解錯誤。

## 切片 C｜事件耐久交接（P0）

### 正確順序

1. App 先讓 Cloud 接受 `started` 並取得 canonical correlation。
2. App 才送 configure；Cloud 不可用或拒絕時裝置維持未配置。
3. 裝置先將事件及 sequence 寫入自身 journal，再通知 App。
4. App 讀 queue head，重新驗證當下 assignment 和 `roomContextId`。
5. App 把 ActivityEvidence 耐久寫入自身 Ledger outbox。
6. 只有步驟 5 成功才 ACK 完全相同的 queue-head event ID。
7. Cloud 以穩定 event ID 去重；失聯重送回同一 Receipt，不重複發獎。

### 必須拒絕

- assignment 已撤銷、user 不符、room 不在 occurrence-time scope。
- queue 非 head event、event ID／session correlation 不符。
- 同一 active assignment 任意增減 rooms，或 revoke 後未完成 wipe 又重新啟用。
- 裝置要求 App 替另一位成員、孩子或房主執行活動。

## 切片 D｜真實 Android E2E（P0）

### 測試案例

1. Web 指派一台乾淨裝置給帳號及一個房間。
2. Android 登入、掃描、連線、同步 exact context revision。
3. 旋鈕選房，開始、暫停、繼續、完成。
4. 完成後在 ACK 前強制斷線，再重連；只出現一份 Cloud Receipt。
5. 再做一次不選房的個人活動；不得自動散布到所有允許房間。
6. 驗證 App、Web、房間貢獻、Reward Ledger、角色狀態一致。
7. 撤銷指派後重試 lifecycle command，確認 fail closed。
8. 清除測試資料或以專用測試帳號保留去識別化證據。

### 證據

- App commit、firmware hash、Android 型號／版本、protocol version。
- 事件 ID、correlation、Receipt ID 的去識別化對照。
- BLE／serial 時序紀錄、App 畫面、Cloud 結果與 Web 畫面。
- 重連與重送案例沒有重複 coin、XP、room contribution。

## 自動測試

```bash
flutter test test/nudge_device_protocol_test.dart
flutter test test/nudge_device_bridge_test.dart
flutter test test/nudge_device_coordinator_test.dart
flutter test test/nudge_device_runtime_test.dart
flutter test test/nudge_device_simulator_test.dart
flutter test test/android_nudge_ble_transport_test.dart
node --test test/android_ble_bridge_test.js test/device_assignment_surface_test.js
npm --prefix functions test
```

## 不在目前專題 gate

- 實體 iPhone BLE 驗收。
- direct Wi-Fi Cloud ingestion、device signature、claim certificate、key rotation。
- 家庭／團體共用同一台裝置。
