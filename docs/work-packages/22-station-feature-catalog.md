# 22｜Nudge Station 完整功能目錄與畫面地圖

## 設計原則

Station 是桌上的行動中樞，不是被動統計螢幕。首頁要讓使用者一眼看懂「現在可以
做什麼」，旋鈕在一到兩次動作內開始。更多資料可以顯示，但不能讓核心 CTA 被
房間、感測器、角色和診斷資訊淹沒。

## 導覽模型

```text
Living Desk
  ├─ rotate → personal / allowed room
  ├─ press → prepare / start
  ├─ long press → quick menu
  └─ App command → settings / diagnostics

Active
  ├─ short press → pause/resume
  ├─ long press → complete confirmation
  └─ rotate → switch information panel, never switch room

Quick Menu
  ├─ duration
  ├─ quiet
  ├─ brightness mode
  ├─ self-test
  └─ back
```

## F01｜Living Desk 首頁

- 角色、主行動、selected personal/room、BLE/Cloud/pending、quiet/brightness。
- VEML7700 只控制呈現亮度；畫面仍可手動鎖定低／中／高。
- 旋鈕切 context，按下準備；無 assignment 時顯示 App 配對入口。
- 可選顯示時間，但不讓時鐘搶走下一步。

## F02｜行動準備儀式

- 選 duration、personal/一個房間、quiet；使用最近合法值作預設。
- 顯示 App/Cloud preparing、exact context revision、control lease。
- correlation 未取得時不能進入正式倒數；可取消回首頁。
- 房間在準備期間失去 Membership 時 fail closed 並回 personal 建議。

## F03｜Focus 控制台

- 大倒數、progress、角色、selected context、pending/sync。
- LED stick 顯示 progress；paused 使用低頻靜態色，complete 使用一次短動畫。
- Buzzer 只在 start/pause/resume/complete/error 播短 cue。
- 旋鈕在 active 中只切換資訊 panel，不改 frozen room context。

## F04｜Rest Coach

- 完成後提供短休息倒數、伸展／喝水等一般性提示，使用者可略過。
- 不作醫療建議，不以 camera/sensor 判定是否真的休息。
- quiet hours 只顯示視覺，不播聲音。
- 休息結束只回 ready，不自動開始下一輪。

## F05｜Room Portal

- 最多三個 Cloud-allowed rooms，顯示 label、goal、個人是否 opt-in 分享。
- 顯示 aggregate progress 和 Room Resonance cue，不顯示精確成員健康／分鐘。
- Station 只能替本人開始；manager/owner 沒有控制他人的入口。
- room removed/revoked 後即刻從可選列表消失，pending 舊事件仍依 occurrence scope。

## F06｜Character Stage

- 角色依 focus phase 和 Cloud accepted outcome 改變表情／姿態。
- 可顯示目前 stage、level、下一階所需正式 XP；不在 Station 購買或裝備。
- archived asset 使用內建 fallback；不因網路中斷白屏。
- 每週可顯示一段短故事，但故事解鎖只讀 canonical snapshot。

## F07｜Ambient Scene

- LED、backlight、角色背景使用同一 `PresentationFrame`。
- 模式：quiet desk、standard、high visibility；不是任意 RGB 玩具設定。
- 使用者可關閉 LED 或聲音，但不能關閉重要文字 fault。
- 夜間最低亮度和最大 LED current 有 firmware hard limit。

## F08｜Today／簡要進度

- 一個主行動、今日 accepted count、目前角色成長、一個關係世界摘要。
- 不顯示完整報表、排行榜或十幾張卡；詳細資料回 App/Web。
- pending 與 accepted 分開；local complete 不先算入正式成果。

## F09｜房間營火

- 顯示 opt-in Room Resonance fixed cue 和 acknowledgement count。
- 旋鈕可送一個固定 acknowledgement；不能回覆自己、不能自由文字。
- signal 過期／撤回／離開房間立即停止呈現。
- 此互動不發 coin/XP，也不改 focus lifecycle。

## F10｜Focus 模板

- App 可下發最多三個安全模板：例如 25/5、50/10、自訂一個。
- Station 只選模板，不編輯複雜 recurrence/任務內容。
- 模板 version 改變走 context revision；active session 不受中途更新影響。

## F11｜自檢中心

- Display：色塊、文字、backlight。
- Input：旋鈕方向、press/long press。
- I²C：0x10/0x34/0x36 availability。
- LED：逐顆低亮色測試。
- Buzzer：一次低音量 cue。
- Storage：非破壞性 journal read/write test area。
- BLE：profile/state/event characteristic readiness。

自檢不清 queue、不改 assignment、不發 ActivityEvent。

## F12｜同步與故障中心

- pending count、last phone contact、last Cloud accepted age、context/lease revision。
- fault 分類：display/input/sensor/indicator/storage/transport/authorization/update。
- optional peripheral fault 以 degraded mode 運作；storage/authorization fault fail closed。
- 提供 QR／短碼導向 App 說明，但不把 secret 放在 QR。

## F13｜更新與維護

- v1 先使用 USB serial flash；App 顯示目前 firmware 與最低相容版本。
- update 前 queue 必須處於安全狀態；若不為空，先同步或明確延後。
- 更新失敗可進 BOOT recovery 並刷回已知良好 binary。
- signed OTA 屬商用 P2，未完成前不把無簽章 Wi-Fi 更新當正式功能。

## F14｜展示與教學模式

- Guided tour 使用 fake presentation frames 展示 UI，但畫面永久標示 `示範資料`。
- Hardware self-test 可在沒有帳號時執行；不得產生 Cloud evidence/reward。
- Live mode 只使用真實 assignment、Receipt 和 outcome；不可混入示範 projection。

## Station 狀態矩陣

| 狀態 | Display | LED | Buzzer | Control |
| --- | --- | --- | --- | --- |
| offline | pairing/clock | slow neutral | none | no new formal session |
| ready | next action | steady ready | optional | select/start |
| preparing | progress | soft pulse | none | cancel only |
| active | countdown | progress | start once | pause/complete |
| paused | pause UI | steady paused | pause once | resume/complete |
| local saved | waiting | sync pattern | none | reconnect |
| accepted | outcome | one celebration | complete once | return/rest |
| degraded | feature fault | remaining valid state | if valid | core may continue |
| locked | assignment/wipe | warning | error once | fail closed |

## 優先順序

- P0：Living Desk、prepare、focus、sync/fault、自檢、display/encoder/LED 基本狀態。
- P1：Rest Coach、Room Portal、Character Stage、Ambient Scene、templates、resonance。
- P2：故事、進階場景、更多模板、signed OTA、額外經證明的感測器。

## 驗收

- 首次使用者可在 30 秒內找到並開始一個 personal focus。
- personal/room 不會因旋鈕快速轉動或 active 中切 panel 而混淆。
- 任一 optional peripheral 拔除時，degraded mode 與 fault 一致。
- Guided tour 和 Live mode 的資料來源永遠可辨識。
