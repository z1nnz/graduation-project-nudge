# WEB-GAME-06：交付與資料契約

來源 Issue #106；起始基線 main 10cc51c；本輪已同步正式 main 4e3eda4（#101含#107）。三個切片各開 Draft PR，最低85分才上傳，核對 exact-head 六項 CI 後請 z1nnz 審查；保留實機與正式環境驗收，不部署、不合併、不推 main、不 force push。

## 範圍與責任

| 切片 | 頁面 | 來源與操作 |
| --- | --- | --- |
| 紀錄館 | personal-identity | 本人 discipline_identity_snapshots、既有共用 parser 與 refreshDisciplineIdentity callable；不使用本機推算 |
| 紀錄館返回 | 十個 personal 頁＋獨立 museum-demo | town_routes／town_return、固定同站小鎮建築路線；Demo 仍明確標示唯讀虛構展示 |
| 大門 | index、login | 首頁靜態介紹與既有小鎮圖；登入沿 Firebase Auth，成功初始化本人資料後固定 town.html |
| 工具 | 四個 research 頁、presentation | 研究來源未提供時為空狀態；草稿與講稿是使用者文字及靜態說明，可下載，不是研究成果 |
| 營運工具 | operations-economy／room-review／shop-campaign、admin_dashboard | 既有正式商品、角色進化鏈、裝置指派、隱私案件與稽核；缺正式彙總或佇列時明確說明 |

personal-focus 的書桌內部場景屬 #104；本包只加返回連結。#104 的本機未提交工作保留在另一組 worktree，未混入本包。#101（含 #107）已進正式 main。本輪同步 main，保留新版大門與探索小鎮／進入 Nudge 入口；書桌只保留一組共用返回連結與腳本，整合順序由 z1nnz 決定。

## 共用路線、樣式與 bootstrap

- 玩家頁使用 data-town-return，載入 town_routes.js 與 town_return.js；已完成的紀錄館路線分類改為 Cloud。
- 首頁與登入採 town.css 的 --town-* 色票、像素木造大門與羊皮紙；工具採橫向選單與相同木框，移除舊 sidebar、shell、hero split 外框。
- app.js 版本沿 main 的 v27；大門、工具及紀錄館用專用 surface query 避免快取舊 bootstrap。館內主模組升 v2。
- 新 UI 邏輯放 growth_identity.js、town_gate_auth.js、town_tools.js 及各自 CSS；app.js 只增加獨立介面隔離，保留原有 Firebase／App Check 初始化。
- 工具切片需大門切片的 bootstrap 隔離先合併，避免舊 Demo 邏輯在工具頁啟動。

## 帳號與資料邊界

- Auth UID 是個人快照／初始化的唯一身分；匿名、無帳號或不符 parser 的快照不顯示個人數字。
- 身分更新與 listener 都檢查帳號 generation；更新回應不得覆蓋後來的快取／離線或其他帳號狀態。
- 登入只在 users/{auth.uid} 不存在時，以既有初始 schema 建立；保留既有任務及資料，不建立獎勵、staff 權限或新的集合。
- 舊 nudgePostLoginRedirect 不再控制登入目的地；成功後固定進入 town.html。驗證或資料同步失敗保留重試，無成功提示或導向。
- 後台先從 server 讀本人 staff profile，再顯示工作台；換帳號、登出、撤權及讀取拒絕會清空舊資料。讀寫仍受既有 Cloud／Rules 檢查。
- 商品上架／封存仍走 manageCatalogItem；裝置仍走 manageDeviceAssignment；隱私承辦沿原案件流程。客戶端不能直接寫商品、稽核或正式獎勵。
- 研究、經濟彙總與獨立審核佇列未提供正式來源，故不虛構 API、不放固定數字。舊本機折扣成功流程已移除，正式發布集中在既有後台。

## 驗證、保留與回復

三片 source 在乾淨 ASCII 暫存目錄以變更覆蓋方式整合測試，沒有 merge 他人分支。逐項結果、前後與360px截圖、資料 hash、自評與限制在 docs/acceptance/web-game06/slice1–3。

本機完成 Flutter analyze、345 Flutter tests、各分支 Node／Functions、Java21完整CI emulator、58 browser assertions及3項訪客門禁檢查；22頁無水平溢出，21頁 axe A／AA 零違規。personal-focus 的內部無障礙不在本包驗收範圍。

Google／Facebook provider、Storage 實際上傳、production App Check、真人螢幕閱讀器與實機仍待驗。截圖及 callable adapter 僅使用 loopback emulator 與虛構帳號，不能宣稱 production attestation。

沒有新增 Cloud／Rules／schema，無 production migration／seed／apply。回復為 revert 對應切片；沿既有資料保留、隱私匯出與帳號刪除契約，不刪除已有正式資料。
