# 03｜Demo 韌體架構

## 目標

用一套可重播的場景引擎驅動兩種螢幕，不把正式 Cloud、帳號、裝置指派與 Ledger
變成 Demo 的依賴。現有 `firmware/nudge_focus_device` 可重用專注狀態與
PlatformIO 基線，但展示畫面必須能獨立運作。

## 架構

```text
DemoScenario
  ├─ scene / elapsed / autoPlay / demoData
  ├─ InputAdapter
  │    ├─ AutoTimerInput
  │    ├─ ExistingButtonOrTouchInput
  │    └─ OptionalSerialInput
  ├─ DisplayPort
  │    ├─ OrbitRoundDisplay
  │    └─ StationSquareDisplay
  └─ OptionalEffectPort
       ├─ ExistingLedEffect
       ├─ ExistingLightSensor
       └─ ExistingBuzzer
```

## 必要狀態

```cpp
enum class DemoScene {
  boot,
  home,
  ready,
  focus,
  encouragement,
  complete,
  growth,
  summary,
};
```

場景切換只接受：

- `next()`
- `previous()`（可選）
- `restart()`
- `tick(nowMs)`

場景不可直接呼叫 Firebase、BLE 或 Web API。選配連動只能把事件轉成上述四種命令。

## 必要資料模型

```cpp
struct DemoData {
  const char* userName;
  const char* characterName;
  int characterLevel;
  int disciplineScore;
  const char* primaryTask;
  const char* roomName;
  const char* encouragement;
  int focusMinutes;
  int demoXp;
};
```

資料編譯在韌體內，不保存真實帳號或健康資料。畫面中若包含模擬群組人數、
步數、睡眠等，固定顯示 `DEMO` 標記。

## 兩台裝置的編譯設定

目標狀態是在 `platformio.ini` 建立兩個清楚的 environment：

```ini
[env:orbit_demo]
; XIAO ESP32S3 + 已購買圓形螢幕
build_flags =
  -DNUDGE_DEMO=1
  -DNUDGE_DEVICE_ORBIT=1

[env:station_demo]
; XIAO ESP32S3 + 已購買方形螢幕
build_flags =
  -DNUDGE_DEMO=1
  -DNUDGE_DEVICE_STATION=1
```

實作者必須依實際螢幕型號補 driver；不能把上述範例當成已存在的可用設定。

完成後的命令應是：

```sh
pio run --project-dir firmware/nudge_focus_device -e orbit_demo
pio run --project-dir firmware/nudge_focus_device -e orbit_demo -t upload

pio run --project-dir firmware/nudge_focus_device -e station_demo
pio run --project-dir firmware/nudge_focus_device -e station_demo -t upload
```

若短期內共用專案會破壞已可工作的圓屏，允許先建立
`firmware/nudge_orbit_demo` 與 `firmware/nudge_station_demo` 兩個最小專案，
比賽後再合併。競賽前以可靠為優先。

## Scene 時間軸

- Boot：1500 ms
- Home：4000 ms
- Ready：3000 ms
- Focus：15000–20000 ms
- Encouragement：5000 ms
- Complete：4000 ms
- Growth：5000 ms
- Summary：停留，或 8000 ms 後回 Home

時間使用 `millis()` 的差值，不使用阻塞式長 `delay()`。如此才能持續讀取
按鍵、觸控與 serial，也避免動畫卡住。

## 自動與手動模式

- 長按既有按鍵或收到 serial `R`：重新開始。
- 短按／觸控或收到 serial `N`：下一幕。
- 開機 5 秒沒有輸入：啟動自動 Demo。
- 任一外接周邊初始化失敗：記錄 serial 訊息後繼續自動 Demo。

## 螢幕 Adapter 的最低介面

```cpp
class DemoDisplay {
 public:
  virtual bool begin() = 0;
  virtual void render(const DemoFrame& frame) = 0;
  virtual void showFatal(const char* shortCode) = 0;
  virtual ~DemoDisplay() = default;
};
```

每個 `render` 收到已整理的 ViewModel，不自行決定業務狀態。Orbit 可把資訊
壓成一個中心數字與一個底部標籤；Station 可顯示任務、角色與關係卡片。

## 圖形資源規則

- 圖示與角色轉成程式可讀的 RGB565／bitmap 資源。
- Orbit 與 Station 共用角色名稱、顏色 token 和 Scene ID。
- 文字太小時優先縮短文案，不要一直縮字體。
- 中文字型若無法在實機穩定顯示，Demo 先用短英文標籤搭配圖示；簡報中文解說。
- 每個資源記錄來源與授權，不把網路圖片直接嵌入韌體。

## 不阻擋畫面的錯誤策略

| 元件失敗 | 韌體行為 |
| --- | --- |
| LED | 略過 `begin`，螢幕照常 |
| 光感 | 使用固定亮度 |
| 蜂鳴器 | 靜音 |
| 按鍵／觸控 | 自動輪播 |
| BLE | 本機 Demo |
| Station driver | 顯示最小色塊測試，停止接其他周邊，回報型號 |

## Logging

Serial 每次只需要輸出：

```text
NUDGE_DEMO boot device=orbit build=<git-sha>
display begin ok
optional led skipped
scene 0 boot
scene 1 home
...
```

不要每個 frame 洗版。錯誤包含短代碼，方便現場快速判讀。

## 測試

### Host

- Scene 順序固定。
- `restart()` 從任何 scene 回 boot。
- 自動時間軸不跳過 complete。
- Optional port 失敗不改變場景流程。
- Orbit／Station 接收相同 Scene ID，但產生不同 Layout。

### 實機

- 每個 environment 都能 compile 與 upload。
- 冷啟動 3 次皆出現 Boot，不停在白屏。
- 自動播放 10 次。
- 手動 next／restart 各 10 次。
- 拔掉所有 P1 周邊後仍可展示 P0。

## 交付

- source 與兩個 PlatformIO environment。
- `orbit_demo.bin`、`station_demo.bin` 或等價 PlatformIO artifacts。
- 完整 build log。
- Scene 對照截圖。
- 兩台實機影片。
- 已知限制與比賽日燒錄命令。

## 明確不做

- 正式裝置註冊、Cloud 權限、Ledger reward minting。
- OTA、Wi-Fi provisioning、加密 key。
- 因正式架構漂亮而重寫已能展示的 driver。
- 為了共用 100% 程式碼而犧牲任一台的穩定畫面。

