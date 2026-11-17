# 06：P1 準備、降級與納入決定

工作包規定兩台 P0-A 完成後才加入 P1。本輪依使用者「先完成程式、實機稍後驗收」指示，
只完成並送審軟體準備；**不將 host 成功當成 P0-A 實機通過，也不啟用任何 P1**。

| 既有物件 | 來源／flag | 軟體行為 | 本輪現場決定 |
| --- | --- | --- | --- |
| 已確認的既有 GPIO 按鍵 | profile.button／buttonPin | 40ms debounce、短按 Next、穩定長按 1.2s Restart；開機按住先放開 | 未確認有可用現成接法，關閉；不採購 |
| Adafruit seesaw 旋鈕系列 | [原廠](https://learn.adafruit.com/adafruit-i2c-qt-rotary-encoder)、profile.encoder | Station 三任務移動；Home/Ready 短按開始，其他幕 Next；長按 Restart；跳值／掉線停用 | 關閉，精確 SKU／現成接頭待核對 |
| 10-WS2813 Mini LED v1.0 | [原廠](https://wiki.seeedstudio.com/Grove-RGB_LED_Stick-10-WS2813_Mini/)、profile.led／ledSignalPathReady | 低主色、0–10 顆進度、2s 完成綠後低亮；亮度最大 16/255 | D 級連接路徑未閉合，跳過；不買轉換器、不焊接 |
| SparkFun VEML7700 SEN-29211 | [原廠](https://docs.sparkfun.com/SparkFun_Ambient_Light_Sensor-VEML7700/hardware_overview/)、profile.light | 每秒取樣、EWMA、遲滯，30/55/80%；無效或缺失 55%，不顯示 lux | 關閉，接線與讀值未驗 |
| SparkFun Qwiic Buzzer BOB-24474 | [原廠](https://docs.sparkfun.com/SparkFun_Qwiic_Buzzer/single_page/)、profile.buzzer | 開始 60ms 低音量短音，完成兩個 50ms 上行音；M 靜音，不循環、不用 delay | 關閉，接線／聲音與靜音未驗 |

已存在 CHSC 觸控尚未接入；Pause/Resume 也未實作，工作包列為可選。不加入其他感測器。
只使用既有零件；既有 GPIO 按鍵 adapter 不表示另有已購買的外接按鍵。
先前照片／型號／C、D 級限制見
[package01 原卡](https://github.com/z1nnz/graduation-project-nudge/blob/4cf97e86c59c6a5ad800790d471652721e4d74b8/docs/competition-demo/station-parts.md)。

## 啟用與錯誤策略

- 編譯 flag `NUDGE_BUILD_OPTIONALS=1`（p1_check）只增加 driver，不更動預設停用狀態。
- armP1、orbitP0aAccepted、stationP0aAccepted、peripheralWiringConfirmed、displayAvailable 五項都通過才准 begin。
- 所有周邊由 OptionalPeripheral／PeripheralGroup 啟動，begin／update 失敗只記錄一次後停用。
- master gate 不通過，完全不呼叫 driver begin／Wire.begin／周邊 pinMode。host 以 begin 呼叫計數驗證。
- I2C 用明確 SDA／SCL、100kHz、20ms timeout；腳位衝突時略過 I2C 模組，螢幕仍可用。
- LCD／I2C／LED／按鍵互斥；Orbit 另保留 Setup501 的螢幕與觸控腳位。
- seesaw 拔除或跳值超過合理每次範圍時停用，任務與場景不被任意大跳值改寫。
- 光感掉線／回讀失敗回 55%；NaN／負值／過大值亦回 55%，不黑屏。
- LED 介面無回讀；軟體 begin／show 不證明已亮或可偵測拔除，實際故障仍以畫面備援。
- 蜂鳴器非阻塞排程，現場可 Serial M 靜音。沒有假造實體靜音按鍵成功。
- default normal environment 回報所有周邊 compiled out；p1_check 分別列出五個 gated／skipped／disabled 狀態。

## 每個模組的矩陣

| 項目 | 軟體驗證 | 實機狀態 |
| --- | --- | --- |
| 存在／初始化成功 | FakePort 可啟動；實際 driver 以固定 commit 交叉編譯 | 五種皆未測 |
| 不存在／begin 失敗 | 五個位置逐一失敗注入，其他 port 與自動顯示繼續；沒有 retry | 五種皆未測 |
| 更新異常 | update false 後停用、只呼叫一次；light／encoder 異常資料邊界測試 | 五種皆未測 |
| 冷啟動 3 次 | 不以 host 代替 | 五種皆未測 |
| 完整 Demo 3 輪 | 共用 core 時間與故障隔離測試 | 五種皆未測 |
| Serial 啟用／略過 | log 路徑與狀態有實作 | 真正板上 log 未收集 |
| 成功／拔除降級影片 | 保留 evidence.json null／false | 沒有影片 |

後續兩台 P0-A 實機成功後，持板者每次只開一個 flag，逐項拍存在、拔除、異常、冷啟動與重播。
任何模組造成黑屏／重啟，就關閉其 flag，重刷無周邊三幕；不為了啟用 P1 新增採購或工具。
目前「全不納入」是本輪明確決定，之後變更必須附新的實機紀錄，由 z1nnz 審查。
