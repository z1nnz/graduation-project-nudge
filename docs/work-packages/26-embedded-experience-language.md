# 26｜雙裝置視覺、動態、燈光、聲音與觸覺語言

## 目標

讓 Orbit 圓屏、Station 方屏、LED、聲音與 App 看起來是同一個 Nudge 系統，同時
尊重不同形狀和使用距離。設計語言服務狀態理解與情緒回應，不用持續動畫搶走
專注力。

## 核心語意

| 語意 | 形狀／動態 | 色彩方向 | 聲音 | 原則 |
| --- | --- | --- | --- | --- |
| ready | 緩慢呼吸 | 柔和主色 | 無 | 可開始、不催促 |
| preparing | 收斂／聚焦 | 中性轉主色 | 可選短音 | 等 Cloud/lease |
| active | 穩定前進 | 低飽和進度 | start 一次 | 不持續刺激 |
| paused | 靜止間隔 | 暖中性色 | pause 一次 | 清楚可恢復 |
| local saved | 小循環／搬運 | 藍灰 sync | 無 | 尚未 accepted |
| accepted | 一次展開 | 明亮但短 | complete 一次 | 只在 Receipt 後 |
| rest | 緩慢下降 | 低亮綠／紫 | 可無 | 允許離開 |
| recovery | 小芽／小光 | 溫和 | 無 | 不羞辱 |
| fault | 穩定符號 | 高對比警示 | error 一次 | 不高頻閃爍 |

## 色彩 token

不要在每個 Adapter 寫任意 RGB。建立語意 token：

```text
surface/background
text/primary, text/muted
state/ready, active, paused, syncing, accepted, rest, warning, fault
character/accent
relationship/family, group, room
```

Orbit 以較少色彩和高對比為主；Station 可用背景與 LED 延伸，但同一 state token
語意相同。LED brightness 在 firmware 有 hard cap。

## Orbit 圓屏構圖

- 中央：一個主元素（時間／角色／倒數）。
- 外圈：一個連續量（progress），不疊多圈。
- 上下 anchor：最多兩個小狀態。
- 重要觸控區避開圓形四角／邊緣；文字按 safe circle 佈局。
- 長文字用短文案 key，不靠縮到無法閱讀。

## Station 方屏構圖

- 上方 status bar：connection/sync/quiet/brightness。
- 中央 primary stage：角色 + timer/next action。
- 下方 control hint/context；只有 diagnostics 才顯示密集資料。
- Active 時移除次要卡片，避免進度、房間、角色、感測器同時競爭。

## 動態原則

- state transition 動畫 150–600ms；celebration 最長約 1.5 秒且只播一次。
- active 只用低頻 progress/呼吸；不用持續粒子和快速 parallax。
- 使用 transform/opacity/frame sprite，避免每幀配置大型 bitmap 或 String。
- `reducedMotion`：用 crossfade、靜態圖和文字替代；不能直接刪除狀態回饋。
- frame drop 不得阻塞 BLE/input/journal；renderer 有固定時間 budget。

## LED 語言

- offline：低亮中性色慢呼吸。
- ready：穩定一段柔光。
- active：完成比例向前推進。
- paused：固定暖色，不閃爍。
- complete local：短 sync pattern，不用正式 celebration 色。
- accepted：一次由中心向外／由左至右完成動畫。
- rest：低亮靜態。
- fault：少量高對比段落 + display 文字，不用快速紅閃。

LED 是補充，不能成為唯一狀態來源；色覺差異者仍可讀 display。

## 聲音語言

- start/resume：短上行。
- pause：短下降。
- accepted complete：短而柔和的完成音。
- error：低音一次，不連續警報。
- room change：極短 tick，可在 quiet 關閉。

聲音非阻塞、音量上限、quiet hours、全局 mute。不同事件不可共享完全相同 cue，
但總數保持少，避免學習負擔。

## 觸覺

目前硬體未確認 vibration motor，所以不列 v1。若未來加入：

- 先確認 driver/transistor/flyback/電源，不由 GPIO 直接驅動 motor。
- 只對 confirm/error 提供短 pattern，可關閉；不在手腕持續震動。
- haptic Adapter 讀語意 cue，不解讀 ActivityEvent。

## 文字與語氣

- ready：「要先一起做 5 分鐘嗎？」
- waiting：「已留在裝置，連上手機後會送出。」
- accepted：「這次行動已被記錄。」
- recovery：「從小一點重新開始也可以。」
- fault：「需要手機協助同步。」

不使用「你失敗了」「偷懶」「被家長看到」「再不做就失去」等壓迫文案。

## Asset pipeline

- asset key/version/size/format/target profile/reduced-motion fallback。
- 圓屏／方屏分別裁切，不在 runtime 強行縮放同一張巨大圖。
- CJK 字集採實際文案 subset；未知 glyph 有 fallback，不顯示空方框。
- 編譯時檢查 asset manifest；runtime 缺失使用內建 default。
- 記錄 flash/PSRAM/RAM budget，不能因角色資產讓 journal/BLE 不穩。

## 測試

- 每個語意 state 在 Orbit/Station/display/LED/sound 的 mapping snapshot。
- accepted vs local-saved 明顯可辨。
- brightness 三段、color-blind grayscale、reduced-motion、mute/quiet。
- 30 分鐘 active renderer 壓力、heap、frame time、BLE/input latency。
- 中英文字、長 label、unknown character、asset missing/archive。

## 交付

- token 表、狀態 motion sheet、LED cue sheet、sound cue sheet。
- Orbit/Station 每個主要 state 的 static mock 和實機 capture。
- asset manifest、memory budget、fallback 表。
