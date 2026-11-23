# Web 功能路線表與小鎮入口契約

- Issue：#82（WEB-GAME-01）切片 0
- 基線：PR #79 `feature/claude-game-world`（`d61afd3`，已含 main `91ba863`、#73、#75）
- 機器可讀版本：`web_dashboard/assets/town_routes.js`
- 測試：`test/town_routes_test.js`（新增頁面若沒有登記在表裡，測試會失敗）

## 原則

1. 小鎮只負責「找得到」和「回得去」。每個頁面原有的登入檢查（`app.js` 的公開頁清單）與角色門禁（`relationship_capabilities.js` 的 `resolveRoleGateRedirect`）不變；小鎮只說明門禁，不授予權限。
2. 只有適合玩家的功能放進世界（`audience: 'player'`）。管理、研究、發表、Demo 工具（`audience: 'tool'`）不放進建築，只在建築列表的「其他工具」區保留標示清楚的入口。
3. 正式獎勵只來自 Cloud Ledger。小鎮與場景只讀 Cloud 資料，或呼叫原有的 callable／outbox；不在前端計算或發放 XP、自律幣。
4. 資料來源分四種：`cloud`（Firestore／callable 正式資料）、`mixed`（正式資料加上固定或示範內容）、`demo`（固定或虛構資料）、`static`（說明頁，沒有使用者資料）。

## 入口契約（給 #83、#84）

| 項目 | 規則 |
| --- | --- |
| 進入小鎮的某棟建築 | `town.html?at=<buildingId>`。只接受 `town_routes.js` 的 `BUILDINGS` 裡的 id，其他值一律忽略，不會產生開放式導向。 |
| 返回小鎮 | 頁面放 `<a data-town-return href="town.html">← 返回小鎮</a>`，載入 `assets/town_routes.js` 與 `assets/town_return.js`。空值會依路線表找出這頁所屬的建築；也可以寫 `data-town-return="tower"` 指定建築。工具頁和未登記的頁面回到小鎮廣場。 |
| 新增場景 | 在 `DESTINATIONS` 加一列或把自己的 `planned` 改成 `available`，並在本文件補一列。測試會檢查 `available` 的頁面必須存在、所有 `.html` 都要登記。 |
| 門禁 | 場景頁自己做登入與角色檢查。`gate` 欄只用來在小鎮顯示說明文字。 |
| 不要做 | 不要在 `town.js`／`town_core.js` 裡寫自己的場景邏輯；不要把新邏輯加進 `app.js`，只做必要接線。 |

已預留、等待其他包合併後再開放的場景（`planned`）：

| id | 頁面 | 建築 | 負責 |
| --- | --- | --- | --- |
| room-chat | `room-chat.html` | 專注塔 | #83 切片 2（PR #90） |
| family-courtyard | `family-courtyard.html` | 家庭庭院 | #83 切片 4（PR #92） |
| group-hall | `group-hall.html` | 團體會館 | #83 切片 4（PR #92） |
| mailbox | `mailbox.html` | 小鎮廣場 | #83 切片 5（PR #93） |
| cabin-scene | `cabin.html` | 你的小屋 | #82 切片 3 |
| garden-scene | `garden.html` | 星光花園 | #82 切片 1／4 |

## 建築對照：#79 原本的落差與修正

| 建築 | #79 目的地 | 問題 | 修正後（切片 1 起） |
| --- | --- | --- | --- |
| 你的小屋 | `personal.html`（個人進階分析） | 名稱是小屋，進去卻是分析入口 | 書桌專注、名片與角色；切片 3 加入 Web 小屋場景。個人分析移到紀錄館 |
| 委託告示板 | `dashboard.html` | 可用，但總覽頁大多是介紹文字 | 今日下一步與任務清單；切片 2 改成場景內告示板 |
| 雜貨店 | `profile.html`（個人名片） | 說是商城，進去是名片 | `operations.html` 角色商城 |
| 天文台 | `personal-focus.html`（專注） | 說明寫 Orbit／Station 裝置，進去是專注計時；Web 沒有裝置頁 | `planet.html` 自律星球。裝置綁定只在 App，天文台不再宣稱裝置功能 |
| 星光花園 | 沒有目的地 | Lv 10 解鎖後仍無處可去 | `garden.html` 真正的場景；未解鎖時顯示目前等級與條件 |
| （無） | — | 通知、隱私、好友沒有建築 | 新增「小鎮廣場」：郵箱／通知、好友、隱私、登入 |

## 逐頁路線表

登入欄：「公開」代表 `app.js` 的公開頁清單（`/`、`index`、`dashboard`、`town`、`login`、`admin_dashboard`），未登入也能開；「登入」代表未登入會被導到 `login.html`，登入後經 `nudgePostLoginRedirect` 回到原頁。

### 世界內的玩家功能

| 頁面 | 用途 | 登入／角色限制 | 資料來源 | 小鎮入口 | 返回路線 | 負責 |
| --- | --- | --- | --- | --- | --- | --- |
| `town.html` | 夥伴小鎮 | 公開；訪客只看導覽 | cloud：本人 `users/{uid}`、`activity_receipts`（唯讀） | — | — | #82 |
| `personal-focus.html` | 書桌專注計時 | 登入 | cloud：`queueWebStandaloneFocusLedgerEvent` → Activity Ledger outbox → `recordActivity`。目前計時狀態只在記憶體，重新整理會中斷（切片 2 修正） | 你的小屋 | `town.html?at=cabin` | #82 |
| `profile.html` | 我的名片、角色與徽章 | 登入 | cloud：本人 `users`、`public_profiles` | 你的小屋 | `town.html?at=cabin` | #82 |
| `dashboard.html` | 今日下一步、Web 功能介紹 | 公開；未登入顯示登入提示 | mixed：`daily_next_action.js` 讀本人任務與最新收據；其餘為介紹文字 | 委託告示板 | `town.html?at=board` | #82 |
| `planet.html` | 任務清單與自律星球 | 登入 | mixed：任務讀寫本人 `users.tasks`，勾選經 `queueWebTaskLedgerEvent`；星球讀 `unlockedPlanets`，但沒有登入身分時會退回示範帳號 `an_nudge`，且用 `planetCount` 自動補星球（切片 3 移除或標示） | 告示板（任務）、天文台（星球） | `town.html?at=observatory` | #82 |
| `rooms.html` | 自律房 | 登入；房主只管資格，不控制成員活動 | cloud：`rooms`、`activity_sessions`、`recordActivity` | 專注塔 | `town.html?at=tower` | #83 |
| `guardian.html` | 家長陪伴中心 | 登入；需已連結家庭（`canViewGuardianHub`），否則導到 `guardian-link.html` | cloud：`family_links`、`relationship_memberships`、`relationship_outcomes` | 家庭庭院 | `town.html?at=family` | #83 |
| `guardian-link.html` | 連結家人 | 登入 | cloud：親屬邀請 | 家庭庭院 | `town.html?at=family` | #83 |
| `guardian-report.html`、`guardian-encouragement.html`、`guardian-goals.html`、`guardian-permissions.html` | 週報、鼓勵卡、共同目標、資料同意 | 登入；同 `guardian.html` 家庭門禁 | cloud：`family_links` 子集合 | 家庭庭院 | `town.html?at=family` | #83 |
| `groups.html` | 團體任務與共同進度 | 登入；需已加入團體，否則顯示加入提示 | cloud：`groups`、`relationship_memberships` | 團體會館 | `town.html?at=guild` | #83 |
| `groups-link.html` | 加入或建立團體 | 登入 | cloud：團體邀請 | 團體會館 | `town.html?at=guild` | #83 |
| `groups-ranking.html` | 團體成果排行 | 登入；團體成員 | cloud：`member_summaries` | 團體會館 | `town.html?at=guild` | #83 |
| `groups-challenge.html`、`groups-study-schedule.html`、`groups-templates.html` | 挑戰、讀書時段、考試模板 | 登入；只限團體管理者，成員導回 `groups.html`，未加入導到 `groups-link.html` | cloud：`groups/{id}` 發布內容 | 團體會館 | `town.html?at=guild` | #83 |
| `personal.html` | 個人分析入口（紀錄館） | 登入 | mixed（#84 切片 1 正在把固定數字換成正式資料或空狀態） | 紀錄館 | `town.html?at=library` | #84 |
| `personal-identity.html` | 自律人格與復原步驟 | 登入 | cloud：`discipline_identity_snapshots`、`refreshDisciplineIdentity` | 紀錄館 | `town.html?at=library` | #84 |
| `personal-trends.html`、`personal-skill-tree.html`、`personal-weather.html`、`personal-pressure.html`、`personal-template.html`、`personal-letter.html`、`personal-time-capsule.html` | 紀錄館各分析工具 | 登入 | demo：目前是固定數字（#84 負責改成正式資料） | 紀錄館 | `town.html?at=library` | #84 |
| `operations.html` | 角色商城 | 登入 | cloud：`shop_items`（published）、`purchaseRewardItem`。目前頁面腳本有語法錯誤，商品不會載入；另有讀 `localStorage` 折扣、直接跳「兌換成功」的假流程（切片 3 修正） | 雜貨店 | `town.html?at=store` | #82 |
| `notifications.html` | 通知、邀請、提醒設定 | 登入 | cloud：`user_notifications`、`notification_preferences` | 小鎮廣場（郵箱） | `town.html?at=plaza` | #83 |
| `friend.html`、`friend-visits.html` | 好友與拜訪紀錄 | 登入 | cloud：`friend_requests`、`users/{uid}/friends`、`public_profiles` | 小鎮廣場 | `town.html?at=plaza` | #83 |
| `privacy.html` | 健康資料同意、匯出與刪除申請 | 登入 | cloud：`privacy_consents`、`privacy_data_requests` | 小鎮廣場 | `town.html?at=plaza` | core |
| `login.html` | 登入／註冊 | 公開 | cloud：Firebase Auth | 小鎮廣場（訪客） | 登入後回到原頁 | core |
| 遊樂園（`town.html` 內） | 接星星休息遊戲 | 登入；需要休息券 | cloud：本人 25 分鐘以上的專注收據；分數只存本機，不換獎勵 | 遊樂園 | 遊戲結束留在小鎮 | #82 |

### 不放進世界的工具頁

這些頁面在建築列表最下方的「其他工具」區列出，並標示用途；不放進任何建築。

| 頁面 | 用途 | 登入／角色限制 | 資料來源 | 入口 | 返回 |
| --- | --- | --- | --- | --- | --- |
| `index.html` | 產品介紹首頁 | 公開 | static | 其他工具 | 小鎮廣場 |
| `planet-builder.html` | 星球建築規劃器 | 登入 | demo | 其他工具 | 小鎮廣場 |
| `operations-economy.html` | 自律幣經濟檢查 | 登入（頁面本身沒有營運身分檢查） | static | 其他工具 | 小鎮廣場 |
| `operations-room-review.html` | 自律房審核 | 登入（同上） | static | 其他工具 | 小鎮廣場 |
| `operations-shop-campaign.html` | 商城活動配置 | 登入；直接寫 `shop_items`，實際由 Rules 拒絕非營運人員 | mixed | 其他工具 | 小鎮廣場 |
| `admin_dashboard.html` | 營運後台（目錄、裝置指派） | 公開頁；寫入經 `manageCatalogItem`、`manageDeviceAssignment`，由 Cloud 檢查營運身分 | cloud | 其他工具 | 小鎮廣場 |
| `research.html`、`research-anonymized.html`、`research-scenario.html`、`research-score-demo.html` | 研究與展示 | 登入 | demo | 其他工具 | 小鎮廣場 |
| `presentation.html` | 專題發表流程 | 登入 | demo | 其他工具 | 小鎮廣場 |

## 已知風險

- PR #86–#89（核心組，疊在 #79 上的 Draft）也修改 `town.html`。本包以 #79 為 base；若那串先合併，需要重新整合 `town.html`，衝突預期只在 `<script>` 與工具列。
- 其他包預留的場景要等各自 PR 合併後才改成 `available`，在那之前小鎮顯示「建造中」，不會連到不存在的頁面。
- 營運工具頁本身沒有營運身分檢查，只靠 Cloud／Rules 拒絕寫入。本包不改這些頁面，只在小鎮標示為工具。
