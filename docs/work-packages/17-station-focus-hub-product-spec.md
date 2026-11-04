# 17｜Nudge Station 方形桌上專注中樞產品規格

## 一句話

Nudge Station 是一台以方形螢幕、可按壓旋鈕、環境光、導光 LED 與提示音構成的
桌上專注中樞，讓使用者看見下一步、選擇一個獲授權房間並完成可同步的活動。

## 產品邊界

### v1 要做到

- 方形首頁同時呈現角色、下一步、selected context、連線與待同步狀態。
- 旋鈕選擇最多三個已授權房間；短按開始／暫停／繼續，長按完成。
- VEML7700 調整螢幕與 LED 的 presentation brightness。
- WS2813 LED stick 顯示 offline/ready/active/paused/complete/rest 六種狀態。
- Qwiic buzzer 播放低音量短 cue，App quiet setting 可立即停用。
- USB 5V/2A 穩定供電、外殼採光窗、導光件與可維修接線。
- 事件 journal、BLE、App outbox、Cloud Receipt、Web/room/character 閉環。

### v1 不做

- 不用相機、麥克風或人體感測監控使用者。
- 感測器不直接判定「有沒有專心」，不自動替使用者完成活動。
- 不顯示家庭／團體成員精確健康值或誰正在被監控。
- 不在 Station 編輯完整任務、管理成員、購買角色或改權限。

## Gate 0：方形螢幕未確認

目前專案沒有方形螢幕的精確商品型號、driver IC、解析度、觸控、供電與 pin map。
組員第一項任務不是寫 UI，而是完成：

- 主控與螢幕正反面清楚照片、所有絲印和接頭。
- 商品頁／原廠 wiki／datasheet。
- driver IC（例如 ST77xx/ILI9xxx 只能在實物證據後填）、解析度、色序、rotation。
- interface（SPI/parallel/RGB）、邏輯電壓、背光電流與是否含 level shifter。
- ESP32 variant、Flash/PSRAM、可用 GPIO、USB serial identity。
- 螢幕是否和主控一體、是否含 touch/SD/LED/按鍵以及它們的共享 pin。

沒有以上資料，不提供任何「接 D 幾」的指令。

## 已確認的周邊候選

| 周邊 | Interface | 用途 | 原理／限制 |
| --- | --- | --- | --- |
| Adafruit PID 5880 encoder | I²C `0x36`, 3.3V | 選房、按壓控制 | seesaw MCU 將旋鈕轉為 I²C 事件 |
| VEML7700 | I²C `0x10`, 3.3V | 環境光與自動亮度 | 量測 lux；只改 presentation |
| Qwiic Buzzer | I²C `0x34`, 3.3V | 短提示音 | 非音樂／語音；quiet mode 必須有效 |
| WS2813 LED stick | 單線 data + 5V | 狀態與進度導光 | 5V data high 規格需 74AHCT/HCT level shifter |
| 5V/2A USB 電源 | power | 長時間穩定供電 | LED 與 ESP32 共地；GPIO 不供大電流 |

I²C 裝置可共用 SDA/SCL，因為每個 address 不同；但多塊 Qwiic pull-up 並聯可能
過強，組裝後要量測等效阻值，依板上 jumper 保留足夠的一組。

## 使用流程

### 首次設定

1. Web staff 將 Station `deviceId` 指派給帳號和最多三個允許房間。
2. Android App 讀取 hardware profile，驗證 assignment。
3. App 送房間、個人目標、角色 snapshot、quiet setting 和 context revision。
4. Station NVS commit 後回 exact revision，顯示 ready。
5. 執行螢幕、旋鈕、光感、LED、buzzer 的互動式 self-test。

### 日常流程

1. 首頁顯示一個下一步；旋鈕可切換 personal/allowed room。
2. App 取得 correlation/control lease；Station configure 時凍結當下選擇。
3. 短按開始；LED 顯示進度，螢幕顯示倒數和角色。
4. 短按暫停／繼續；長按完成。
5. 裝置先 journal event，App durable enqueue 後 ACK；Cloud accepted 後顯示成果。
6. 未選房就是 personal；不得自動散布到全部允許房間。

## 方形畫面資訊架構

### Ready

- 左上：角色與 level/stage。
- 右上：BLE、Cloud sync、pending、brightness/quiet 小圖示。
- 中央：下一步／personal goal。
- 下方：旋鈕目前選擇及「按下開始」。

### Active

- 大字倒數或已過時間。
- progress bar／ring，選一種即可。
- 房間 label、角色短動畫、LED 同步進度。
- 不顯示商城、排行榜或其他成員精確數據。

### Pause/Complete/Rest

- Pause 顯示繼續與長按完成提示。
- Complete 分成 `saved locally`、`waiting app`、`cloud accepted` 三態。
- Rest 降低亮度與動畫，提供下一次建議但不自動開始。

### Diagnostics

- 顯示 firmware/profile、I²C address 結果、sensor fault、安全 rail 資訊。
- 完整 raw log 走 serial；一般畫面不顯示 UID/token/JSON。

## 感測與回饋原理

### 環境光

每秒取樣 lux，使用 EWMA 平滑，加入上下限與 hysteresis，避免手影或燈光閃爍導致
亮度跳動。sensor fault 使用固定安全亮度；不阻擋計時。

### LED

WS2813 每顆燈透過單線時序接收顏色，再將後續資料轉給下一顆。ESP32 只提供 data，
5V rail 提供電流。level shifter 確保 logic high，導光件讓亮點變成均勻光帶。

### Buzzer

使用少量固定 cue（start/pause/complete/error），不播放訊息內容。安靜時段和 App
quiet setting 優先；buzzer 缺席不阻擋核心功能。

### Encoder

旋轉是選擇，短按是 lifecycle toggle，長按是完成。按鍵 debounce、long-press 閾值
與 command queue 順序都在 Input Adapter 統一處理，畫面不自行解讀 GPIO。

## 外殼與可維修性

- 方屏、旋鈕與導光窗位置先用紙板／3D 草模驗證視角與手感。
- VEML7700 有獨立採光窗，不能被螢幕、LED 或不透光外殼遮住。
- Buzzer 保留聲孔但不直接朝向使用者；音量保持低。
- LED、主控、螢幕電源線分支清楚，共地且有應力釋放。
- 外殼可拆，不用熱熔膠永久封死 USB、排針和量測點。

## 成功指標與驗收摘要

- 新使用者不看工程教學完成一次 personal focus 和一次 room focus。
- 旋鈕 500 次動作無重複或漏掉的 lifecycle transition。
- 三段光照亮度平順，sensor 拔除後 fallback。
- 30 分鐘高亮 display + LED + buzzer 混合負載無 brownout/過熱。
- 斷電、斷 BLE、App killed、lost ACK 後 Cloud 仍只有一個 settlement。
- 撤銷 assignment 和 stale lease 皆 fail closed。
