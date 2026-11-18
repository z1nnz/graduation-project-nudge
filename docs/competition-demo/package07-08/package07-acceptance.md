# 07 App／BLE：軟體準備與實機待驗

## 實作與驗收對照

| 指標 | 本輪軟體 | 實機結果 |
| --- | --- | --- |
| Demo 掃描名稱 | 精確 `Nudge Orbit Demo`／`Nudge Station Demo`，只掃獨立 7df2 service | 未用真實手機掃描 |
| 連線／一次一台 | 未連線／連線中／已連線；先取得對應裝置有效 state，才允許三按鈕；連線中不能重複掃描 | 未連實機 |
| Next／Restart／StartFocus | 專用 v1 Demo command；單一 pending write、無自動重送；local input 優先 | host 10／5 次不代替板上 10／5 次 |
| 不等 Firebase／帳號 | 獨立 Dart 入口與 channel，不建立 AppState／DeviceAssignment／Cloud command | widget 與本機 Web 開啟成功，未啟動 Android APK |
| 失敗回自動展示 | 權限／掃描／連線／MTU／寫入錯誤／逾時，清狀態、斷線、顯示改用自動展示 | 真實藍牙關閉／App 關閉未驗 |
| 韌體不由 callback 繪圖 | 4 格 FreeRTOS command queue，callback 只驗證與 enqueue，loop 才更新 Scene | 真實 SDK 記憶體／延遲仍未驗 |
| 僅 NUDGE_DEMO=1 接受 | adapter 以 NUDGE_BUILD_DEMO_BLE && NUDGE_DEMO 編譯；production 專案與 7df1 service 不接受這條路徑 | 沒有接正式裝置測試 |
| 無私人資料 | command 只 3 欄，state 只 v／mode／device／scene／index；額外欄位拒絕 | 沒有傳送真帳號或健康資料 |
| 手機與畫面同時影片 | evidence.json 保留位置與 hash | **未拍，0 實機通過** |

## 協定

UUID、名稱與 Scene ID 的唯一來源是 `shared/demo_contract.json`，生成 C++／Dart／Kotlin 常數；Node check 驗證產物一致。
service `7df20000-4e55-4447-4500-4e5544474531`，command `7df20001-…`，state `7df20002-…`。
沒有沿用 production 的 7df1 command/event，也沒有新增 Cloud 權限或資料真相。

```json
{"v":1,"type":"demo","action":"next"}
```

action 只接受 next／restart／startFocus。三欄須唯一，v 是整數 1，最多 96 bytes；未知、重複、額外資料、逃脫欄名／不支援格式都拒絕。
韌體用範圍有限的 ASCII JSON grammar，不宣稱通用 JSON parser；官方 client 只產生此最小格式。

```json
{"v":1,"mode":"demo","device":"orbit","scene":"focus","index":3}
```

App 驗證五欄、整數版本、裝置／Scene／index 對應；GATT connected 事件本身不會啟用控制。
Android 請求 MTU 517，peer 至少 99；韌體設定 185。無法協商則斷線回備援，不分割重送。
廣播分成 21 bytes 的 flags＋128-bit UUID 與完整名稱 scan response，避免 UUID／完整名稱擠在同一個 31-byte 封包。

## 前置與啟用

公開版本所有 gate 為 false，不能拿 `_ble_check.bin` 稱為可直接連線的已驗證成品。
兩台 P0-B、視覺一致與十次重播證據完成後，持板者才可：

1. 在本機硬體 profile 填實際已確認接線，依證據將 orbitP0bAccepted／stationP0bAccepted／visualsAccepted／tenReplaysAccepted 設 true，最後才 armBle。
2. 重建 orbit_ble_check 或 station_ble_check；硬體 override 會記錄 hw 雜湊，公開打包器不匯出此配置，實機紀錄須另存實際版本／設定。
3. Flutter 3.41.7（CI 版本）執行 pub get，再開預覽：

```sh
flutter run --target lib/main_demo_controller.dart
```

實機前置都完成才可增加五項參數：

```sh
flutter run --target lib/main_demo_controller.dart --dart-define=NUDGE_DEMO_BLE=true --dart-define=NUDGE_DEMO_ORBIT_P0B=true --dart-define=NUDGE_DEMO_STATION_P0B=true --dart-define=NUDGE_DEMO_VISUALS=true --dart-define=NUDGE_DEMO_TEN_REPLAYS=true
```

先連 Orbit 或 Station 一台，中斷後才連另一台。操作 Next／Start Focus／Restart，確認裝置回報與實際畫面。
`指令已傳送` 只表示 transport 接受，沒有正式 receipt 或 exactly-once 裝置 ACK。
queue 滿、斷線、local input 優先時可丟棄待處理命令，不自動重送；必須以實機影片驗證 10／5 次。
App dispose 會斷線，韌體斷線清 queue、重開廣播；不以連線狀態暫停 tick，無輸入 5 秒後仍自動。

SDK begin 可能有一次性耗時；有 heap 初步檢查／可回報失敗的入口保護，但未宣稱已通過真實無重啟／無卡頓。
如果 BLE SDK 造成重啟或白屏，立即移回無 BLE 的 orbit_demo／station_demo，不改 Cloud 解決。

## 停止條件與實機清單

- [ ] 兩台 P0-B、視覺與十次自動重播先通過，記錄真正 firmware／profile id。
- [ ] 真手機精確掃描 Demo 名稱，版本與手機型號可重現。
- [ ] Next 連續 10 次無雙跳，Restart 5 次，錄到 App 操作與裝置畫面。
- [ ] 手機關藍牙、App 關閉後裝置仍自動；沒有黑屏或停住。
- [ ] 核對比賽日期。距離不足 3 天且尚未連續成功 10 次，不啟用 P2。

需要 Cloud security model／真帳號、BLE 重啟／卡畫面、跨手機不重現時，立即停止 P2，回 P0-A／P0-B 排練。
本輪未取得比賽日期，不推定已滿足時間門檻；目前全部停用。
