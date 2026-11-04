# 21｜Nudge Orbit 完整功能目錄與畫面地圖

## 設計原則

Orbit 每個畫面只回答一個問題：現在幾點、我下一步做什麼、活動進行到哪裡、紀錄
有沒有安全送達。圓屏不是縮小的 App；深層設定、長文字與管理功能一律回 App。

## 導覽模型

```text
Watch Face
  ├─ tap → Today / Next Action
  ├─ swipe left → Character
  ├─ swipe right → Sync / Device
  └─ long press → Quick Focus

Quick Focus
  ├─ swipe → 5 / 15 / 25 min
  ├─ tap → confirm
  └─ App/Cloud prepared → Active

Active
  ├─ tap → pause/resume
  ├─ long press → complete confirmation
  └─ swipe → compact status only
```

導覽深度最多兩層；任何位置都能在一次 swipe／timeout 回 Watch Face。活動中禁止
因誤 swipe 進入設定或商城。

## F01｜圓形時間首頁

### 顯示

- 時間、日期、角色、BLE/sync、quiet、電量（只有 capability 存在時）。
- 外圈只顯示一個安全摘要：今日已完成／目前倒數／等待同步，不能同時三圈。
- Always-on 不作 v1 必要功能；idle 降亮或熄屏。

### 行為

- tap 打開 Today；long press 進 Quick Focus。
- 離線不隱藏時間，但 sync icon 清楚標示。
- 時間來自 RTC/phone anchor；倒數永遠使用 monotonic clock。

## F02｜Today／下一個小行動

- 顯示 App 選定的一個主行動，不在手錶上自行排序全部任務。
- 三種 action：focus timer、task reminder、safe health summary。
- `開始`、`稍後`、`在 App 調整`；稍後只改 presentation，不修改正式任務期限。
- action 過期或權限撤銷時顯示 refresh，不使用 stale data 開始活動。

## F03｜Quick Focus

- 預設 5/15/25 分鐘；App 可設定一個自訂常用值，限制合理範圍。
- personal 為預設；最多顯示一個 App 選定且仍獲授權的房間。
- App/Cloud correlation 未完成前顯示 preparing，不先開始可結算倒數。
- 離手機時只允許繼續已配置 session，不建立新的正式 Cloud session。

## F04｜Active Focus

- 中央倒數、外圈 progress、下方 personal/room、極小 sync 狀態。
- tap pause/resume；long press + confirm complete。
- complete 後依序呈現 `saved on Orbit` → `waiting for phone` → `accepted`。
- queue full 時禁止新 lifecycle 並提供回 App 同步的清楚提示。

## F05｜角色夥伴

- 狀態：sleep、ready、focus、pause、waiting、celebrate、recovery、fault-safe。
- 動作不隨機轟炸；只有 phase 或 Cloud accepted outcome 改變才播放重要動畫。
- 顯示角色 name/stage/level 與一個內建 asset key，不載入任意遠端圖片。
- 點擊只顯示一句短回應；完整圖鑑／進化路線回 App。

## F06｜Recovery

- 最近中斷後提供 `先做 5 分鐘` 或 `今天休息`。
- 不顯示失敗 streak、負分、家長／manager 監控文案。
- recovery plan 由 App 的 private snapshot 產生；Orbit 不自行分析人格或健康。

## F07｜安全通知

只支援低資訊量通知：

- 下一個自選提醒。
- 房間收到固定 acknowledgement。
- App 要求同步／更新。
- quiet hours 內只保留使用者主動開始的 timer 完成 cue。

不顯示聊天全文、健康數字、孩子資料或管理命令。通知點擊只開對應安全畫面。

## F08｜同步中心

- 顯示 App connection、pending count、last accepted age、context/lease revision。
- `pending` 不是 error；超過門檻才轉 warning。
- 提供 retry connection，但不讓使用者手動 ACK 或刪 queue。
- 顯示短 fault code，完整診斷在 App／serial。

## F09｜裝置資訊

- device nickname、profile、firmware、protocol、battery capability、App assignment。
- 不顯示完整 device secret、UID、token 或 room ID。
- reset/wipe/update 只能導向 App 並二次確認。

## F10｜配戴與省電

- wrist raise 只有在實際有 IMU capability 後才做；否則用 tap/timeout。
- idle 降低 frame rate、動畫與 BLE notify；active session 保持可靠 monotonic timer。
- 電量低時先降低 brightness/animation，不刪除 queue、不跳過 journal。
- USB prototype 顯示供電圖示，不假裝有 battery percentage。

## 圓屏狀態矩陣

| 系統狀態 | 主畫面 | 可操作 | 禁止 |
| --- | --- | --- | --- |
| unassigned | 配對圖示 | 開 App | 開始活動 |
| assigned/offline | 時間 + offline | 查看 pending | 新正式 session |
| ready | 角色 + next action | quick focus | 管理別人 |
| preparing | preparing ring | cancel | 重複 start |
| active | countdown | pause/complete | 改 room |
| paused | paused | resume/complete | 改 session owner |
| local saved | waiting phone | reconnect | 再發一筆 complete |
| accepted | short celebration | done | 本地加 XP |
| revoked | locked | 開 App | 所有 lifecycle |
| update required | update | 開 App | 不相容 command |

## 功能優先順序

- P0：Watch Face、Quick Focus、Active、sync states、fault、journal/replay。
- P1：Today、角色狀態、Recovery、安全通知、裝置資訊。
- P2：電池、省電深化、具能力時 wrist raise、角色小故事、成果卡。

## 驗收

- 每個畫面都有 fake-state preview 和實機照片。
- 一般流程不超過兩層導覽，Quick Focus 不超過三個明確操作。
- 字體、邊緣 touch target、長中文、英文數字、reduced motion 全部驗證。
- 任何 pending/rejected/revoked 都不播放 accepted celebration。
