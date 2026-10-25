# 01｜目前狀態、缺口與優先順序

## 判讀方式

本文件以 2026-10-25 的 `origin/main` 為基線。「存在程式碼」和「真實環境完成」
分開記錄；較早的藍圖若仍寫著功能尚未開發，以目前 source、測試與最新驗收紀錄
為準。

## 已有的正式基礎

| 能力 | 目前狀態 | 主要位置 |
| --- | --- | --- |
| Activity Ledger、Receipt、去重、房間貢獻 | implemented／已有 production E2E 基線 | `lib/services/cloud_activity_ledger_gateway.dart`、`functions/src/activity-ledger-service.js` |
| App/Web 耐久 outbox | implemented | `lib/services/activity_ledger_outbox.dart`、`web_dashboard/assets/activity_ledger_client.js` |
| Health Connect／Apple Health 快照與 correction | implemented | `lib/services/health_snapshot_outbox.dart`、`functions/src/ingest-health-snapshots-handler.js` |
| Cloud Reward Ledger、購買／裝備與第一階販售規則 | implemented | `functions/src/reward-purchase-service.js`、`functions/src/reward-avatar-service.js` |
| 多家庭／多團體 Membership 與角色介面 | implemented | `lib/models/relationship_membership.dart`、`web_dashboard/assets/relationship_membership_contract.js` |
| 家庭樹、團體星球、共同回憶 | implemented／Cloud 衍生成果 | `functions/src/relationship-outcome-service.js` |
| 自律房非同步個人活動與 Room Resonance | implemented | `lib/services/room_activity_session_ledger_gateway.dart`、`functions/src/room-resonance-service.js` |
| 裝置指派、韌體核心、BLE 協定、App bridge | source-verified | `firmware/nudge_focus_device/`、`lib/services/nudge_device_bridge.dart` |
| Web catalog 上架、裝置指派與營運介面 | source-verified | `web_dashboard/assets/admin_catalog.js`、`admin_device_assignments.js` |

## 還沒有被證明完成的事

### P0：專題版完成前一定要做

1. **實體圓形螢幕 Bring-up**：USB、燒錄和韌體執行已證明，但顯示畫面仍未以
   可重現的 serial marker 加直接觀察證明。
2. **完整高規格周邊驗收**：旋鈕 `0x36`、VEML7700 `0x10`、蜂鳴器 `0x34`、
   D6 背光、5V LED 位準轉換、供電和溫升。
3. **真實 Android BLE 閉環**：指派 → context revision → 選房 → 活動 →
   裝置 queue → App outbox → Cloud Receipt → Web/房間/角色結果。
4. **版本化驗收紀錄**：保存 firmware hash、App commit、deviceId 去識別代號、
   手機版本、測試時間、serial log、畫面和 Cloud 清理結果。

### P1：讓系統可用且有說服力

1. App 首次使用與裝置設定要讓非開發者理解，不可只顯示技術狀態。
2. Web 導覽和管理操作依登入者能力顯示；管理者、成員、家長、孩子不能共用
   一張含無權按鈕的介面。
3. 角色上架、圖鑑、進化、商城與裝置快照需要一份共同視覺／契約驗收。
4. 家庭、團體、自律房和角色成果要形成「今天做一個小行動，關係世界有回應」
   的清楚循環，且不能變成監控。
5. 失敗復原要完整：離線、撤銷指派、BLE 斷線、過期 context、重送、舊版資料。

### P2：商用前強化，不阻擋專題展示

- 裝置 claim、每台裝置金鑰、簽章事件、時間證明與 key rotation。
- 安全 Wi-Fi provisioning、直接 Cloud device ingestion、簽章 OTA。
- App Store／Play 正式 package identifier、商店簽章與實際推播收據。
- 大量使用者分片、長期歷史彙總、進階 AI 行為預測。
- 家庭／團體共用裝置；目前裝置只服務被指派的個人。

## 里程碑

### M1：硬體可觀察

- 螢幕可穩定顯示獨立色塊與文字。
- I2C 掃描、LED、蜂鳴器、環境光分別有 pass/fail。
- 不接可選周邊時核心計時仍可用。

### M2：裝置可靠

- context revision、NVS、事件 queue、斷線重播、只 ACK queue head 通過。
- 斷電重開不遺失未 ACK 事件，也不重複結算。

### M3：全系統閉環

- 真實 Android 手機完成一次個人活動及一次獲授權房間活動。
- App、Cloud、Web、房間成果與角色狀態一致。
- 撤銷指派後既有連線無法再控制裝置或提交新事件。

### M4：可展示產品

- 新使用者可自行完成登入、角色選擇、加入自律房、設定裝置和開始活動。
- 家長／孩子、管理者／成員各自只看到可用操作。
- 失敗狀態有可理解的復原指引。
- 所有宣稱都對應自動測試、實機或正式環境證據。

## 不要重做的事

- 不另建第二套活動紀錄或獎勵計算。
- 不把家庭和團體改成互斥帳號類型。
- 不讓房主開始／結束所有人的房間活動。
- 不讓商城販售進化後階段。
- 不因硬體還沒驗收而推翻已測試的 Ledger、Membership 和角色服務。
