# Nudge 競賽離線展示韌體

目前涵蓋 03／04 Orbit、05 Station、06 周邊準備，以及 07 Demo Controller／BLE、08 共用角色視覺。
原本 `nudge_focus_device` 正式韌體保持原狀。實機依使用者指示稍後驗收。

Station：XIAO ESP32S3 ＋ Waveshare 17344／2inch LCD Module，ST7789 家族、240×320、SPI。
已補入真實 ST7789 adapter 與八幕 Painter；**發布設定沒有已確認 GPIO，預設只輸出診斷，不會操作 LCD**。
周邊 adapter 已編譯／host 測試，但全部預設停用；不能當作 P0-A 或周邊實機成功。


## 建置

Python 3.9 以上、PlatformIO 6.1.19、C++17／make。
ESP32 平台固定 6.12.0，所有圖形與周邊 libraries 固定 Git commit，見 platformio.ini。

```sh
python -m pip install platformio==6.1.19
make -C firmware/nudge_competition_demo test
make -C firmware/nudge_competition_demo station-preview
pio run --project-dir firmware/nudge_competition_demo -e station_p0a -e station_demo -e station_colors -e station_calibration -e station_p1_check -e orbit_p0a -e orbit_demo -e orbit_static -e orbit_colors -e orbit_calibration -e orbit_p1_check -e station_static -e orbit_ble_check -e station_ble_check
python firmware/nudge_competition_demo/scripts/package_builds.py
```

| Environment | 用途 |
| --- | --- |
| orbit_p0a（專案預設） | 已有 Orbit 三幕；無周邊依賴 |
| orbit_demo／orbit_static | Orbit 八幕／關閉角色分幀的備援 |
| orbit_colors／orbit_calibration | Orbit 原有五色／校正 |
| station_p0a | Station 三幕：Home 5s → Focus 20s → Complete 5s |
| station_demo | Station 八幕，與 Orbit 相同 Scene ID／時間軸 |
| station_colors | 整片紅、綠、藍、黑、白，各 2s |
| station_calibration | 240×320、實際 rotation、8/12px 邊界、8/16/32px 字級參考 |
| station_static | 關閉 Station 角色動畫，八幕仍照常播放 |
| station_ble_check／orbit_ble_check | 編譯 Demo BLE；發布 profile 的 P2 gate 仍 OFF |
| station_p1_check／orbit_p1_check | 編譯五種周邊 driver；發布 profile 仍關閉全部模組 |

Station 的四種畫面模式及 p1_check 都先檢查 profile；未確認就只顯示 serial 診斷，沒有假 pin map。
`NUDGE_BUILD_OPTIONALS=1` 只代表編譯包含周邊，不等於允許初始化。
CI 保留原設定：既有 root Node 測試入口會實際編譯執行三個 C++ 測試程式；
ESP32 交叉編譯在本機完成，最新結果隨本輪 build-evidence 交付，不能把 Web CI 稱為 ESP32 編譯。

## 實機之後設定

1. 持板者先確認 Station 是獨立於 Orbit 的第二塊 XIAO，及 LCD 原廠訊號／電源／接頭對應。
2. 將 config/local_hardware_profile.example.h 複製為 include/local_hardware_profile.h。
   所有 GPIO 預設 -1；只填已核對的 ESP32 GPIO 數字，再標示 independentStationConfirmed／lcdWiringConfirmed。
   不照抄 Orbit D 編號、UNO 範例或線材顏色。文件沒有提供猜測接線表，也不要求採購。
3. LCD MOSI、clock、CS、DC、reset、backlight 必須是相異的 XIAO 外露 GPIO；USB GPIO 不允許。
   目前 layout 只接受直向 rotation 0／2。先以五色核對色序及 invertColors，再跑校正與三幕。
4. 使用原廠 ST7789 型號資料移植 Adafruit driver；這不是原廠提供的 XIAO 現成範例，也未完成實機移植驗收。
5. 稍後接板只連目標裝置，核對實際 USB port 後才操作下列 upload 範本。

```sh
pio device list
# /dev/cu.usbmodem-REPLACE 必須替換為已核對的 Station port。
pio run --project-dir firmware/nudge_competition_demo -e station_colors -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e station_calibration -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e station_p0a -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio run --project-dir firmware/nudge_competition_demo -e station_demo -t upload --upload-port /dev/cu.usbmodem-REPLACE
pio device monitor --port /dev/cu.usbmodem-REPLACE --baud 115200
```

Serial N 下一幕、R 回 Boot、M 切換周邊靜音。無輸入 5s 啟用自動；初始化後重新計 Boot 1.5s。
三幕每圈 30s；八幕 Home 4／Ready 3／Focus 20／Support 5／Complete 4／Growth 5／Summary 8s，每圈 49s。
沿用 package03/04 的實作時間，不沿用 package02 尚未重排的 4s Ready／6s Summary 紙面規劃。

## P1 稍後啟用的門檻

profile 的 armP1、orbitP0aAccepted、stationP0aAccepted、peripheralWiringConfirmed 皆須為 true，
且 display 初始化可用，才會進入任何周邊 begin；目前沒有兩台實機 P0-A 證據，這些值全為 false。
即使編譯 p1_check，也不會呼叫 Wire.begin 或操作周邊 GPIO。

- 每次只啟用已購買且現有接法已確認的一個欄位：button／encoder／led／light／buzzer。
- I2C 的 sda／scl 必須相異且不占 LCD。Orbit 額外保留原廠 Setup501 的螢幕／觸控腳位。
- buttonPin／ledPin 同樣不得占用 LCD、I2C 或彼此的腳位。沒有已核對 GPIO 按鍵時保持 button=false。
- seesaw encoder 只用 Station；按鈕 40ms debounce、穩定按住 1.2s Reset；Task Select 短按開始，其他幕短按 Next。
  開機已按住的按鍵須先放開，避免意外事件；旋鈕大跳值會停用，沒有旋鈕自動選第一個任務。
- 光感每秒取樣、平滑與遲滯後只輸出 30/55/80%；無效／缺失回固定 55%，畫面不顯示 lux。
  Station 與 Orbit 都會將輸出套用到自己的背光；Orbit 使用原廠 Setup501 已有的 TFT_BL，沒有借用 Station 腳位。
- LED 僅低主色、進度與 2s 完成色；亮度上限 16/255。需 ledSignalPathReady 才可啟用。
  現有 LED 連接屬未確認的 D 級，本輪決定不納入現場；不新增採購或焊接。
- 蜂鳴器只用非阻塞短音：開始一個、完成兩個上行音；低音量，M 靜音。Pause/Resume 選配未實作。
- I2C 設 20ms timeout；模組 begin/update 失敗記錄一次後停用，不無限重試。LED 無回讀，不能由 begin 推定實際亮燈。
- 未接入 CHSC 觸控 driver；無可靠實體輸入時維持自動與 Serial，沒有宣稱教授已成功操作。

## 畫面、記憶體與真實性

Station 八幕：Boot 含短 build id、Desk Home、三個任務、20 秒專注預覽、3/5 支持與自主開始／結束、
25 MIN 完成、SPROUT LEVEL 7／DEMO XP+10、2/3／50 MIN／Score82 摘要。
小樹／小芽及中文任務只存在共用 DemoData；畫面用短英文與自製幾何圖示，不提供未驗證中文字型。
每幕 DEMO／OFFLINE，08:30 為 Orbit 固定時鐘；所有數字為示範，不保存活動、不連線、不發正式 XP。

Station 進場先用 RGB565 buffer 清整幕，配置失敗則直接繪圖；buffer 約 153600 bytes heap，
實際記憶體、速度與殘影待驗。Focus 後續只更新倒數／進度，沒有每幀整屏清除。
ST7789 init 沒有面板 ACK，geometry 符合不等於實物成功。PWM 失效回固定背光 ON 並記錄，非精確 55%。
白屏先停止接周邊，退五色／校正，保留另一台展示，不按壓玻璃。

## 07／08：控制器與共用角色

- shared/demo_contract.json 是協定、名稱、8 個色彩與 6 種角色姿態的唯一資料來源。
  修改後執行 node scripts/generate_demo_contract.cjs；--check 驗證 C++／Dart／Kotlin 產物一致。
- 兩台都使用同一 CharacterPainter：idle／ready／focus／support／complete／growth。
  每次切幕最多 900ms 的輕微動作，Focus 永遠靜態，不阻塞 Next／Restart。
  orbit_static／station_static 可全部關閉角色動畫，場景與進度仍正常。
- App 獨立入口 lib/main_demo_controller.dart 不執行正式 Firebase、帳號、通知與 AppState 啟動。
  flutter run --target lib/main_demo_controller.dart 可先開預覽；Android 可使用 BLE，iOS／Web 只提供預覽與自動展示備援。
- BLE 使用獨立 UUID 7df2… 與指定 Demo 名稱，沒有沿用正式 7df1… 帳號／活動控制。
  Android 共用既有 GATT transport 的 Demo profile；正式協定與正式裝置韌體未改。
- firmware 的 NUDGE_BUILD_DEMO_BLE=1 只編譯 adapter。profile.armBle、orbitP0bAccepted、stationP0bAccepted、
  visualsAccepted、tenReplaysAccepted 及 displayAvailable 全通過才初始化；本輪全為 false。
- App 也要 5 個獨立 --dart-define：NUDGE_DEMO_BLE、NUDGE_DEMO_ORBIT_P0B、NUDGE_DEMO_STATION_P0B、
  NUDGE_DEMO_VISUALS、NUDGE_DEMO_TEN_REPLAYS，皆須 true；本輪不傳這些參數，按鈕預設停用。
- 真正啟用前需完成兩台 P0-B、視覺與 10 次重播，再核對 07 停止條件。
  不把 CI／host 通過當作這些實機前置，也不在距比賽不足 3 天且未連續成功時新增 P2。

## 韌體檔與回復

輸出 .pio/build/<environment>/firmware.bin，打包器匯出 14 個 binary／SHA-256／source commit／Git tree／dirty 狀態。
Station 檔名含 _unconfigured，全部實機 verified=false，P1 armed=false；不能拿來宣稱已能顯示。
打包器拒絕存在 local_hardware_profile.h 的公開交付，避免把已改接線的本機版本誤標為預設設定。
本機 profile 修改會讓 build id 加上 hw 雜湊，實機照片／log 須同時記錄該版本與設定。

正式交付由乾淨 source commit 編譯，後續 evidence commit 的韌體 tree 必須相同。
韌體檔是 application image，重刷應用 PlatformIO upload 處理 bootloader／partitions，不能把它單獨寫到 0x0。
回復本輪 07／08 修改可回到前一版韌體；Git revert 不會自動重刷實機，已燒錄者須另用先前已驗證版本還原。
本輪新增獨立 Demo Dart 入口，擴充共用 Android BLE adapter 與初始化保護；正式 Dart 啟動、Web／Cloud／Ledger、原正式韌體及接線未改，作者不合併 PR。
