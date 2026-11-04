# 14｜雙裝置共用韌體架構與協定

## 目標

保留 `firmware/nudge_focus_device` 已有的 portable C++ 狀態機、protocol、context、
journal 與視覺語意，將目前集中在 `src/main.cpp` 的 Round Display／Arduino 細節拆成
Adapter。兩台硬體使用同一個核心，不複製兩份容易分歧的活動規則。

現在有兩個真實硬體 Adapter，因此 display/input/sensor/presentation 的 Seam 已不再
是假設；但不要為未購買的第三種裝置建立更多抽象。

## 建議目錄

```text
firmware/
  nudge_device_core/
    include/nudge/          # portable Interfaces、模型、狀態機
    src/                    # 不依賴 Arduino 的 Implementation
    test/native/            # host tests
  nudge_orbit/
    platformio.ini
    src/main.cpp
    src/orbit_*.cpp         # 圓屏／觸控／RTC／電源 Adapter
  nudge_station/
    platformio.ini
    src/main.cpp
    src/station_*.cpp       # 方屏／旋鈕／感測器／LED／蜂鳴器 Adapter
```

第一個重構 PR 可先保留原路徑，使用 library dependency 引用 core；確認 build 和
host tests 都通過後再移動檔案，避免「重構 + 新功能 + 新板子」同時發生。

## 核心 Module

### `FocusLifecycleModule`

```cpp
TransitionResult configure(FocusConfiguration config);
TransitionResult dispatch(FocusAction action, MonotonicMillis now);
FocusSnapshot snapshot(MonotonicMillis now) const;
```

負責 phase、倒數、暫停時間和合法 transition。它不畫螢幕、不讀按鈕、不寫 BLE。

### `DeviceContextModule`

```cpp
ContextResult replace(DeviceContextSnapshot candidate);
ContextResult selectRoom(RoomContextId roomId);
const DeviceContextSnapshot& snapshot() const;
```

負責 exact monotonic `contextRevision`、最多房間數、角色安全快照、sound preference。
Adapter 只有在 durable store 成功後才能回報 revision。

### `DurableEventModule`

```cpp
EnqueueResult transitionAndCommit(FocusAction action);
std::optional<ActivityEvent> queueHead() const;
AckResult acknowledge(EventId exactHead);
```

負責 stable event ID、sequence high-water、最多八筆 queue、雙槽 journal 和 power-loss
恢復。這是兩台裝置最重要的可靠性 Module。

### `PresentationModule`

```cpp
PresentationFrame present(DeviceSnapshot state, CapabilitySet capabilities);
```

輸出與像素無關的 frame：phase、remaining、progress、角色狀態、room label、sync、
brightness、cue。Orbit/Station 各自把 frame 轉成不同畫面、燈光和聲音。

### `ControlLeaseModule`

```cpp
LeaseResult applyLease(DeviceControlLease lease);
bool mayControl(SessionId sessionId, EpochMillis now) const;
```

防止 Orbit、Station、App 同時控制同一 session。Cloud/App 發行短期 lease；裝置離線
只能繼續已配置 session，不能自行搶另一台裝置的 lease。

## Hardware Interfaces 與 Adapter

```cpp
struct DisplayPort {
  virtual DisplayInfo info() const = 0;
  virtual RenderResult render(const PresentationFrame&) = 0;
};

struct InputPort {
  virtual std::vector<InputEvent> poll(MonotonicMillis now) = 0;
};

struct IndicatorPort {
  virtual void apply(const IndicatorFrame&) = 0;
};

struct SensorPort {
  virtual SensorSnapshot sample(MonotonicMillis now) = 0;
};

struct JournalPort {
  virtual LoadResult load() = 0;
  virtual CommitResult commit(const JournalSnapshot&) = 0;
};
```

| Interface | Orbit Adapter | Station Adapter |
| --- | --- | --- |
| DisplayPort | GC9A01 round renderer | 待 Gate 0 確認的 square renderer |
| InputPort | touch／單鍵 fallback | I²C encoder + press |
| IndicatorPort | 螢幕動畫／可選小燈 | WS2813 stick + backlight + buzzer |
| SensorPort | battery/RTC（確認後） | VEML7700，其他僅在型號確認後 |
| JournalPort | ESP32 Preferences/NVS | ESP32 Preferences/NVS |
| TransportPort | BLE GATT v2 profile | BLE GATT v2 profile |

## Device profile 與協定 v2

不要破壞現有 v1；先讓 App 同時支援 v1 和 v2，兩台新韌體穩定後才停止新指派 v1。

### 裝置宣告（read-only）

```json
{
  "protocolVersion": 2,
  "deviceId": "server-bound-id",
  "hardwareProfile": "orbit_round_v1",
  "firmwareVersion": "0.2.0",
  "capabilities": ["touch", "rtc", "focus_control", "character_snapshot"],
  "display": {"shape": "round", "width": 240, "height": 240}
}
```

Station capability 可包含 `encoder`、`ambient_light`、`led_strip`、`buzzer`；capability
只描述能做什麼，不授予 actor、room 或 reward 權限。

### 共用 state

```json
{
  "v": 2,
  "phase": "ready",
  "remaining": 1500,
  "pending": 0,
  "contextRevision": 42,
  "selectedRoomId": "room-safe-id",
  "leaseRevision": 7,
  "faults": []
}
```

### 必守 ordering

1. App 驗證 assignment 與 device profile。
2. App 送 context + revision；裝置 NVS commit 後回相同 revision。
3. App 取得 Cloud correlation 與 control lease，才送 configure。
4. 裝置 input 觸發 transition，先 journal commit 再 notify。
5. App 驗證 assignment/lease/room，耐久 enqueue outbox 後 ACK exact queue head。
6. Cloud Receipt 到達後，App 才更新正式 reward/outcome presentation snapshot。

## 原理說明

### 為什麼用 monotonic clock

ESP32 的 wall clock 可能因重開、RTC 或手機同步跳動；活動倒數使用只會向前的
monotonic time，避免時間倒退。epoch 只作事件稽核顯示，由 App 配置 anchor。

### 為什麼先 journal 再通知

若先通知再寫 flash，斷電會讓 App 以為事件存在、裝置卻遺失。先 durability、後
visibility 可讓重送安全，代價是 flash 寫失敗時不發布事件。

### 為什麼 ACK 只能移除 queue head

順序 ACK 讓 journal 狀態簡單且可驗證；亂序刪除可能在斷電恢復後跳過未送事件。
stable ID + Cloud idempotency 讓遺失 ACK 只造成重送，不重複 reward。

### 為什麼 sensors 不能直接改活動結果

環境光只應調整 presentation；在席或移動感測若未有正式 evidence policy，不得自動
結束、增加分鐘或判定專注。這避免錯誤感測直接改寫 Ledger。

## 重構順序

1. Characterization tests 鎖定現有 v1 行為。
2. 抽出 portable core，不改 JSON 或 BLE UUID。
3. 現有 Round firmware 改用 Adapter，確認 host/build 行為相同。
4. 新增 v2 device profile read characteristic 和 parser tests。
5. 新增 Orbit Adapter；再新增 Station Adapter。
6. App 支援 capability-driven UI 和 control lease。
7. 實機證據完成後才更新 default protocol。

## 測試

- native：所有 lifecycle、時間、queue、journal corruption、context/lease revision。
- golden：同一 `PresentationFrame` 的 Orbit/Station 佈局語意，不比較每個像素細節。
- protocol：v1/v2 encode/decode、未知 capability、oversize、UTF-8、MTU fail closed。
- fault injection：NVS commit 失敗、lost ACK、重開、stale lease、sensor/display 缺席。
- build：兩個 PlatformIO env 各自乾淨編譯，禁止互相偷用對方 pin macro。

## 非目標

- 不在 common core include TFT、Wire、BLE、Preferences 或特定 Arduino driver。
- 不建立一個塞滿 `if (round) ... else ...` 的巨大 `main.cpp`。
- 不讓 capability 或 profile 名稱成為 Cloud 權限。
