# 24｜Orbit、Station、App、PWA、Web 跨裝置連續體驗

## 目標

使用者在不同裝置間移動時，看見同一個活動、角色與關係世界；控制權明確轉移、
離線事件不遺失、同一行動不重複結算。跨裝置不是「所有端都能同時改」，而是
canonical state + 明確 control lease + 各端適合的呈現。

## 各端角色

| Surface | 最適責任 | 不負責 |
| --- | --- | --- |
| Orbit | 隨身查看、快速開始、簡短控制 | 管理、長文、完整設定 |
| Station | 桌上活動、房間選擇、感測回饋 | 取代 App 身分、監控他人 |
| Android App | assignment、BLE、context、outbox、完整設定 | 本地 mint reward |
| PWA | 30 秒快速入口、離線 web outbox | 實體 BLE v1 驗收 |
| Web | 報表、家庭／團體／catalog／device 管理 | 控制別人的 activity |
| Cloud | 身分、Receipt、Reward、Membership、Outcome | 硬體 presentation |

## Canonical state 與 presentation state

### Canonical

- Activity Session lifecycle、Receipt、Reward、room contribution。
- DeviceAssignment、control lease、Membership、catalog、relationship outcome。

### Presentation

- 目前畫面、亮度、動畫 frame、角色短句、selected menu、local pending。
- Presentation 可離線且各端不同，但不能改寫 canonical 結果。

## Control lease

### 欄位

```text
sessionId
controllerDeviceId
leaseRevision
issuedAt / expiresAt
assignmentRevision
allowedActions
```

### 規則

- 同一 session 同時只有一個 controller；App 可作 coordinator/read-only observer。
- lease revision strictly increasing；舊裝置收到新 revision 後停止控制。
- 網路中斷時 controller 可完成已配置 session並 journal；不可取得新 session。
- lease expiry 不刪除 pending event，App 仍依 occurrence-time assignment 驗證。
- transfer 需要使用者在 App 明確確認，不因兩台裝置靠近自動轉移。

## 主要旅程

### Journey A｜App 規劃，Orbit 執行

1. App 選下一步與 duration。
2. context revision 到 Orbit。
3. 使用者在 Orbit 確認；App/Cloud 建 correlation + lease。
4. Orbit 執行並 journal；App outbox/Cloud settle。
5. App、PWA、Web 更新正式結果，Orbit 收 accepted presentation。

### Journey B｜Orbit 開始，Station 接手

1. Orbit active；Station 顯示「另一裝置進行中」。
2. 使用者在 App 選 transfer to Station。
3. Cloud/App 發新 lease revision，Orbit 轉 read-only/idle。
4. Station 取得當前 elapsed/remaining 和 session correlation。
5. Station 後續事件保持同一 session，sequence 仍以各 source event ID 唯一。

若 protocol v2 無法安全接續 elapsed/sequence，MVP 不做 mid-session transfer，只允許
完成／discard 後在另一台開始；不得用 UI 假裝無縫。

### Journey C｜Station room，PWA 查看

- Station 選一個獲授權房間並開始。
- PWA 顯示 canonical active session，但 read-only；不建立第二個 web timer。
- room contribution 只在 Cloud accepted 後顯示。

### Journey D｜離線完成

- 裝置 local saved、App unavailable。
- 另一端顯示 stale/unknown，不推測 accepted。
- App 重連後 durable enqueue、ACK；Cloud idempotent settle。
- 所有端以 Receipt revision 更新一次 celebration。

### Journey E｜撤銷與換帳號

- revoke 後所有新 command fail closed；既有 queue 保留等待安全處理。
- logout 清除 App/PWA 使用者 presentation cache，不刪裝置 queue。
- 跨帳號 reassign 需要 verified empty queue + wipe receipt。

## Deep link 與裝置入口

- Web/PWA/App route 只帶 safe intent，例如 `open=device&deviceRef=safe-id`。
- URL 不帶 actor role、coin、XP、完整 room IDs、token。
- Orbit/Station 可顯示一次性 pairing short code，但 Cloud 驗證 assignment，不信任碼
  本身為 ownership proof。

## 同步衝突政策

| 衝突 | 決策 |
| --- | --- |
| 兩端 start 同 session | lease winner；另一端 rejected/read-only |
| 兩端 complete | stable event/correlation + Cloud lifecycle 冪等 |
| context revision 倒退 | 裝置拒絕 |
| room removed during offline | occurrence-time scope 驗證；不 fan-out 新 room |
| catalog archived | ownership 保留，presentation fallback |
| App logout with pending | 阻止新 control，保留安全同步提示 |
| firmware incompatible | 明確 update required，不截斷 command |

## App UI

- `My devices` 同時列 Orbit/Station：online、controller、pending、firmware、last sync。
- active session 卡片顯示目前 controller 和「轉移」條件。
- 禁止一鍵「清空 pending」；reset/wipe 有風險說明和 Cloud receipt。
- Surface 不支援能力時不顯示空按鈕，例如 Orbit 無 ambient sensor 設定。

## 測試

- 兩台同時 connect、start race、lease revision race。
- mid-session transfer 支援／不支援兩種明確結果。
- App killed、PWA offline、Station/Orbit restart 的組合。
- 同一 Cloud Receipt 在五個 surface 只形成一次 canonical update。
- logout/login B、revocation、Membership ended、queue nonempty transfer lock。
- clock skew、lease expiry、old firmware、unknown capability。

## 成功條件

- 使用者能說出「現在是哪一台在控制」。
- 任何 network/device failure 都不重複 reward 或遺失已 journal event。
- Surface 顯示可以短暫 stale，但必須標示，不能偽裝成同步完成。
