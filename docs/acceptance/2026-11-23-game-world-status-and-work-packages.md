# Nudge 遊戲世界：遠端進度與續作工作包

盤點時間：2026-11-23。來源：當時的 `origin/main`、`origin/feature/claude-sky-island`、`origin/feature/claude-game-world`、`origin/codex/orbit-screen-demo` 與 PR #65／#75。這是 GitHub 遠端狀態；未檢查 Claude 的本機目錄。

## 使用者提供的五張照片

| 照片 | 遠端可核對的狀態 | 驗收判斷 |
| --- | --- | --- |
| 1、5：Web 小鎮及手機版 | `feature/claude-game-world` 只比小屋分支多一份遊戲世界設計文件；沒有小鎮地圖素材、Canvas 介面或操作測試 | 概念圖，尚未推送可執行的小鎮 |
| 2：Orbit 圓形畫面 | PR #65 的 `docs/specs/orbit-report-preview-v2.png`、韌體繪圖程式與軟體測試已推送 | 軟體預覽；尚未實機驗收，PR 未合併 |
| 3：角色讀書、運動、休息姿勢 | 遊戲世界文件描述 6 系列 × 4 姿勢；遠端無對應姿勢圖或 `CompanionSprite` | 概念／待提交素材，尚未接進 App |
| 4：自律房場景 | 文件描述場景與座位；遠端無場景素材或場景元件 | 概念圖，尚未接進 App |

PR #75 已推送 App 夥伴小屋、家具、Cloud callable 與 Rules，但尚未合併／部署。當時六項 CI 中 Flutter gate 失敗，其餘五項通過。其所依賴的 Windows 修正 PR #73 六項 CI 通過，仍待審查。正式功能應以合併後的 exact head 與實際部署狀態再次驗收。

## 可並行的工作包

### GW-1：角色姿勢與共用元件

- 所有權：`assets/avatar/poses/`、`lib/widgets/companion_sprite.dart` 及專屬測試。
- 交付：先以一個系列完成待機、讀書、休息、運動、慶祝；明確寫出無素材的其他系列之靜態回退。減少動態時停止位移、縮放與粒子動畫。
- 驗收：依房內活動狀態顯示姿勢；Cloud 確認前不播放慶祝；360px 與深色模式截圖。其他系列素材可在同一契約下分批補齊。

### GW-2：自律房場景與成員互動

- 所有權：房間場景素材、`lib/widgets/study_room_stage.dart` 及專屬測試；整合時修改 `study_room_live_page.dart`，須與聊天室 PR 協調。
- 交付：最多 8 個座位，自己在前排，超額顯示 +N；依核准會員投影顯示讀書／休息／離線；點角色顯示合法可見的名稱、狀態與今日時間。共同目標以場景物件呈現。
- 驗收：不同房型、加入／離開、離線、待審核、不具會員身分、減少動態；房主不能控制其他成員活動。依賴 GW-1 的姿勢介面。

### GW-3：App 其他頁面的共用視覺

- 所有權：`lib/theme/game_ui.dart`、任務／圖鑑等頁面的外觀與測試；不修改 Cloud 或 Ledger。
- 交付：委託、角色、商城、家庭、團體、統計、設定使用一致的標題、面板與按鈕；保留既有功能及設定入口。底部導覽依最新設計文件調整。
- 驗收：未登入、空資料、pending、錯誤、360px、深色、減少動態；不得把共同成長算作個人 XP。以 PR #75 合併後的首頁外觀為視覺基準。

### GW-4：Web 夥伴小鎮

- 所有權：`web_dashboard/` 的新地圖頁、素材與 Web 專屬測試；不改 App 與 Cloud 契約。
- 交付：可走動地圖、點擊與鍵盤移動、建築對既有頁面的入口、NPC 導覽、手機操作與靜態導覽回退。先做小鎮與建築入口，再做休息小遊戲。
- 驗收：每棟建築進入正確現有功能；訪客與未授權身分仍由既有路由守衛處理；手機寬度可操作；不使用 Nuva 的圖像或程式素材。

### GW-5：整合與驗收

- 所有權：整合者；不與 GW-1 至 GW-4 同時修改同一檔案。
- 交付：處理 PR #73／#75 的依賴與 CI，檢查 C／D 各切片的 exact head、畫面截圖、權限及跨 App／Web 資料契約。Orbit PR #65 的軟體證據另與硬體組員的實機影片配對。
- 驗收：六項 CI 全過、無 skipped 被算作通過；本機與 GitHub 分支中的圖片、可執行功能、實機證據分開列示。部署、合併與 production migration 仍依專案授權流程。

## 本次 Codex 切片

`codex/study-room-chat-page`：將聊天與固定貼圖移到獨立頁，房內主畫面保留最新訊息預覽與按帳號／房間隔離的本機未讀標記。沿用既有 `addStudyRoomMessage` 與房間事件，不新增獎勵來源，也不變更 Rules。

本機驗收（Windows 11、Flutter 3.41.7、Node 22、JDK 21）：`flutter analyze` exit 0；`flutter test --no-pub --reporter compact` 233 通過；`node --test test/*.js` 136 通過、0 skipped；`npm --prefix functions test` 120 通過、25 skipped。後者跳過的案例沒有算作通過；另以 Java 21 執行 CI 同等的 `firebase emulators:exec --only auth,firestore` Rules／交易命令，exit 0，執行的測試沒有 skipped。聊天室專屬的 widget 與未讀標記測試均通過。尚未做真實帳號或實機畫面驗收。

實際 Flutter 渲染的 360×780 離線示範截圖：`docs/acceptance/screenshots/study-room-chat/chat-360x780.png`。示範資料不是 Cloud 帳號，使用 `tool/study_room_chat_preview_test.dart` 產生。
