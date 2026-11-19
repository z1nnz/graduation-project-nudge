# 11／12：Issue Backlog 與比賽日離線準備

2026-11-19。使用者要求先查重、每包自評至少 85 才上傳 PR、六項最新 head CI 全綠後請 z1nnz 審查；實機稍後驗收。
固定需求：[11 可認領 Issue](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/11-demo-issue-backlog.md)、[12 比賽日操作](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/12-competition-day-runbook.md)。

**這是待辦與操作準備；不是兩台已可上台、已凍結韌體、影片備援或實機驗收通過。**
Station 獨立主控／接線未確認，P1／BLE 仍 OFF，所有實物欄位保留待驗。

## 查重與分支

查全部 26 PR、27 分支、Issue 與 #18／#26 留言，沒有新版 11／12 的專屬交付；Issue 清單此前只有 PR，沒有獨立 Issue。
既有 #22 腳本、#25 韌體與 #26 驗收工具是參考基礎，不當作 Issue 已認領或比賽已排練。
無法排除他人未推送本機工作。沒有替其他人確認分工或交換裝置。

新分支從最新 main c37c6ab 建立獨立工作樹，僅沿用 #21 的既有 iOS checksum metadata 修復，保持嚴格 CI；沒有帶入 #23–26 的整包程式歷史。
離線包透過固定 Git object 讀取 #25 的 firmware c4cb9fa、#26 的 Gate A 3a55966，詳見 [來源鎖定](source-lock.json)。
建議先審 #21；正式裝置來源整合仍等相關 PR 合併，本輪作者不自行 merge。

## 11：34 個可認領項目

- [完整 Issue 索引](issues.md)／[機器可讀 backlog](backlog.json)／[發布登錄](issue-registry.json)
- 34 個原定 ID、優先級與預設責任均保留，增加依賴、估時、Scope、步驟與五項驗收。
- 全部 open、無 assignee；預設角色不是已認領，也不因建立 Issue 就啟用周邊。
- P0-A 全部實機通過前，不認領 P0-B／P1／P2；既有軟體準備只是來源參考。
- 沒有影片與版本不關閉；source-complete 不能寫成 device-verified。

```sh
node scripts/demo_backlog.cjs validate docs/competition-demo/package11-12/backlog.json
node scripts/demo_backlog.cjs plan docs/competition-demo/package11-12/backlog.json
```

plan 只列依賴與可送認領確認的項目，不會指派或通知組員；初始完成集合為空。
每個真正認領的 Issue 各開一個成果分支與 PR，base main，不把 34 個硬體任務混進本輪 PR。
有重複 marker／標題時停止，不再建立第二份。關閉前可用 close-check 核對提交者紀錄，但工具不會關閉 GitHub Issue，也不認證影片內容或簽章：

```sh
node scripts/demo_backlog.cjs close-check ./close-record.json --evidence-root ./evidence
```

close-record 至少需 source_commit、實體連續 video 的 file／sha256／kind／continuous、physical_verified 與 human_reviewed；缺任一 exit 2。人工仍須看真正版本與影片。
不代傳每日公告、不替 johnsnow 認領、不新增採購；阻塞半天向既有負責人回報。

## 12：離線與紙本操作

- [現場操作卡](runbook.md)／[四頁 A4 PDF](../../../output/pdf/nudge-demo-operations.pdf)
- [三分鐘口白](presenter-script.md)／[只帶現有物品](inventory-checklist.md)／[現場記錄](onsite-record.template.md)
- [真實待驗狀態](readiness.pending.json)／[目前檢查結果](readiness.status.json)
- [離線準備 ZIP](../../../output/demo/nudge-demo-preparation.zip)／[ZIP SHA-256](../../../output/demo/nudge-demo-preparation.zip.sha256)
- [逐項自評](self-review.md)／[PDF 視覺檢查](pdf-qa.json)

PDF 使用 Noto Sans TC 的內嵌字型子集，四頁均渲染 PNG 檢查，不需上網下載字型才能閱讀；來源與 SIL OFL 見 font-license。
沒有 PDF 可直接讀 Markdown。ZIP 不需網路即可解壓檢視，包含操作文件、四個候選 application image／Gate A log、追溯來源與 PlatformIO pin。
**ZIP 不含真正實機影片、已驗接線、toolchain／library cache 或全新電腦離線安裝器。** 帶原本已配置的筆電，不宣稱另一台電腦已可燒錄。

```sh
python3 scripts/build_demo_kit.py verify output/demo/nudge-demo-preparation.zip
node scripts/demo_runbook.cjs assess docs/competition-demo/package11-12/readiness.pending.json --evidence-root docs/competition-demo/package11-12
```

第二條目前正常 exit 2，表示前一晚／現場紀錄不足。即使將來 exit 0 也只代表可送人工核對，physical_acceptance_certified 永遠 false。
只接受相對路徑、真檔 hash、兩個不同板號、兩條已驗資料線、每台 3 次冷啟動／3 輪、同版本實機影片與副本確認；空白或軟體預覽不當實機通過。

## 與現有韌體能力對齊

1. 自動輪播沒有暫停／停在 Home 的指令；看到 Home 時開始，結尾觀察 Complete／Growth／Summary，不要求雙機同步。
2. 預設重設只寫 USB 斷電 5 秒再接；長按必須該台手勢已實測才採用。已配置 serial 的 R 屬操作者選項，不猜 port 或請教授開終端機。
3. App／BLE 未驗就跳過，不請教授登入／配對。P1 故障忽略效果，不在台上帶電改線。
4. 一台失效用另一台與真正實機影片；兩台都失效且沒有影片，明說非現場即時運作、備援未備妥，不冒充實物。
5. 候選 .bin 是 application image，不能單獨寫到 0x0；Station 檔名 unconfigured，沒有確認接線前不 upload。Git revert 不會回刷硬體。

本輪沒有 upload、真實影片、手機播放驗證、兩條線驗證、三次現場排練、場地／比賽日期或另一位組員確認。
自評僅評使用者授權的準備成果，未完成實機條件另列扣分，不可用 85 分當現場通過證明。
