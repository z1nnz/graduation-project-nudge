# Package 00｜競賽 Demo 範圍採用與交付紀錄

日期：2026-11-14（Asia/Taipei）。任務：`DEMO-00`，P0-A。
本次交付是範圍文件與離線工作包，實機驗收由使用者另行安排。

## 唯一有效的工作包來源

- [Competition Demo Edition v1 README](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/README.md)
- [00｜範圍重設](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/00-scope-reset.md)
- [01｜現有零件與限制](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/01-demo-parts-and-constraints.md)
- [09｜兩人分工與 Git 流程](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/09-two-person-team-and-git-plan.md)

來源分支為 `codex/execution-work-packages`；固定版本
`9ace911bf892dfb3a451acce7e2ecbeb41904f7d`。來源文件透過
[PR #18](https://github.com/z1nnz/graduation-project-nudge/pull/18) 提議合併；
本紀錄不宣稱該 PR 已合併，也不重複修改其 15 份工作包。

## 執行邊界

| 等級 | 工作與進入條件 |
| --- | --- |
| P0-A | 已購買兩台 XIAO ESP32S3 與各自螢幕；Home → Focus → Complete 自動循環；無網路、手機、登入及感測器也可展示；每台冷啟動 3/3、10 秒內進 Home、三幕影片 |
| P0-B | P0-A 全部完成後，才擴充八幕、Restart、10 次重播及 binary／完整影片 |
| P1 | P0-A 全部完成後，只用既有輸入、LED、光感、蜂鳴器；失敗時略過、固定亮度或靜音 |
| P2 | P0-B 凍結且兩台完成 10 次重播後，才考慮 App／BLE 與真實資料；可明確不做 |

不新增採購、焊接、電池、永久外殼或量產驗證要求。未知型號／接線的模組暫停，
不猜 GPIO、線色或電壓。固定資料標記 DEMO，不宣稱正式 Cloud 獎勵或即時同步。
新增需求依 package 00 的五項門檻逐項回答，任一不符即排到比賽後。

預設分工沿用 package 09：johnsnow 負責 Orbit，roy 負責 Station，
z1nnz 裁決範圍、審查與最後合併。這是工作包的預設分工，未代替組員回覆確認。

## 舊版作廢紀錄

| 舊資料 | 處理 |
| --- | --- |
| `Nudge-MD-雙裝置完整工作包-2026-11-04-v2.zip` | **superseded**；SHA-256 `9298b0e15521f8e8ac4f0fbc1262f237d3ac03d0e5ca7f9b5c889a9be585d663`；僅留歷史追溯，不作競賽分工、採購或驗收依據 |
| [舊 32 包固定版本](https://github.com/z1nnz/graduation-project-nudge/tree/7a80aac501e808b91c26b77d24305788af2cb242/docs/work-packages) | **superseded**；舊 HW／CORE 任務、量測與正式 Ledger gate 不自動成為競賽前置 |
| 2026-11-08 硬體盤點／照片 | 可作既有零件的歷史證據；沿用原圖，不沿用舊版 gate 作為競賽必做要求 |

## 新離線 ZIP

在完整 repository checkout 執行：

```sh
python3 scripts/package_demo_work_packages.py /tmp/Nudge-Competition-Demo-Work-Packages-v1.zip
unzip -t /tmp/Nudge-Competition-Demo-Work-Packages-v1.zip
```

腳本從上述固定 Git commit 取得 15 份 Markdown（README 加 00–13），
逐檔保持原始位元組；ZIP 根目錄另有入口 README、VERSION 與 SHA-256 manifest。
ZIP 內不含舊 32 包、runtime、binary、cache 或任何實機通過宣稱。
需先以 `git fetch origin codex/execution-work-packages` 取得來源 commit。

## Package 00 驗收狀態

| 要求 | 本次狀態與證據 |
| --- | --- |
| README 指向新版並作廢舊版 | 本 PR 新增入口及本紀錄 |
| 新 ZIP 指向新版 | 可用上述命令重建；來源及逐檔雜湊隨 ZIP 交付 |
| 所有開放硬體 Issue 標優先級 | 2026-11-14 查詢 [open issues](https://github.com/z1nnz/graduation-project-nudge/issues)：只有文件 PR #18，無獨立開放硬體 Issue 可重分類；未將未建立的 backlog 當作已指派 Issue |
| 兩位組員的 PR 都引用 00 | PR template 已加入固定來源、裝置及優先級欄位；本 PR 引用 00，另一位組員的實際 PR 仍待其提交 |
| 群組公告同步新版 | [公告文案](team-announcement.md)已備妥，尚未發送；待專題負責人轉貼並確認收件 |
| 實體 P0-A／P0-B | 未執行；這兩包文件的交付不代表任何實機已完成 |

回復方式：revert 本 PR 的文件、模板與打包腳本；歷史 ZIP 不刪除、不改寫。
最後合併仍由 z1nnz 執行，六項必要 CI 全綠後才能合併。
