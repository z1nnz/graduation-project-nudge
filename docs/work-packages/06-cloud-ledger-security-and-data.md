# 06｜Cloud、Ledger、安全與資料治理工作包

## 目標

維持 Cloud 作為活動、獎勵、權限和衍生成果的唯一權威，補齊營運稽核、資料
生命週期和未來裝置可信身分。任何新來源都要接到既有 Ledger Interface，而不是
建立旁路。

## 切片 A｜Ledger 契約守門（P1）

### 規則

- `recordActivity(ActivityEvidence) -> ActivityReceipt` 保持唯一正式活動入口。
- actor 從驗證身分取得，不信任 client-supplied user ID。
- 同一 stable event ID 重送回相同或可追蹤 correction 的結果。
- 一筆活動只結算一次個人 reward；多房間只有多個可見 contribution。
- App/Web 計時活動要先有 Cloud 接受的 started，completed 時數不得超過 Cloud
  可觀察時長。
- steps/sleep 只接受受信任 health Adapter；Web 不得提交人工健康數字。

### 新來源接入清單

每個 Adapter 都要定義來源識別、證據格式、時間政策、去重鍵、correction、可
獎勵性、房間分享與 privacy lifecycle。缺一項就不得進 production。

## 切片 B｜正式稽核與可觀察性（P1）

- 為 catalog publish/archive、device assign/revoke、Membership 角色變更、privacy、
  notification、migration 建立一致 audit envelope。
- audit 至少含 event type、actor、target safe reference、request ID、時間、結果、
  schema version；禁止放 token、健康明細或任意 payload dump。
- 建立營運查詢：失敗 callable、重複事件率、outbox 延遲、Receipt settle 延遲、
  rejected capability、device reconnect/replay。
- 告警不直接顯示真實 email、家庭名稱或健康值。

## 切片 C｜資料變更與舊投影（P1）

每次 schema/cutover 使用：

1. 預設 dry-run，只列問題與預計變更數。
2. project/run-bound fence，阻擋新舊 authority 同時寫。
3. 每筆交易驗證 before fingerprint 和 runner ownership。
4. 可續跑 apply，失敗時 fence 保持關閉。
5. rollback 只還原未被後續合法修改的 before-image。
6. 第二次 dry-run 必須回報零問題／零待清理項目。
7. 只有 fresh-install、production E2E 和 acceptance evidence 完整後才 purge。

不得以刪除舊欄位來取代 migration；不得在沒有 retention gate 時清除稽核資料。

## 切片 D｜隱私與通知（P1）

- export／account deletion 覆蓋 Ledger owner data、Membership、relationship outcome、
  room resonance、device assignment/transfer lock、notification/audit 的正式範圍。
- account deletion 與 migration/purge 共用 destructive-operation guard。
- 通知只傳最小安全內容；實際資料由登入後 App 讀取。
- consent、notification preference、data request 全部由 App Check-protected Cloud
  command 寫入並產生不可變 audit。
- 家庭健康分享必須逐類別、可撤回，不因 guardian 角色自動全部開放。

## 切片 E｜可信裝置身分（P2，商用前）

目前 prototype 的 Cloud source 是已登入 App，device ID 只提供相關性，不是密碼學
證明。商用版另立 ADR 後實作：

1. 製造／claim credential 和 owner-bound provisioning。
2. 每台裝置不可匯出的 private key 或等價保護。
3. server challenge、signed event envelope、nonce/replay policy、clock uncertainty。
4. key rotation、lost device revoke、factory wipe receipt、transfer state machine。
5. direct device ingestion 與 App ingestion 使用同一 Ledger service，但不同
   authentication Adapter。
6. signed OTA manifest、rollback protection 和故障恢復。

在以上完成前，UI、文件和簡報不得稱裝置事件為「防偽」或「實體行為證明」。

## 測試

- unit：service invariants、error mapping、caps、idempotency、correction ordering。
- emulator：Rules、transaction race、fence ownership、rollback、account deletion 競爭。
- contract：App/Web/Cloud 同一 schema version 和 enum。
- production：短效 admin OAuth + 短效 App Check token 的真實帳號 E2E，完成後清理。
- security negative tests：偽造 actor、跨 scope、stale membership、replay、oversized input。

## 主要位置

- `functions/src/activity-ledger-service.js`
- `functions/src/firestore-activity-ledger-store.js`
- `functions/src/reward-purchase-service.js`
- `functions/src/account-deletion-service.js`
- `functions/src/privacy-*.js`
- `firestore.rules`、`storage.rules`、`firestore.indexes.json`
- `scripts/migrate_*.js`、`scripts/production_real_account_e2e.mjs`
- `docs/production-acceptance.md`

## 交付與驗收

- 每個資料切片附 threat/abuse cases、emulator 測試、migration/rollback、監控欄位。
- 正式執行只回報去識別化摘要；Token 不寫入命令歷史、檔案或 PR。
- `production-verified` 必須能指出實際 run 與 cleanup，不接受只看 source tests。
