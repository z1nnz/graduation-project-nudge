# 11｜PWA 輕入口與新玩法工作包

## 產品定位

Nudge PWA 不應再複製一套完整 App 或把管理後台直接「加到主畫面」。它的角色是
**30 秒內開始一個小行動、離線時安全排隊、回來時看到角色與共同世界的最新
回應**。複雜的角色上架、裝置指派、家庭／團體管理仍留在 Web Dashboard；實體
BLE 仍由 Android App 負責。

目前 `web/manifest.json` 只有基本 name、icon、start URL、standalone 與方向設定；
尚未定義 PWA 專用快捷入口、豐富安裝資訊、使用者情境路由、PWA 離線資料生命
週期或 Web Push worker 整合。因此第一步是建立可靠的 PWA Module，而不是先做
更多動畫。

## 核心新玩法

### 1. 一鍵「現在做 5 分鐘」

- 從桌面圖示或 PWA shortcut 直接進入 `quick-focus`。
- 預設顯示最近使用的合法活動類型，但開始前仍由使用者確認。
- started／completed 都走既有 Web Activity Ledger outbox；離線只顯示 pending，
  Cloud Receipt 到達後才顯示正式獎勵。
- 完成後角色產生短回應，並讓使用者選「今天到這裡」或另一個小行動。

### 2. 今日脈搏 Today Pulse

首頁只顯示四件事：現在最小一步、角色目前狀態、待同步數量、已選個人／家庭／
團體情境。它不是另一張資料儀表板，不顯示十幾張統計卡。

### 3. 房間營火 Room Campfire

- 顯示目前房間的 opt-in resonance 和固定支援回應，不顯示精確分鐘／健康值。
- 成員可發出一個 24 小時 cue，其他成員可送固定 acknowledgement。
- 沒有人需要同時在線，房主也不負責開始或結束活動。

### 4. 離線救援 Offline Rescue

- 無網路仍可建立本機計時 lifecycle，耐久寫入既有 Web outbox。
- 明確顯示「存在此裝置，尚未經 Cloud 確認」；重新連線後有限退避重送。
- 若登入身分、Membership、房間或 App Check 已失效，事件保留稽核狀態並顯示
  rejected，不把失敗偽裝成完成。

### 5. 角色窗景 Companion Window

安裝後的 PWA 可作為輕量桌面夥伴：角色以最近 Cloud snapshot 顯示 ready、active、
rest、recovery。它只能呈現狀態，不在背景自行建立任務、活動或 reward。

## 建議 Module 與 Seam

### `PwaCapabilityModule`

```text
detectPwaCapabilities() -> PwaCapabilitySet
```

集中檢查 install prompt、service worker、push、badge、shortcut/deep-link fallback 和
storage availability。所有功能都採 capability detection；瀏覽器不支援時仍可從
一般頁面完成核心流程。

### `PwaIntentModule`

```text
resolveLaunchIntent(url, authState, capabilitySet) -> PwaDestination
```

處理 `start_url`、manifest shortcut、通知點擊與一般網址。它只決定安全目的地，
不在 URL 接受 actor、role、coin、XP 或可偽造的房間權限。

### `WebOfflineActionModule`

```text
enqueueActivity(evidence) -> LocalQueueReceipt
flushActivities() -> FlushReport
```

Adapter 必須重用 `web_dashboard/assets/activity_ledger_client.js` 的 stable ID、狀態與
Cloud ingestion，不另建第二套同步。使用者切換或登出時，使用者範圍快取必須隔離
或清除；共用電腦不能看到上一個帳號的私人 snapshot。

### `PwaEngagementSnapshotModule`

```text
loadPwaHome(activeContext) -> PwaHomeSnapshot
```

只彙整正式 Receipt、角色快照、目前 relationship outcome、resonance 和 pending
queue count。Implementation 可跨多個 repository，但畫面只學一個小 Interface。

## 實作切片

### 切片 A｜可安裝與啟動路由（P1）

1. 補齊 manifest 的 `id`、`scope`、brand colors、categories、screenshots，以及少量
   shortcuts：`開始 5 分鐘`、`今日`、`我的房間`。
2. shortcut URL 全部位於同一 PWA scope，登入前先回 auth，登入後才解析情境。
3. 不在首次開頁立刻逼安裝；完成第一個有效行動後才解釋安裝價值。
4. iOS／Android／desktop 安裝方式不同，沒有自訂 prompt 時顯示平台對應說明。

Manifest shortcuts 並非所有常用瀏覽器都支援，因此頁內必須保留同等入口。

### 切片 B｜Service Worker 與離線殼（P1）

- 快取 App shell、版本化靜態角色資產和安全 fallback；不快取 Firebase 私人 response、
  token、完整健康資料或管理頁 HTML。
- 新版本使用明確 update-ready UI，不在活動中途強制 reload。
- Flutter 產生的 worker 與 Firebase Messaging worker 必須設計為一個協調策略；
  不可讓兩個 worker 爭奪相同 scope。FCM 可接收既有 registration。
- Background Sync 只作增強，不是唯一送出機制；不支援時在 foreground flush。

### 切片 C｜Web Push 與 Badge（P1/P2）

- 只在使用者看懂用途並主動開啟後請求通知權限。
- 通知 payload 只含安全 route 和類型，實際內容開啟後由 Cloud 讀取。
- badge 只表示待處理的安全數量，例如未讀支援或待同步，不顯示 streak 壓力數字。
- Push API、badge 或背景能力不可用時，PWA 仍完整可用。

### 切片 D｜跨端接續（P1）

- PWA 建立的 activity 與 App 使用相同 correlation／Receipt 規則。
- PWA 進行中的 focus 可在另一端看見 canonical session，但 v1 不允許兩端同時控制。
- 若 App 接手，PWA 轉成 read-only 並顯示已在另一端繼續。
- 實體裝置控制仍在 Android App；PWA 只提供「在 App 開啟裝置」的安全入口。

## 測試與驗收

- manifest schema、scope、icons、screenshots、shortcut route。
- 已安裝／未安裝、登入／未登入、支援／不支援能力的 route tests。
- 離線 start → complete → 關閉 PWA → 重開 → 上線 flush → 單一 Receipt。
- 使用者 A 登出、B 登入後看不到 A 的 snapshot、outbox 內容或通知 route。
- service worker upgrade 發生在 idle，不中斷 active focus。
- Chrome/Edge Android 或 desktop 做 install smoke；Safari/iOS 做 add-to-home-screen
  fallback。所有特殊能力以 feature detection 為準，不以單一瀏覽器成功代替矩陣。
- accessibility：keyboard、screen reader、reduced motion、只靠顏色以外的狀態。

## 成功指標

- 安裝後從圖示到 started Receipt 的中位時間。
- quick-focus 開始後有效完成率與 rejected/duplicate rate。
- 離線 queue 最終成功率、最長 pending 時間。
- 首次有效行動後的自願安裝率；拒絕安裝不再反覆打擾。
- 通知 opt-in 後的有效回訪率與關閉通知率，避免靠轟炸提高開啟數。

## 明確不做

- 不把 staff 後台快取成可離線管理工具。
- 不用 Web Bluetooth 取代目前 Android BLE acceptance path。
- 不在 service worker 保存長效 Auth/App Check token 或私人健康資料。
- 不以 PWA streak、倒數恐嚇、強制通知或紅點製造焦慮。

## 官方技術參考

- [web.dev：PWA installability](https://web.dev/articles/install-criteria)
- [MDN：manifest shortcuts](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/shortcuts)
- [MDN：Background Sync](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API)
- [MDN：App badge](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Display_badge_on_app_icon)
- [Firebase：Web FCM service worker](https://firebase.google.com/docs/cloud-messaging/web/receive-messages)
