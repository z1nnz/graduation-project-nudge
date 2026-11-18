# 10 Gate A–G 與三次排練

**目前僅 Gate A 軟體準備通過。Gate B–G、USB upload、三次實體排練、兩位非開發者回饋均未執行。**
預期硬體：Orbit＝XIAO ESP32-S3＋Seeed 1.28 吋圓屏（GC9A01，仍需實物核對）；Station＝Waveshare 17344 的 240×320 ST7789V／VW，獨立第二塊主控及 GPIO 未確認。
不要猜 pinmap、帶電改線、加購工具或接上未確認模組。Station 未通過 B 前不接 P1。

## Gate A：可重現的程式驗證

本輪固定讀取 [#25 c4cb9fa](https://github.com/z1nnz/graduation-project-nudge/tree/c4cb9fa3b7a919f1c888bf79b10a011d94c4fb0f/firmware/nudge_competition_demo)，不在本分支複製它。
來源 tree 鎖定於 [source-lock.json](source-lock.json)。先在分離工作樹準備來源，再從本輪 repository root 執行：

```sh
git fetch origin c4cb9fa3b7a919f1c888bf79b10a011d94c4fb0f
git worktree add --detach ../nudge-demo-source c4cb9fa3b7a919f1c888bf79b10a011d94c4fb0f
node scripts/demo_gate_a.cjs --source-checkout ../nudge-demo-source --platformio pio --out ./gate-a-new
```

pio 必須在 PATH，或傳該 executable 路徑；不要把路徑放進公開紀錄。輸出資料夾必須不存在，避免沿用舊結果。
runner 不會 upload。先驗 tree／project clean，再執行：

1. 既有 make test：三個 native 執行檔。
2. 新增 host probe：P0-A／P0-B 各 10 個完整序列（包括 Boot、Complete、回 Home）、每個起始 Scene 各 10 次 Restart（共 80），Focus 的輸入不等待倒數。
3. PlatformIO run -t clean，再 run：orbit_p0a、station_p0a、orbit_demo、station_demo。
4. 檢查狀態碼、明顯越界／未初始化／缺 driver 警告、embedded build id、每檔 SHA-256、來源未在過程改變。

本輪四環境 clean build 通過、source 有 c4cb9fa3b7a9 build id；全部 native 及 host probe 通過，沒有記憶體越界／缺 driver 警告。
build log 中的第三方來源／工具提示仍保留，警告須由 reviewer 閱讀，不因 exit 0 全部忽略。
本輪九行 warning：四行 TFT_eSPI 的 TOUCH_CS 未設定（此 Demo 不採觸控，沒有假填 pin 消警告）、五行 Python urllib3／LibreSSL 工具提示。都保留原文；未見記憶體越界或顯示 driver 找不到，未宣稱已支援觸控。
自動掃描常見憑證 pattern，另由 reviewer 確認沒有真實帳號／Token／私人資料；固定小樹／小芽屬 Demo，不是真人記錄。
來源 project clean 不等於本機硬體 profile 已驗。預設拒絕 local profile；稍後持板者確實需要時才明確加 --allow-local-profile，記下 profile hash，仍需 B–G。
Station public binary 維持 unconfigured；編譯成功只證明 driver 程式可建置。

所有檔案見 [Gate A 報告](build-evidence/gate-a/gate-a.json)。這份 report 和 host 次數不能填進實機次數欄。
Gate A 的 binary 為 application image，不可單獨寫到 0x0。持板者須用已審來源與確認接線，以 PlatformIO upload 處理 bootloader／partitions；本輪沒有執行。

## Gate B–G：每台實測程序與次數

影片要拍到裝置與畫面切換，保留真正 build id、接線 profile、手機／板號、日期與操作者；失敗也記錄。
建議檔名 orbit-p0a-01.mp4、station-restart-01.mov；兩台不能用同一 board_id，不能把一台成功當另一台成功。
所有次數每台分開；兩台不需同步。

| Gate | 步驟與門檻 | 目前 |
| --- | --- | --- |
| B | RGB 黑白各整屏、文字方向、全幅與局部更新；冷啟動 3/3，USB 拔插 3/3 | 兩台全部未驗 |
| C | 自動 Home→Focus→Complete，均可辨認 Nudge，Complete 必到；無 App／網路／P1；各 3/3 | 未驗 |
| D | 已採 P0-B 時八幕順序，Focus 不阻塞、Encouragement 退出、Complete、Summary 回 Home；Restart 覆蓋八個起始幕 | 未採用實測 |
| E | 不開 App、關 Wi-Fi／手機藍牙仍走完整採用故事，無 Cloud loading；已採 P1 的模組故障只 serial、不擋主畫面 | 未驗 |
| F | P0-B 完整流程 10/10；Restart 10/10，至少覆蓋八個起始幕；每種實體輸入各 10 次無重複；若採 BLE，10 次故障仍可本機展示 | 未驗，P1／BLE OFF |
| G | 至少兩位非開發者、不先解釋程式；5 秒找到資訊、30 秒知道兩台差異、桌面距離可讀、注意完成動畫、知道 DEMO 是固定值；各一句回饋 | 沒有回饋 |

最低 P0-A＝每台 A／B／C 與冷啟動 3/3。後續 D、P1、P2 失敗不撤銷已證明的最低門檻；本輪尚未達到該實機門檻。
最低門檻不等於完整排練已完成。E／G 與三次排練另外記錄；工具分開回報 minimum_p0a_records_complete 與 submission_records_complete。

| 每台計數 | 需要 |
| --- | ---: |
| 冷啟動 | 3 |
| USB 拔插 | 3 |
| P0-A 三幕 | 3 |
| 已採 P0-B 完整流程 | 10 |
| 已採 P0-B Restart | 10（至少八個起始幕） |
| 每種已採實體輸入 | 各 10 |
| 已採 App／BLE 故障備援 | 10 |

未採項目用 adoption=false，不寫 0/0 通過；不能用未採 P0-B／P1／BLE 阻擋 P0-A。
input 的每一列需對所有 adopted_inputs 各觸發一次，連續 10 列；例如 button、encoder_rotation 都採用，兩者都要各 10 次，不能合計 10 次。

## 填寫原始紀錄與核對影片

先複製 physical-record.pending.json 到自己的證據目錄，不覆蓋公版；或用 init 建全空白檔：

```sh
node scripts/demo_acceptance.cjs init ./record.json
node scripts/demo_acceptance.cjs assess ./record.json --evidence-root ./evidence --today 2026-11-19 --out ./assessment.json
```

exit 2＝尚未完整；1＝格式／執行錯誤；0＝紀錄足以送人工審核，仍不等於實物驗收認證。
已填比賽日期時必須明確傳 --today 為比賽所在地的曆日，不使用隱含 UTC 日期批准功能。
--out 不覆寫既有檔案；第二次請換新檔名。日期以競賽所在地曆日填寫，避免 UTC 跨日。

每列填 attempt、pass／fail、scene、elapsed_ms、observed_build_id、操作者代號、日期、observations 與 evidence。
evidence 格式如下（值均由實際檔案／影片取得，這不是成功範例）：

```json
{
  "file": "orbit-p0a-01.mp4",
  "sha256": "替換為真正的64位小寫SHA-256",
  "kind": "physical_video",
  "continuous": true,
  "duration_ms": 120000,
  "start_ms": 0,
  "end_ms": 30000
}
```

工具要求檔案在 evidence-root 內、相對路徑、hash 相符且片段起訖合法；不接受絕對路徑、../、越界 symlink、host_simulation／圖片冒充影片。
同一 case 的多個 attempt 不可重用同一影片的重疊片段；同一長片可使用不同不重疊片段，無需拍十份重複檔。
sha256 可由本機 shasum -a 256 filename.mp4 取得；大型影片以分段讀檔雜湊，不一次塞進記憶體。
若只保留雲端影片連結，本機工具無法檢查內容／hash，該列保留待核對；不要因連結存在改成 pass。

observations 的必要鍵以 scripts/demo_acceptance.cjs 為機器契約：colors=color/full_screen；cold_boot=home_within_10s/home_ms；p0a=sequence/automatic/nudge_recognizable/no_app/no_network/no_optional；p0b=sequence/complete_seen/summary_returns_home；restart=returned_to_boot/no_reflash；其餘見 case 名稱與工具。
記錄中的 firmware 指主展示 binary；五色／校正另用診斷 environment 時，於 observations 加診斷 environment、binary hash 與來源，另附建置 manifest 供人工核對。工具沒有自動認證每個診斷程式。P0-B 改採用時須換真正 P0-B 主 binary，不能沿用 _p0a 冒稱八幕。
初始 template 的 restart.scene 已排八幕＋Boot／Home，方便逐幕測，但仍是 pending。
失敗須填 Scene、經過時間、版本、日期、描述與 reproducible=yes/no/unknown；不是「偶爾壞掉」就結束。
成功欄位是操作者陳述；工具不辨識 mp4 畫面，也不能判斷操作者陳述真假。z1nnz 仍要看完整影片，確認實物、版本、畫面、每次操作與結果。

## 三次排練

| 排練 | 如何做 | 保留 |
| --- | --- | --- |
| 1 工程 | 開 serial，逐幕／Restart／供電檢查；錯誤回到失敗記錄 | serial log＋裝置全程影片 |
| 2 口頭 | 不看程式，依 3 分鐘腳本，一鏡到底、計時 | 本輪計時容許 165–195 秒，非新硬體門檻；影片與實際時間 |
| 3 故障 | 不開 App、關網路、P1 移除、其中一台先不上電；另一台與真正備援影片接續說明 | 拍到每個情境與展示者恢復，不只勾 pass |

拔 P1／改接線先斷電；不靠新採購修復。尚無實機備援影片時明寫「沒有備援影片」，不要拿軟體圖稱為備援實錄。
三分鐘固定故事沿用 [package 02 PR #22](https://github.com/z1nnz/graduation-project-nudge/pull/22)；該 PR 尚未合併，開始排練前由負責人確認採用版。
兩位觀眾用 viewer-1／viewer-2 代號即可，不收真帳號或私人健康資料。記下實際桌距（本表採 30–80cm），不要替未參與的人填回饋。

## 凍結與降級

competition_date 未提供，目前工具回 date_unknown 並不允許據此批准新功能；這不是斷言比賽已近。
填真正比賽日期後：距賽 ≤3 天，凍結已採韌體／driver，只修阻擋展示的 bug，不新增感測器／重構／library major；≤1 天只做 upload、供電、影片、線材，不合併新功能。
保存實際已驗收 binary＋source／profile／hash；目前四檔只是軟體 build，沒有已驗收硬體版本。

故障順序：記錄版本與失敗 → 停 P1／P2 → 回已驗 P0-A → 一台失效用另一台與真正備援影片。
沒有已驗版本或備援影片則向 z1nnz 明說，不宣稱已可上台。BLE 重啟／卡畫面、不跨手機重現、需 Cloud／真帳號或距賽不足三天未十次連續成功時，不採 P2。

以下均不能當作實機通過：只有 SUCCESS、編譯、模擬器／電腦截圖、單張靜態圖、必須有開發者手機／網路、只有作者知道怎麼恢復。
