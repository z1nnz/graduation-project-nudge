# Nudge Focus Companion 高規格樣機製作規格

狀態：韌體與 App 整合開發中；尚未完成實物組裝與實機驗收。
預算上限：NT$5,000；目標落點約 NT$4,200–4,900。商品、台灣優先連結與 2026-08-21 查核狀態見[最高規格採購清單](2026-08-21-top-spec-purchase-checklist-tw.md)；正式結帳前仍需重新確認庫存、運費與交期。

## 最終選定版本

這不是「把預算湊滿」，而是保留每個能明顯改善展示與使用體驗的元件：

| 子系統 | 選定零件 | 用途 | 預估成本 |
| --- | --- | --- | ---: |
| 主控 | Seeed XIAO ESP32-S3 預焊排針版 | BLE、狀態機、NVS、周邊控制 | NT$360–500 |
| 主顯示 | Seeed Round Display for XIAO `104030087` | 房間、倒數、角色、同步狀態 | NT$630–900 |
| 操作 | Adafruit I2C QT Rotary Encoder PID 5880 + 旋鈕帽 | 選房、開始、暫停、完成 | NT$320–450 |
| 主燈效 | Grove 10×WS2813 Mini LED Stick `104020131` | 六種狀態與進度導光 | NT$190–350 |
| 邏輯保護 | 74AHCT125 或等效 74HCT 3.3V→5V 位準轉換板 | 讓 5V WS2813 data 符合規格 | NT$80–250 |
| 環境光 | SparkFun VEML7700 Qwiic | 自動調整螢幕與燈條亮度 | NT$315–500 |
| 聲音 | SparkFun Qwiic Buzzer BOB-24474 | 短提示音與完成回饋 | NT$315–500 |
| 配線 | Qwiic 線材／分接、杜邦線、端子、小料 | 共用 I2C 與可靠接線 | NT$400–750 |
| 電源 | 有認證 5V/2A USB 電源與資料線 | 穩定供電與燒錄 | NT$350–650 |
| 外殼 | FDM 外殼、乳白導光件、螺絲與防滑墊 | 可拆修、遮光、展示完成度 | NT$700–1,000 |

預算內必須保留位準轉換器，不可為省幾十元直接用 ESP32 3.3V data 驅動 5V WS2813。技術依據與原廠連結見 [官方整合查證](2026-08-21-official-integration-research.md)。

## 接線定稿

| 接點 | 連接 |
| --- | --- |
| D4 / SDA、D5 / SCL | Round Display 既有 I2C + Encoder `0x36` + Buzzer `0x34` + VEML7700 `0x10` |
| D2 | 進 74AHCT125 A；74AHCT125 Y 再接 LED SIG；microSD 必須停用且不可插卡 |
| D6 | Round Display 背光 PWM；若實機不穩定，降級為背光開關，LED 仍自動調光 |
| 3V3 | Encoder、Buzzer、VEML7700；組裝後量測 rail 壓降 |
| 5V | LED 棒與主電源支路；不得由 GPIO 或 3V3 rail 供應 LED 大電流 |
| GND | 所有模組與 5V 支路共地 |

Qwiic 板上的 pull-up 會並聯。裝好後必須先量測等效阻值；如果過強，依原廠 jumper 設計只保留足夠的一組，不能盲目把所有 pull-up 都留下。

## 裝置操作流程

1. Web 後台把實體 `deviceId` 指派給帳號與允許的自律房；App 只能讀取 Cloud 的有效指派。
2. Android App 連上裝置後，把「允許房間、個人目標、目前角色名稱／等級／階段、提示音偏好」壓成單一 BLE context frame；只有裝置寫入 NVS 並回報同一 `contextRevision` 後才算同步成功。
3. 裝置只保留最多三個已授權房間；旋鈕可選房，選擇與角色快照寫入 NVS，重新開機仍可顯示。
4. App 取得 Cloud 已確認的 Activity correlation，再送出 focus configure；韌體在處理 configure 的當下讀取旋鈕最新選擇並凍結為該輪單一房間，沒有選房就是個人活動。
5. 旋鈕短按開始／暫停／繼續，長按完成；裝置事件先寫入自身雙槽 journal。
6. App 讀到事件後重新驗證 DeviceAssignment 與選取房間，只把該房間寫進 Activity Ledger outbox；本地持久化成功後才 ACK 裝置。
7. Cloud 以 event ID 冪等收件，App、Web、房間成果與角色成長才從 canonical Ledger 取得一致結果。

## 目前已落地的韌體能力

- VEML7700 每秒取樣，EWMA 平滑、亮度上下限與感測失效 fallback；LED 亮度已接入，D6 背光 PWM 已完成編譯但仍需實物確認。
- 六種燈效：offline、ready、active、paused、complete、rest；活動時以 10 顆 LED 顯示進度。
- Qwiic Buzzer 使用低音量短 cue；App 可關閉提示音，Buzzer 缺席不阻擋計時。
- 旋鈕轉動選擇已授權房間，短按與長按沿用可靠的 focus lifecycle；房間與角色快照持久化。
- 裝置事件帶單一 `roomContextId`；App 會拒絕未在 Cloud assignment 內的房間，不再把一筆事件自動散布到所有房間。

## 實物到貨後不可略過的驗收

1. I2C 同時找到 `0x10`、`0x34`、`0x36`，任一外接體驗元件拔除時核心計時仍可用。
2. 遮光／室內／強光三段測試，確認 LED 與背光平順；D6 PWM 不穩就啟用降級模式。
3. 5V LED 必須經位準轉換，做長時間燈效壓力測試，禁止熱插拔。
4. 高亮螢幕、LED 與蜂鳴器同時工作時，量測 USB 輸入、3.3V rail、溫升與是否重啟。
5. 斷電重開後確認角色、房間選擇與未 ACK 事件皆恢復；重送不得重複計分。
6. 使用真實 Android 手機完成：後台指派 → BLE → 選房 → 專注 → App outbox → Cloud Ledger → Web/房間/角色成果。

只有第 6 項完成並保存證據後，才能把「嵌入式系統已整合」寫進正式驗收；目前可稱為可編譯、具測試的高規格實作，不可稱實物完成。
