# Nudge 離線競賽展示韌體（工作包 03、04）

這個獨立專案提供 Orbit 的離線三幕／八幕展示與可重用的 C++ 場景 core。
既有 `nudge_focus_device` 保留原狀。**尚未燒錄或完成實機驗收**。
`station_demo` 只編譯 core／序列診斷，不包含 Station LCD driver，也不能充當 Station 展示成品。

工作包固定來源：
[03 韌體架構](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/03-demo-firmware-architecture.md)、
[04 Orbit](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/04-orbit-round-display-work-package.md)。
本專案是允許的獨立最小 Demo 專案路線，不依賴尚未合併的共用 core PR。

## 建置與輸出

需要 C++17／make、Python 3.9 以上、PlatformIO 6.1.19。ESP32 平台固定 6.12.0，
Seeed_GFX 固定 V3.1.0 對應 commit `0b13b21f284c9bce3351b394bbd871b688d6aec7`。

```sh
python -m pip install platformio==6.1.19
make -C firmware/nudge_competition_demo test
make -C firmware/nudge_competition_demo preview
pio run --project-dir firmware/nudge_competition_demo -e orbit_p0a -e orbit_demo -e orbit_static -e orbit_colors -e orbit_calibration -e station_demo
python firmware/nudge_competition_demo/scripts/package_builds.py
```

| Environment | 實際作用 |
| --- | --- |
| `orbit_p0a`（預設） | Boot 後 Home 5s → Focus 20s → Complete 5s → Home |
| `orbit_demo` | Boot 1.5s；Home 4s → Ready 3s → Focus 20s → Encouragement 5s → Complete 4s → Growth 5s → Summary 8s → Home |
| `orbit_static` | 同八幕，關閉 Boot／Complete 角色分幀，保留倒數／進度更新 |
| `orbit_colors` | 紅／綠／藍／黑／白，各 2s，檢查是否全圓顯示；不播放場景 |
| `orbit_calibration` | 十字、外環、N/E/S/W、三種字級與 rotation 0；不播放場景 |
| `station_demo` | **僅序列診斷**，回報 `STATION_DRIVER_UNCONFIGURED`，不操作未知 LCD GPIO |

輸出在 `.pio/build/<environment>/firmware.bin`；打包在 `build/artifacts/`。
打包器核對 binary 內嵌 build identity，拒絕把舊版 binary 配上新 commit。
manifest 記錄 source commit／專案 Git tree、dirty 狀態、檔案長度及 SHA-256；所有 physical_verified 維持 false。
Station 檔名特別使用 `station_diagnostic_only.bin`。不能把此檔燒到 Station 當作方屏展示。
CI 的既有 Web check 會經 root Node 測試入口編譯及執行 native C++ 測試，六個必要 check 名稱不變。
目前 GitHub 憑證不允許修改 workflow，因此本 PR 保留既有 CI 設定；ESP32 六種交叉編譯在本機完成，
binary／manifest／完整 build log 隨 [build-evidence](../../docs/competition-demo/package03-04/build-evidence/) 交付。
build log 只遮去操作者的本機路徑，其他行完整保留。這些是未經實機驗證的建置輸出。
manifest 的 source commit 是獨立的 source 提交，後續 evidence 提交不修改韌體專案；可核對 Git tree 相同。

## 燒錄與現場操作（待裝置持有人驗證）

先確認實物是 XIAO ESP32S3＋Seeed Round Display；每次只連目標裝置，使用 `pio device list`
核對 USB port。插接方向依原廠及現場照片核對，不能將本文件當作 Station 接線圖。

```sh
pio device list
# 把下列 /dev/cu.usbmodem-REPLACE 換成剛核對的 Orbit port。
pio run --project-dir firmware/nudge_competition_demo -e orbit_colors -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e orbit_calibration -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e orbit_p0a -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e orbit_demo -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio device monitor --port /dev/cu.usbmodem-REPLACE --baud 115200
```

序列 `N`／`n` 下一幕、`R`／`r` 回 Boot；換行及其他字元忽略。
沒有輸入 5s 後自動播放，Boot 不必等待輸入，冷啟動理論 1.5s 進 Home。
每次有效輸入讓自動切換等候至少 5s，不需要 App、BLE、帳號、Wi-Fi 或任何 P1 模組。
沒有替尚未驗證的觸控／按鍵指定腳位；板上 Reset 會重新開機，實際操作成功仍待驗。
上游可能輸出 `TOUCH_CS pin not defined` 警告；本輪沒有使用其 SPI 觸控介面，
沒有為消除警告填入假腳位。既有電容觸控亦未啟用，操作只用自動與 USB serial。

卡住時保留另一台演示，使用已核對的 USB／port 重啟或重刷原本的 `orbit_p0a`。
出現白屏／局部顯示先用五色與校正模式，停止加入周邊，不按壓玻璃。
若 buffer 配置失敗會回報並直接繪製靜態切幕；有較明顯切幕也不阻止自動流程。
`screen.init()` 沒有 panel ACK；log 的 init issued **不是實體畫面成功證據**。

## Core、畫面與限制

`Scenario` 只接收 tick／next／restart，使用 uint32 millis 差值，支援回捲。
晚到的 tick 每次只換一幕，重新計算停留起點，避免 catch-up 直接跳過 Complete；
遇到停頓會延長整體展示時間，不能保證兩台同步。沒有 previous（工作包列為可選）。
`Runtime` 把 Frame 交給 DisplayPort；EffectPort 初始化失敗仍可輪播，測試會注入失敗。
正式周邊尚未接入；begin 的實作仍須遵守非阻塞契約。

固定資料只在 `DemoData` 一份：小樹、小芽 Level 7、完成專題韌體、期末一起前進、3/5、
「今天也慢慢來，我們都在」、25 分鐘、DEMO XP +10、今日 2 次／50 分鐘、Score 82。
英文短標籤 `PROJECT` 是任務顯示別名；08:30 是固定展示時鐘，不是 RTC。
Focus 畫面 `00:20` 是 20 秒壓縮展示倒數，完成的 `25 MIN` 也是展示值。
每幕都有 DEMO；不寫 NVS／Ledger、不發正式 XP，也不連線。

Orbit 的文字與角色位於中央約 70% 安全區，環在外緣。主數字 24px、標題與內容 16px；
校正附 8px 參考字，不把小字當可讀實測。主畫面只用 ASCII，避免未驗證中文字型。
初次切幕有 240×240 RGB565 buffer（約 115200 bytes heap），失敗可降級。
Focus 後續只補進度環及每秒倒數區，避免每幀整屏清除；實際速度、色序、閃爍待實機觀察。
Boot 是兩階亮度／展葉，不宣稱平滑 alpha 淡入；Complete 1s 內顯示兩階角色與勾選，
Ready 目前靜態光環，沒有呼吸動畫。可用 static 版關閉角色分幀。

P0-B 採用工作包 03／04 的 Ready 3s、Summary 8s，每圈 Home 起算 49s；
與 #22 package02 紙面規劃的 4s／6s、48s 不同。那份是未落實的規劃，不能當本 binary 的時間表；
現場三分鐘腳本須以本表重新排練，不能宣稱已完成真人計時。

Station Painter 只是 240×320 的 host 版面介面樣例，與 Orbit 接收同一 Frame／資料；
不是工作包 05 的八幕方屏交付，獨立主控、ST7789 driver、供電與接線留待確認。
無裝置驗證影片／截圖，沒有既有周邊控制或 BLE。完整驗收見[檢核紀錄](../../docs/competition-demo/package03-04/acceptance.md)。

## 資源與來源

角色／勾選／環為本次自行編寫的幾何繪圖，無下載圖片、未複製外來角色；顏色為 RGB565 常數。
Classic ASCII 字型由 Seeed_GFX／TFT_eSPI 原有的 Adafruit 5×7 字型提供，維持第三方來源及授權。
[上游授權檔](https://github.com/Seeed-Studio/Seeed_GFX/blob/0b13b21f284c9bce3351b394bbd871b688d6aec7/license.txt)
包含 MIT 與 BSD 說明，本專案不移除授權；沒有額外嵌入 bitmap。
本次使用程式幾何資源取代 RGB565 bitmap 的儲存形式，輸出仍是 RGB565。記憶體／可讀性需實機驗收。

Orbit 原廠 [Seeed 指南](https://wiki.seeedstudio.com/get_start_round_display/) 與
[固定版本 Setup501](https://github.com/Seeed-Studio/Seeed_GFX/blob/0b13b21f284c9bce3351b394bbd871b688d6aec7/User_Setups/Setup501_Seeed_XIAO_Round_Display.h)
決定 GC9A01／240×240、D8/D9/D10 SPI、D1 CS、D3 DC、D6 BL、RST -1。
這些是原廠配置，未聲稱照片實物已成功顯示；Station 不沿用這份設定。

## 回復

本 PR 不改既有正式韌體、App／Web／Cloud、資料契約或周邊接線。
刪除本獨立專案、交付 evidence 與 native test 即可撤回軟體變更；
實機若曾燒錄，另用操作者保存且已驗證的原版專案／binary 重刷，不能靠 Git revert 自動復原裝置。
