# 25｜感測器智慧、環境適應與行為規則

## 原則

感測器只能增加便利與呈現品質，不能在沒有正式 evidence policy 時替使用者判定
是否專心、是否睡覺、是否完成任務。Sensor observation、presentation decision 與
Activity Ledger evidence 必須是三個不同概念。

## 分層

```text
Hardware reading
  → calibration / filtering
  → SensorSnapshot + quality
  → PresentationPolicy
  → brightness / cue / diagnostic

不直接 → ActivityEvent / Reward / room contribution
```

## VEML7700 環境光

### 功能

- 自動調整 Station display/LED brightness。
- 夜間降低刺激；強光提高可讀性。
- 診斷外殼採光窗是否被遮住。

### 處理

- 1 秒採樣；warm-up 後才使用。
- 保存 raw lux、filtered lux、quality、timestamp，不保存長期環境歷史。
- EWMA 平滑 + dark/indoor/bright hysteresis；輸出百分比受 firmware min/max 限制。
- 突然手遮不立刻熄屏；持續改變才跨級。
- timeout、NACK、out-of-range 使用固定安全值並上報 degraded fault。

### 驗收

- 三段可重現光照、外殼前後重新校正。
- 連續 1000 samples 無 bus lock；拔除後核心正常。
- 手機 flashlight 不造成 LED 過亮或高頻跳動。

## Encoder／觸控輸入

輸入不是傳統 sensor，但同樣需要 filtering：

- encoder debounce、detent delta、短／長按、按住旋轉。
- touch press/release、edge zone、swipe threshold、palm/accidental touch timeout。
- raw observation 轉 `InputEvent`；core 依 phase 決定 action。
- action dispatch 後有 feedback，避免使用者因延遲重複操作。

## RTC 與時間

- RTC：watch face／離線 wall time。
- epoch anchor：事件稽核顯示，由 App 同步。
- monotonic time：活動 elapsed/remaining 的唯一計時來源。
- RTC 漂移或跳時不改 active countdown；App 可在 idle 更新 wall time。

## 電量與電源（能力確認後）

- Orbit battery voltage 只在有官方量測路徑、分壓與校正後提供估算。
- 百分比需要 discharge curve 和負載補償；v1 可先用 coarse low/medium/high。
- 低電優先降低 presentation；不跳過 journal、不刪 pending。
- Station 可監控 brownout/reset reason，但沒有電流感測器時不捏造即時功耗。

## 可選感測器評估框架

任何新 sensor 先回答：

1. 它改善哪一個明確使用者流程？
2. 原始讀值是否需要校正、通風、安裝角度或距離？
3. 是否涉及健康、在席、行為監控或旁人資料？
4. 缺席／失效時核心能否繼續？
5. pin、address、pull-up、電源、熱與外殼成本？
6. 資料在裝置、App、Cloud 各保存多久？
7. 它只改 presentation，還是要成為 evidence？後者必須另立 ADR/abuse policy。

## 候選能力

### 溫濕度

只有 Station 有獨立通風腔、遠離 ESP32/display/LED 自熱並完成校正才考慮。可用於
一般環境舒適提示，不作健康判斷、不自動結束活動。

### 人體存在／毫米波

不納入 v1。若未來研究，預設只在裝置本地形成「可能有人／無人」且可關閉；不
識別人、不保存時序到 Cloud、不替使用者判定專心。需要清楚可見的感測狀態。

### IMU

Orbit 只有硬體真的內建且資料品質驗證後，才可做 wrist raise／gesture；不自行
宣稱步數準確。gesture 可作 presentation，不作 activity reward evidence。

### 心率／血氧

不納入 Nudge Orbit 原型；涉及貼膚光學、校正、運動 artefact、醫療暗示、隱私和
電源。沒有完整研究與法規策略前不加入。

## `SensorModule` Interface

```cpp
struct SensorReading {
  SensorKind kind;
  float value;
  SensorQuality quality;
  MonotonicMillis sampledAt;
};

SensorSnapshot sampleSensors(MonotonicMillis now);
PresentationAdjustments decidePresentation(
  SensorSnapshot snapshot,
  UserPresentationPreferences preferences);
```

兩個 Interface 分離，讓測試可證明 raw reading 不會直接形成 ActivityEvent。

## 測試與資料品質

- known input/calibration、range、precision、warm-up、drift。
- NACK、timeout、stuck value、NaN/outlier、clock gap。
- sensor missing at boot、runtime disconnect、reconnect。
- user override 與 auto mode precedence。
- quiet/reduced-motion/low-power 的組合。
- privacy test：raw sensor history 不出現在 export 外的未知 collection/log。

## 功能狀態

- VEML7700：Station P1，已知硬體候選。
- encoder/touch/RTC：P0 核心輸入／時間。
- battery sensing：Orbit P2，視實際板與電池設計。
- IMU/temperature/presence：proposal，未確認硬體和政策。
- heart rate/SpO2：explicitly deferred。
