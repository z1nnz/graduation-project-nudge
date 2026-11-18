# 09 分工與 Git 實行表

## 預設責任與已知狀態

| 角色 | 預設責任 | 本輪已知狀態 |
| --- | --- | --- |
| johnsnow | Orbit 圓屏 P0-A／P0-B、圓形進度、Orbit 實機證據；預設共用 core 實作者 | 未取得認領／交接確認，沒有代發公告 |
| roy | Station 身分卡、方屏 P0-A／P0-B、Station 實機證據 | 使用者授權本輪文件／工具；實機仍待持板者驗收 |
| z1nnz | 範圍裁決、共用視覺、整合、ZIP／腳本、PR review 與最終 merge | 所有正式 PR 送其審查，作者不合併 |

具體原始碼已由 Roy 按先前使用者授權準備在 #23／#24／#25，不等於交換裝置或另一位組員接受了分工。
預設實體責任維持原表；若要交換裝置，先在實際 Issue 留下裝置、原／新持有人、時間、同意紀錄，再更動 coordination.json。
目前沒有交換、沒有獨立 Issue，也沒有兩人共同實機完成的證據。

## 檔案責任與互斥修改

以下路徑屬於尚待合併的 #25 來源：

| 範圍 | 路徑 | 下一次修改規則 |
| --- | --- | --- |
| Orbit adapter | firmware/nudge_competition_demo/src/main.cpp 中 OrbitDisplay／TftCanvas、drawing.cpp | johnsnow；main.cpp 同時是共用入口，先協調單一編輯者，不能當成互不影響的獨立檔案 |
| Station adapter | firmware/nudge_competition_demo/src/station_arduino.cpp、station.cpp | roy，沒有確認 pinmap 不改成可操作 GPIO |
| 共用引擎與入口 | src/core.cpp、main.cpp、include/demo/core.h | 預設 johnsnow；改動前在 Issue 宣告單一編輯者，整合者裁決跨裝置影響 |
| 共用角色／色彩 | shared/demo_contract.json、scripts/generate_demo_contract.cjs | z1nnz 審查協調；修改 source 後重生常數，不各改 C++／Dart／Kotlin |
| 共用硬體／周邊 | hardware_profile.*、peripherals*、platformio.ini | 先圈定一個裝置；未知接線不猜，P1 前置未實機通過維持 OFF |
| 本輪文件／驗收工具 | docs/competition-demo/package09-10、scripts/demo_*、test/demo_acceptance_test.js | roy；不因此取得其他組員分支的編輯權 |

同一 main.cpp 不允許兩人同時重構。發現同檔衝突，停止 rebase，先在團隊現有管道說明檔案、目的與目前 head；取得處理方式後逐檔解決。
沒有衝突時不額外發訊息，不用 reset --hard、強推或覆蓋他人工作。
沒有等待對方動畫／感測器才開始自己 P0-A；必要時用兩個獨立 demo 專案，先保持 driver 隔離。

## 依賴與合併

理想順序依需求維持：Orbit P0-A、Station P0-A、共用 core、共用視覺、兩台 P0-B、輸入、其他周邊、選配 BLE、比賽文件。
P0-A 可平行；P0-B 正式整合等 core 合併 main 後再同步。P1 等兩台 P0-A，P2 等 P0-B／視覺／十次重播實測。

目前實際情況：

| PR | 內容 | 目前限制 |
| --- | --- | --- |
| #18–20、#22 | 新範圍／零件／故事 | 尚未合併，不能聲稱團隊均採用 |
| #21 | iOS checksum metadata | 六 CI 基礎修復，建議先審 |
| #23 | Orbit P0-A＋core／P0-B 準備 | 同 PR 已有共用核心，實機未驗；需按 slice 看差異 |
| #24 | Station 與 P1 準備 | Station 接線未配置，P1 OFF；軟體準備不代替前置 |
| #25 | 共用角色與選配 BLE 準備 | BLE OFF，未實機連線 |
| 本輪 | 09／10 文件與工具 | 從 main 整理，只有 #21 既有修復；#25 只為本機讀取來源 |

之前已將多個軟體 slice 合併交付，與理想拆分／實機後整合順序有差異；不在文件中改寫成已照順序完成。
z1nnz 審查時決定待合併 PR 的切分與時程。碼可審不代表實機可上台，尚未採用的 P1／P2 不啟用。

## 每一輪 Git 操作

```sh
git switch main
git pull --ff-only origin main
git switch -c feature/roy-demo-rehearsal-records
```

一分支一個可驗收成果。示例：feature/johnsnow-orbit-display-demo、feature/roy-station-display-demo、fix/roy-station-rotation。
未合併依賴只在分離工作樹暫測；正式送出前由最新 main 整理自己的差異，base 一律 main，不把別人的整包修改複製進去。

開發循環：先 compile 最小例子 → 一個畫面／輸入 → compile → 自己裝置 upload → 10–30 秒影片 → commit → 下一小段。
**本輪使用者明確暫緩 upload／影片，故只提交準備成果；該循環的實機段沒有打勾。**

```sh
git status
git add docs/competition-demo/package09-10/operator-sheet.md
git diff --cached
git commit -m "docs(demo): record Station rehearsal handoff"
git push -u origin feature/roy-demo-rehearsal-records
```

禁止 git add .、push main、強推與自行 merge。每次只加入自己的實際檔案；同步用 git fetch origin 與 git merge origin/main，先理解衝突再處理。

## 本機檢查與審查

依 CONTRIBUTING：flutter analyze、flutter test、node --test test/*.js、npm --prefix functions test；韌體另做 clean PlatformIO／host tests。
本機工具故障不能降低 CI 規則，PR 保留真正的命令、限制與結果。
文件 PR 也等以下六項最新 head 全綠，才 Ready／請 z1nnz 審查：

- Flutter analyze and tests
- Android Kotlin compile
- iOS dependency lock
- Web and shared contract tests
- Cloud Functions tests
- Firestore rules and transaction tests

PR 必填 Issue（沒有就明寫未建立與需求來源）、負責人、做什麼／改哪些檔、實際硬體與未知型號、命令結果、upload 結果、影片／照片、P0-A／P0-B／P1／P2、降級與未完成項目；不能拿 host 圖代替影片。
看完影片再核對：無不相關 App／Cloud 修改、無憑證／私人資料／操作員路徑、編譯無 driver／記憶體警告、可離線、拔掉 P1 不阻擋 P0-A、固定資料有 DEMO、無採購、能看到完整結果。
缺實機影片時只能審軟體準備，不能簽實機通過。

每日回報使用 [交接模板](handoff-template.md)。阻塞超過半天，向既有負責人回報，不自行購買零件繞過。
本輪只提供可貼用文字，未擅自替兩人傳送公告或確認認領。
