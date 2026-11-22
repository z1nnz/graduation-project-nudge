# PR #70 A：既有 PR 審查與整合清單

查核日期：2026-11-22（Asia/Taipei）。以 `origin/main` = `27f1e4d` 和各 PR 最新 head 為準。此表是審查決策，不是合併、部署或實機驗收。

## 逐 PR 處置

| PR | base → head（SHA） | 範圍／需求 | 前置與差異風險 | 最新 CI | migration | 處置 |
| --- | --- | --- | --- | --- | --- | --- |
| #18 | main → `codex/execution-work-packages` (`9ace911bf892dfb3a451acce7e2ecbeb41904f7d`) | 00–13 展示工作包規格 | 後續展示 PR 引用此規格；須先確認新版範圍 | 6/6 成功 | 無 | 規格審查後優先整合 |
| #19 | main → `docs/roy-package00-demo-scope` (`d58d37c71a72555c1b20d3ba774e06a634f05dfd`) | 00 範圍、公告草稿、打包器 | 依 #18；與 #20 等共享 iOS lock 修復（#21 已合併），需檢查重疊 | 6/6 成功 | 無 | 確認公告仍是草稿後整合 |
| #20 | main → `docs/roy-package01-parts-inventory` (`4cf97e86c59c6a5ad800790d471652721e4d74b8`) | 01 零件／照片 | 依 #18；照片僅證明盤點，不能證明第二主控或接線 | 6/6 成功 | 無 | 人工核對照片來源後整合 |
| #22 | main → `docs/roy-package02-demo-story` (`1a041ff3eb59e7cf6a8e79a9e5b40032506e4f53`) | 02 故事與時間檢查 | 依 #18、參照 #25 的 3 秒／8 秒時序；與 #62 有同領域文件 | 6/6 成功 | 無 | 先核對 #25 時序及 #62 重疊，再整合 |
| #23 | main → `feature/roy-package03-04-offline-orbit` (`5a6d7d3862861491b58c5360015e409fd66221d8`) | 03／04 Orbit 離線韌體 | 依 #18；#24 的祖先，先於 #24 | 6/6 成功 | 無 | 原生測試與軟體建置可收；實機仍未驗 |
| #24 | main → `feature/roy-package05-06-station-demo` (`2e3fe6126ade0e690e4eb004cc9ff3a7db81c7a6`) | 05／06 Station 與周邊隔離 | head 已包含 #23；Station pinmap 未配置 | 6/6 成功 | 無 | #23 整合後重算增量；硬體結果保留待驗 |
| #25 | main → `feature/roy-package07-08-demo-controller` (`c4cb9fa3b7a919f1c888bf79b10a011d94c4fb0f`) | 07／08 Demo Controller／姿態 | head 已包含 #23、#24；#65 的 base | 6/6 成功 | 無 | #23、#24 後重算增量；正式 Ledger 隔離需核對 |
| #26 | main → `feature/roy-package09-10-rehearsal` (`3a5596619f51bbfb87389626c6441fbf2c64c56d`) | 09／10 排練／驗收工具 | 引用 #25 時序與 binary；未包含 #25 head | 6/6 成功 | 無 | #25 後核對來源鎖與工具，再整合 |
| #61 | main → `feature/roy-package11-12-demo-operations` (`e3bd9e537e81ef6a05a89cff2bc55881988f28f5`) | 11／12 backlog／現場包 | 引用 #25、#26；未包含兩者 head | 6/6 成功 | 無 | 前置整合後重驗 ZIP、PDF、Issue 對照 |
| #62 | main → `feature/roy-package13-delivery-evidence` (`2907a026f3278f27a320fb655779d3ac383222b2`) | 13 交付與 00–13 總稽核 | 依 #18–#26、#61；內附舊遠端快照 | 6/6 成功 | 無 | 最後重建並刷新來源快照，不能照舊快照核准 |
| #65 | `feature/roy-package07-08-demo-controller` → `codex/orbit-screen-demo` (`9eb40f26ece444268bd76cb1d9755c6b3f6b4d1c`) | Orbit 螢幕／報告預覽 | 明確依 #25；目前無 check runs | 無，非通過 | 無 | #25 先整合；改 base 為 main 後跑六 gate，人工看預覽 |
| #66 | main → `codex/avatar-evolution-pipeline` (`0405f7cf307f6af0532533e6e4377accb4e93c70`) | 穩定角色 key、排程、strict parser、遷移 preflight | migration apply／rollback 未有；見 F1 | 6/6 成功 | 有，僅 dry-run | 保持 draft，B 續做與回歸 |
| #69 | main → `codex/web-companion-install` (`08af5dcd8930278b3bef4a4564fa001494d94852`) | PWA 安裝入口 | #68 已合併；真實 HTTPS 安裝未驗 | 6/6 成功 | 無 | 保持 draft，補真實瀏覽器驗收 |
| #70 | main → `codex/companion-world-loop` (`05b299421319aeebbde57c585fc2a9efa0ed4dc3`) | A/B/C/D 分工文件 | 文件非功能；A/B 已在執行 | 6/6 成功 | 無 | 文件審查；不可視為四包完成 |

CI 欄是查核時用 GitHub REST `commits/{sha}/check-runs` 得到的 exact head 結果；分支同步或新增 commit 後必須重查。#65 的非 main base 不觸發目前只監聽 main PR 的 workflow。所有展示分支的軟體預覽、自評分數與實體顯示分開計。

## Findings

| 嚴重度 | 位置與重現 | 建議 |
| --- | --- | --- |
| 高 F1 | #66 `scripts/avatar_progress_migration_plan.mjs:46-47`：catalog 少一個曾用名稱時，`resolve` 原樣回傳；以未知名稱的 XP 帳本跑 planner，`issues` 為空、`updates` 可能為空，無法發現漏匯的歷史身份。 | 對不屬於內建名稱或已知 stable key 的值 fail closed，要求補完整 catalog／有證據的對照，再考慮 apply。 |
| 高 F2 | #66 `docs/acceptance/avatar-progress-migration-preflight.md:23-39`：apply／rollback、cutover fence 與 emulator 驗證尚未實作。 | 保持 draft；不可把 6/6 CI 當作資料遷移安全驗收，更不可執行 production apply。 |
| 中 F3 | #65 `.github/workflows/ci.yml:3-6`：workflow 僅在 base main 的 PR 執行；#65 以 #25 分支為 base，exact head `9eb40f2` 查不到 check runs。 | #25 整合後改 base／更新 head，取得六項 gate；目前只接受 `make test`、PlatformIO 的局部證據。 |
| 中 F4 | #24 `docs/competition-demo/package05-06/evidence.json:7-19`：pinmap、第二主控、實體三幕結果均未確認。 | 合併決策明列「軟體交付」；由持板者另做接線、冷啟動、螢幕及重播驗收。 |
| 中 F5 | #62 `docs/competition-demo/audit00-13/remote-snapshot.json:2-10`：快照日期 11/19、main `c37c6ab`、#62 head `3e1f765`，已落後目前 main `27f1e4d`／head `2907a02`。 | 總稽核合併前重新產生遠端快照、核對來源 commit 與輸出 ZIP，勿用舊 snapshot 證明最新整合。 |
| 中 F6 | main `test/firebase_bootstrap_contract_test.dart:13-15` 在 Windows 讀到 CRLF，字面 `\n` 斷言失敗；`test/app_state_study_room_test.dart:598-634` 以本機 05:00 切日，夜間執行時與 AppState 的日界線不一致，週額度預期 0、實得 100。 | 修正測試為跨平台換行與固定時鐘／一致時區，再在相關 PR 整合後重跑。這是本機 main 基線失敗，不歸咎於審查文件。 |

## 建議整合順序

1. #18；再 #19、#20（兩者可分別審核，但各次 merge 後重算下一個 PR 的差異與 CI）。
2. #23 → #24 → #25；#65 待 #25 後改 base 並補 CI。#22 在 #25 時序固定後核對；#26、#61 依其引用來源接續。
3. #62 最後重建 00–13 稽核與交付證據。每步只由 `@z1nnz` 按最新 head、衝突與 gate 決定合併。
4. #69、#70 與硬體鏈無程式前置，可獨立審查；#66 仍受 B 的遷移安全 gate 阻擋。C／D 的整合要等各自 PR 與明確介面需求，不能用 #70 文件代替驗收。

## 尚需人工驗收

軟體展示：Orbit／Station 實際板型、接線、五色、字型可讀、冷啟動與重播影片；目前沒有 ESP 實機。App／Web：真實帳號的角色購買／進化、帳號切換與 Cloud 確認；家庭孩子同意及撤回、團體成員移除、房間成員自主活動。上述沒有可用帳號或實機時標記未驗，不由 CI 成功推論完成。

## 本機驗證（A 文件切片）

Windows 11、Flutter 3.41.7／Dart 3.11.5、Node 22.23.3、Java 17。`flutter pub get`、`npm ci --prefix functions`、`npm ci --prefix scripts` 均 exit 0。`flutter analyze` exit 0、無 issue；`node --test test/*.js` 136/136、0 skipped；`npm --prefix functions test` 120 通過、25 skipped、0 failed，故不算完整通過；`flutter test` exit 1，重跑 expanded 時 225 通過、2 失敗（F6）。本機 Java 17 未執行需要 CI Java 21 的 Rules emulator gate；以各 PR exact head CI 作遠端 gate 記錄，不視為本機 emulator 通過。
