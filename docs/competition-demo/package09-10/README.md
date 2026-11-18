# 09／10：分工交接與驗收準備

日期：2026-11-19。依使用者要求先完成可審查的文件／工具，逐包自評至少 85 再上傳；實機稍後驗收。

需求固定於 Competition Demo v1：
[09 分工與 Git](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/09-two-person-team-and-git-plan.md)、
[10 測試與排練](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/10-demo-test-rehearsal-acceptance.md)。

**本輪完成驗收準備，沒有完成實機驗收，也沒有取得另一位組員的認領／交接確認。分數不是實機通過率。**

## 查重

查全部 25 個 PR、26 個分支、Issue 與 #18／#25 留言；Issue 清單只有 PR，沒有獨立 Issue。沒有新版 09／10 的專屬成果。
既有 CONTRIBUTING、PR template 與 #23–25 的測試是可沿用基礎，尚缺具體協作交接、跨 Gate 的紀錄工具、三次排練與兩位觀看者表。
不能排除他人未推送的本機工作。沒有變更其他人的分支或代替組員答覆。

## 交付

- [09 分工、檔案責任、Git、PR／衝突／每日回報](package09-team-plan.md)
- [10 Gate A–G、次數、觀看、三次排練、凍結](package10-acceptance-runbook.md)
- [現場填寫與交接表](operator-sheet.md)
- [可直接填寫的 PR／Issue／每日回報模板](handoff-template.md)
- [逐項驗收與自評](self-review.md)
- [待驗原始紀錄](physical-record.pending.json)／[目前紀錄檢查結果](physical-status.json)
- [Gate A clean build、四個 binary 與 hash](build-evidence/gate-a/gate-a.json)
- [版本來源鎖定](source-lock.json)／[分工與確認狀態](coordination.json)
- [查重紀錄](duplicate-audit.json)／[本輪準備證據與工具 hash](preparation-evidence.json)

`scripts/demo_gate_a.cjs` 在指定的韌體 checkout 跑既有三個 native 測試、額外重播探針，以及四環境 clean build。
`scripts/demo_acceptance.cjs` 驗證後續持板者填寫的紀錄與本機影片 hash；不是影片內容辨識，也不會自動認證實機。
只驗紀錄完整性，即使資料完整仍保留 `physical_acceptance_certified=false`，必須由 z1nnz 看實物影片與記錄後裁定。

## 分支與依賴

本輪由最新 main `c37c6ab` 建立獨立工作樹／分支。只沿用 #21 的既有 iOS metadata checksum 修復，以維持嚴格 CI；其版本與依賴沒有變更。
沒有將未合併 #23／#24／#25 韌體、App 或其整包歷史帶進這個 PR；只在本機對固定 #25 checkout 執行 Gate A。
維護者可先合併 #21，使本 PR 的那兩個既有檔案自然退出差異。
固定韌體參考是 #25 的 c4cb9fa，非 main 已具備的功能；正式裝置整合仍需等待相應 PR 審查合併。

本輪不修改 driver、場景引擎、App／Web／Cloud／Ledger、工作流程、接線或實體模組；P1／BLE 仍 OFF。
Station binary 明示 unconfigured；仍無已確認獨立主控與接線，不能作已可點亮的證據。
Gate A 產物是 application image，不能單獨寫到 0x0；持板者稍後依已審來源用 PlatformIO upload 處理分區與 bootloader。

## 快速檢查待驗狀態

在 repository root 執行：

```sh
node scripts/demo_acceptance.cjs assess docs/competition-demo/package09-10/physical-record.pending.json --evidence-root docs/competition-demo/package09-10 --today 2026-11-19
```

預期 exit **2**，代表實機紀錄不足；不是命令故障，也不是實機通過。exit 1 是格式／讀取錯誤，exit 0 只代表可送人工審核的紀錄完整。
初始檔只預填來源與軟體 build hash，沒有宣稱曾燒到板上；實際版本不同時必須用真正建置／profile／binary 替換。
本輪沒有傳送團隊公告、替另一位組員認領、建立交換裝置紀錄或編造觀看者回饋。
