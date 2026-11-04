# 15｜Nudge Orbit 圓形穿戴式裝置產品規格

## 一句話

Nudge Orbit 是一個以圓形螢幕呈現時間、角色與下一個小行動的個人穿戴式夥伴；
它讓使用者不用打開完整 App 就能開始、暫停、完成一次自己的活動。

## 產品邊界

### v1 要做到

- 圓形時鐘首頁、角色狀態、同步／離線提示。
- 顯示 App 選定的一個下一步或一個最近合法房間。
- 快速 5/15/25 分鐘 focus，開始、暫停、繼續、完成。
- 觸控操作；若該批觸控未通過，再使用單鍵／App 控制 fallback。
- 未 ACK 事件跨斷電保存，重連後安全重送。
- App 可更新角色安全快照、quiet setting、時鐘 anchor、context revision。
- USB 供電完成全部軟硬體驗收；可拆式腕帶只作外觀／配戴概念。

### v1 不做

- 不量測心率、血氧、體溫，不宣稱健康或醫療功能。
- 沒有已確認 IMU 時不自行計步；顯示的步數只能來自手機正式 Health Adapter。
- 不在手錶上加入商城、家庭管理、團體管理、聊天鍵盤或完整任務編輯。
- 未完成 protected LiPo、充電、溫升、續航與外殼前，不作全天候腕上使用。
- 不防水，不在充電時佩戴。

## 已知硬體與待確認項目

| 項目 | 現況 |
| --- | --- |
| 主控 | Seeed XIAO ESP32-S3 預焊版 |
| 顯示 | Seeed Round Display for XIAO `104030087`，GC9A01 240×240 |
| 觸控 | 板載 CHSC6X，須實機驗收 |
| RTC | 板載 RTC，型號／位址依實物與原廠文件核對 |
| 背光 | D6；先固定 HIGH 驗證，再測 PWM／開關 fallback |
| 電源 | 第一階段 USB；電池為獨立安全里程碑 |
| 顯示現況 | USB/燒錄/韌體執行有證據，完整 rendering 仍需重新取得直接證據 |

Round Display 佔用大部分 XIAO 腳位，所以 Orbit 不承接 Station 的 LED stick、外接
旋鈕、VEML7700 和 Qwiic buzzer。穿戴裝置的價值是簡潔，不是把所有零件掛上去。

## 使用流程

### 首次設定

1. App 掃描 Orbit，讀取 profile/firmware/capabilities。
2. App 確認 Cloud DeviceAssignment 屬於目前帳號。
3. 使用者選擇預設 5/15/25 分鐘、quiet mode、是否顯示一個房間。
4. App 送 context revision；Orbit 寫 NVS 並回 exact revision。
5. Orbit 顯示角色與時間，完成一輪觸控測試後才標記 ready。

### 日常流程

1. 抬起／點亮：只顯示時間、角色、同步狀態。
2. 點角色或 focus ring：顯示下一步與時間。
3. 再次確認：App/Cloud correlation 與 lease 已備妥才進入正式倒數。
4. 單擊暫停／繼續；長按或確認手勢完成，避免誤觸。
5. 完成先顯示「等待同步」，Cloud Receipt 後 App 再下發正式成長 snapshot。

Orbit 離開手機時可以繼續已配置的 session；不能在沒有有效 assignment/lease 的
狀態建立可結算的新 Cloud session。

## 畫面資訊架構

### Watch face

- 中央：時間或角色。
- 外圈：當日安全進度／目前 focus 倒數，不能同時顯示多個 ring。
- 12 點方向：BLE/sync 小圖示。
- 6 點方向：下一步或 phase 短標籤。

### Focus face

- 中央大數字：剩餘時間。
- 外圈：progress。
- 下方：一個 room/personal label。
- 觸控區域要大於視覺圖示，避免圓角邊緣難點。

### Recovery face

- 只提供「5 分鐘重新開始」「今天休息」兩個簡單選擇；完整調整回 App。
- 不顯示 streak 失敗、紅色警告或家長／管理者命令。

### Fault face

- 可理解圖示 + 短代碼，例如 `PHONE`、`SYNC`、`ASSIGN`、`UPDATE`。
- serial log 保留完整錯誤；螢幕不顯示 token、UID 或內部 JSON。

## 互動原則

- v1 手勢只保留 tap、long press、左右 swipe；每個畫面最多兩種主要動作。
- 危險動作（discard/reset/wipe）只能從 App 執行並再次確認。
- 觸控失敗時仍可透過 App 完成，不讓損壞輸入造成 queue 無法同步。
- 動畫使用短、低更新率的 transform/frame；休息時降低刷新與背光。

## 電源策略

### USB 驗收版

- 先建立穩定功能和功耗 baseline，避免電池同時增加充電、保護、續航與熱風險。
- 記錄 idle、display active、BLE notify、flash write 四種電流狀態。

### 電池概念版（USB 版通過後）

- 只用具保護板、尺寸和容量可追溯的 3.7V LiPo；確認 connector polarity。
- 驗證充電 IC、最大充電電流、外殼散熱、短路保護、低電壓關機與膨脹空間。
- 不在人體上充電；外殼不得壓迫電池；腕帶拉力不能傳到焊點。
- 續航測試須用實測平均／峰值電流，不用商品頁理想值推測。

## App 與資料

- App 顯示 Orbit 卡片：電量（若能力存在）、連線、firmware、last sync、pending count。
- 裝置保存最小 presentation snapshot，不保存 email、家庭健康明細或完整聊天。
- App 發出的角色 snapshot 只含 catalog ID/name/stage/level 和內建 asset key。
- account logout/revoke 立即停止新控制；queue 未清空時裝置進 locked/wipe-required。

## 成功指標

- 從點亮到 started accepted 的時間中位數。
- 觸控誤操作率、活動中斷率、BLE 重連時間、pending queue 最長時間。
- 一次充電續航只在電池版實測後報告。
- 使用者不看工程文件能否完成一次 5 分鐘活動。

## 驗收摘要

- 顯示／觸控冷開機 10 次。
- 100 次 tap/long-press/swipe 不產生重複 transition。
- 斷線、App killed、手機重啟、Orbit 重啟後單一 Receipt。
- 撤銷 assignment 後不能開始新活動。
- USB 版 2 小時基本 soak；電池版另做充放電、溫升與 24 小時以上續航測試。
