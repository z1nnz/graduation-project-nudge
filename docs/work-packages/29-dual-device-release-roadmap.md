# 29｜Orbit／Station 功能優先級與版本路線

## 目的

功能豐富不等於同時開發全部。每一版必須有一條可完成的使用者循環、可回復的故障
路徑和清楚證據；下一版在前一版穩定後擴充，不讓動畫、故事或額外感測器阻擋
核心 Activity Ledger 閉環。

## R0｜硬體識別與可觀察（P0）

### Orbit

- hardware identity、USB/serial、GC9A01 color/orientation、touch/RTC scan。

### Station

- hardware identity、方屏 driver/interface/pin/power、serial、display smoke。

### 共用

- 現有 v1 characterization tests、原始 log/照片、回復操作。

### 完成條件

兩片螢幕都能由另一位組員冷開機 10 次重現；方屏型號與接線不再未知。

## R1｜本地可靠計時器（P0）

### 共用

- portable lifecycle、monotonic timer、context、journal、queue-head ACK tests。
- PresentationFrame 與 hardware Adapter seam。

### Orbit

- Watch Face、Quick Focus、Active、pause/resume/complete、local saved。

### Station

- Living Desk、encoder、Active、display 狀態；optional sensor 尚可缺席。

### 完成條件

各自 20 次斷電後 queue/phase 恢復；不需要 Cloud 也能證明本地 durability，但不宣稱
reward 已完成。

## R2｜Android BLE 與 Cloud 閉環（P0）

- protocol v2 profile/capabilities。
- exact context revision、correlation、control lease、durable App outbox。
- Orbit personal E2E、Station room E2E、lost ACK/revoke。
- App `My devices` 顯示兩台狀態。

### 完成條件

兩台各自 device-verified；Cloud 只有單一 Receipt/Reward，room scope 正確。

## R3｜完整體驗版（P1）

### Orbit

- Today、角色狀態、Recovery、安全通知、Sync center、privacy glance。

### Station

- VEML7700、LED、buzzer、Rest Coach、Room Portal、Character Stage、self-test。

### 跨端

- App/PWA/Web canonical session observer；同 session 單一 controller。
- Living Home 與裝置 presentation snapshot 一致。

### 完成條件

第一次使用者不看工程文件完成 personal + room 活動；optional fault 有 degraded mode。

## R4｜內容與關係世界（P1/P2）

- Daily beat、weekly chapter、milestone memory、asset fallback。
- family tree/group planet/Room Campfire 的安全摘要。
- 非同步 support acknowledgement；不發 reward、不監控。
- Orbit/Station 不同構圖但同狀態語言。

### 完成條件

內容由 canonical source 驅動；pending/rejected 不解鎖；consent/revoke 測試通過。

## R5｜雙裝置接續（P2）

- controller visibility、lease transfer、read-only observer。
- 若安全可行才做 mid-session transfer；否則只做 session 間切換。
- dual-device race、offline、stale lease、firmware compatibility。

### 完成條件

使用者能辨識 controller；衝突不重複 event/reward、不遺失 journal。

## R6｜產品化硬體（P2）

### Orbit

- protected battery feasibility、low power、熱、續航、外殼、腕帶；非防水仍明示。

### Station

- 焊接板、可維修外殼、導光、採光窗、24h soak。

### 平台

- device claim/key、signed event/timestamp policy、verified wipe、signed OTA。

### 完成條件

安全／可靠性／security ADR 與證據完整；否則仍稱 prototype。

## 功能評分方法

每個候選 1–5 分：

| 維度 | 問題 |
| --- | --- |
| Core value | 是否縮短開始行動或強化有意義回應？ |
| Evidence reuse | 是否重用 Ledger/Membership/catalog，而非新真相？ |
| Device fit | 是否真的適合圓屏／桌機？ |
| Reliability | 失效時核心是否可繼續？ |
| Privacy | 是否最小資料、可同意／撤回？ |
| Cost | pin、電源、記憶體、外殼、開發時間？ |
| Testability | 是否有可自動／實機驗收的 Interface？ |

Core value、Reliability、Privacy 任一低於 3，不進當前版本。

## 候選排序

| 功能 | 版本 | 理由 |
| --- | --- | --- |
| Orbit quick focus | R1 | 圓屏最核心用途 |
| Station encoder focus | R1 | 桌面主流程 |
| exact revision/journal | R1/R2 | 資料可靠前置 |
| App My devices | R2 | 兩台可理解／維護 |
| Station ambient/LED/buzzer | R3 | 充分使用已購周邊 |
| Orbit recovery/character | R3 | 增加陪伴而不增硬體 |
| Room Campfire | R4 | 同儕誘因且低監控 |
| stories/collectibles | R4 | 長期內容，需 canonical source |
| mid-session transfer | R5 | 複雜且非核心，先證明必要性 |
| Orbit battery | R6 | 安全獨立里程碑 |
| presence/IMU extras | proposal | 型號、隱私、價值未確認 |
| heart rate/SpO2 | deferred | 不符合目前產品／安全範圍 |

## 停止條件

- 核心 display/BLE/journal 不穩時，停止內容動畫與新 sensor。
- optional feature 造成 brownout、input latency 或 duplicate event，先移除 feature。
- 使用者無法分辨 pending/accepted 或 controller，停止跨端擴充。
- 隱私撤回無法立即生效，停止關係內容發布。
- 電池有異常溫升／膨脹／無保護，停止配戴測試。

## 版本宣稱

- R0/R1：硬體 bring-up／本地原型。
- R2：App-mediated device integration prototype。
- R3/R4：完整體驗 prototype。
- R5：雙裝置 continuity prototype。
- R6 且安全/security gate 完成後，才討論產品化；不能提前宣稱商用品質。
