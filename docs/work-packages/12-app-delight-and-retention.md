# 12｜App 吸引力、角色回應與留存循環工作包

## 問題判斷

目前 App 已有任務、專注、健康、自律房、角色、商城、家庭、團體、分析、通知和
裝置等大量功能，但它們主要以功能頁存在。使用者打開 App 時看到的是「可以去
哪些地方」，而不是「現在最值得做什麼、完成後世界會有什麼回應」。枯燥感不一定
來自功能太少，而是缺少一條有情緒、有期待、可恢復的每日核心循環。

## 新的核心體驗：Living Home

首頁改成一個會隨正式資料改變的「生活場景」，而不是卡片集合：

1. **角色現在的狀態**：ready、陪伴中、休息、等待同步、恢復中。
2. **一個主要行動**：根據使用者已選目標顯示最小下一步，永遠只有一個主 CTA。
3. **共同世界入口**：目前選定家庭樹、團體星球或房間營火的一個小視窗。
4. **同步真相**：本機 pending 與 Cloud accepted 清楚分開。
5. **使用者出口**：可以按「今天到這裡」，不以連勝、紅點或 guilt 阻止離開。

## 每日吸引力循環

```text
回來看角色 → 選一個最小行動 → 3 秒進入準備儀式 → 自主完成
     ↑                                             ↓
休息／恢復 ← 選擇下一步或結束 ← Cloud Receipt 後的世界回應
```

### 0–3 秒：立即可懂

- 首頁只說一句角色短句和一個 CTA，例如「先陪我專心 5 分鐘」。
- 不先要求整理所有任務、加入團體或綁定裝置。
- 已有 active session 時只顯示繼續，不建立第二個 session。

### 一次行動：看得到因果

- started accepted 後才進入正式活動狀態。
- completed 先顯示「等待 Cloud 確認」；Receipt 到達後才播放正式成長回應。
- 角色、家庭樹、團體星球各自只更新自己合法的 outcome，不重複 mint reward。

### 七天：形成故事而非壓力

- 用「本週旅程」呈現做過的不同小行動，不以斷掉的 streak 宣告失敗。
- 一段空白後提供 recovery ritual：縮短時間、換活動、改時段，使用者自己決定。
- 每週只解鎖一小段角色故事／環境變化，不用大量日常彈窗。

## 建議 Module 與 Seam

### `EngagementHomeModule`

```text
loadEngagementHome(userId, activeContext) -> EngagementHomeSnapshot
```

Snapshot 包含一個主行動、角色 presentation、同步狀態、選定關係的安全摘要和可用
recovery options。Module 內部可以讀多個既有 repository，但呼叫首頁只需學一個
Interface，避免 `home_page.dart` 直接拼接所有功能規則。

### `NextActionModule`

```text
suggestNextActions(canonicalSummary, userPreferences) -> up to 3 suggestions
```

第一版使用透明規則並回傳 reason；它不自動建立任務、不修改目標、不讀未同意
健康資料。首頁只選一個主要建議，其餘放在「換一個」中。

### `CelebrationModule`

```text
presentAcceptedOutcome(previousSnapshot, acceptedSnapshot) -> CelebrationPlan
```

只接受 Cloud accepted 的前後差異，回傳動畫、聲音、文字和 reduced-motion 替代。
Implementation 必須去重 Receipt，避免重開頁面重播、重發通知或重複顯示獎勵。

### `RecoveryModule`

```text
buildRecoveryOptions(privateIdentitySnapshot) -> RecoveryPlan
```

輸出小而可選的行動，不能產生人格標籤、懲罰或對 guardian/manager 公開 private
recovery state。

## 可增加的吸引力功能

### A. 角色狀態與微互動（P1）

- 角色有少量可辨識狀態，而非無限隨機動作。
- 點角色可看到「為什麼是這個狀態」與下一步，不藏規則。
- 完成時用 1–2 秒微動畫、觸覺／音效和文字回應；支援關閉聲音及 reduced motion。
- 等待同步時角色呈現「正在帶回紀錄」，不先慶祝正式獎勵。

### B. 可變場景與收藏（P1）

- 個人場景依最近 28 個 discipline days 的正式成果逐步變化。
- 收藏的是「走過的片段、回憶、裝飾」，不是隨機抽卡或付費數值優勢。
- archived catalog 資產有 fallback，舊回憶不因上架結束而破圖。

### C. 活動前的準備儀式（P1）

- 3 秒選擇：時間、個人／一個獲授權房間、是否安靜。
- 使用最近選擇作預設，但每次可改；選擇房間不等於授權，App 仍驗證 assignment
  和 Membership。
- 有實體裝置時把同一 presentation context 送到裝置，exact revision 後才 ready。

### D. 行動後的「世界回應」（P1）

- 個人：角色 XP／場景變化。
- 家庭：樹或共同回憶有一個小變化，但只有合法 bond event 才生成。
- 團體：星球增加共同建設，不公開誰做了多少精確數值。
- 自律房：共同週期推進，成員可 opt-in 發 resonance。

一筆 Receipt 可驅動多個合法 projection，但只能有一次個人 reward settlement。

### E. 恢復模式（P1）

- 偵測近期沒有有效行動時，不顯示「連續中斷」警告。
- 只提供三種小選項：5 分鐘重啟、換一種活動、今天休息並排明天。
- recovery 完成也有角色回應，但不補發過去不存在的 coin/XP。

### F. 同儕接力與故事（P2）

- 使用工作包 08 的非同步接力 Quest：每人自行選擇時間和任務。
- 完成只點亮共同故事的一段；管理者不能代做，未完成不懲罰下一位。
- 先驗證三日參與與撤回分享，再擴大季節活動。

## 角色情境差異

| 情境 | 首頁應突出 | 不應突出 |
| --- | --- | --- |
| 個人 | 一個下一步、角色、同步狀態 | 所有統計和商城促銷 |
| child | 自己的選擇、已同意共同目標 | guardian 監控語氣 |
| guardian | 提出陪伴、共同成果 | 精確健康值、替 child 完成 |
| member | 自主 Quest、團體世界、退出／靜音 | manager 命令式待辦 |
| manager | 團體設定與邀請的次要入口 | 代填成員活動 |

## 實作切片

### 切片 1｜Living Home 骨架

- 在 `lib/screens/home_page.dart` 建立單一 `EngagementHomeSnapshot` 渲染路徑。
- 先重用現有 AppState repository，不先搬動所有底層資料。
- Widget tests 覆蓋 loading、empty、pending、accepted、recovery、stale Membership。

### 切片 2｜主行動與三秒儀式

- 接到既有 focus／task／room lifecycle。
- active session 去重；錯誤、離線、撤銷能力有明確回復。
- 埋點只量測安全的 funnel state，不存任務文字或健康明細。

### 切片 3｜Cloud accepted Celebration

- 以 Receipt/outcome snapshot diff 驅動，實作去重與 reduced-motion plan。
- 驗證重開、跨端同步、舊 Receipt 不重播。

### 切片 4｜角色場景與關係窗景

- 串接角色 catalog、discipline identity、family/group outcome、room resonance。
- 權限消失或 catalog archived 時安全降級，不保留越權快取。

### 切片 5｜裝置連續體驗

- App 與實體裝置顯示同一安全 snapshot 和狀態語言。
- Android BLE 閉環完成前，裝置區塊維持 source-verified 標示，不假裝已連線。

## 視覺與動態原則

- 一個主色背景場景、一個主要角色、一個主 CTA；降低卡片和選單密度。
- 動畫有明確因果：開始、同步、accepted、recovery；不做持續搶注意的粒子。
- 60fps 優先使用 transform/opacity，低階裝置與省電模式提供靜態版。
- 所有狀態都有文字／圖示，不只靠顏色；支援文字放大、TalkBack/VoiceOver。
- 音效與觸覺預設克制、可分別關閉；quiet hours 同步套用 App 和裝置。

## 驗證指標

- 新使用者從登入到第一筆 accepted Receipt 的完成率與時間。
- 首頁主 CTA → started accepted → completed accepted 的 funnel。
- Receipt accepted 後 7 日內第二次有效行動率。
- recovery suggestion 被選擇後 48 小時內的小行動完成率。
- 動畫關閉率、通知關閉率、被拒事件率與重複 Receipt 率作護欄。

每個實驗先定 success 和停止條件；若留存提高但通知關閉、焦慮回饋或無效事件也
明顯上升，就不能算成功。

## 明確不做

- 不做抽卡、付費戰力、隨機 loot、倒數威脅或無法關閉的 streak。
- 不用假進度或先播放獎勵掩蓋 pending Cloud 狀態。
- 不讓 AI、guardian、manager 或 device 替使用者自動開始／完成活動。
- 不因追求漂亮首頁再建立一份本機 XP、Membership 或角色 catalog 真相。
