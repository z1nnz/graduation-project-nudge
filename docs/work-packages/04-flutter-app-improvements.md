# 04｜Flutter App 改善工作包

## 產品目標

讓第一次使用 Nudge 的人不需理解 Firestore、Ledger 或 BLE，也能知道下一步；
同時讓進階功能仍服從 Cloud 權限、耐久 outbox 和多關係情境。App 是個人行動
主入口，不是 Web 管理後台的縮小版。

## 切片 A｜首次使用與核心循環（P1）

### 使用者旅程

1. 登入與必要隱私選擇。
2. 選擇一個初始角色；解釋角色反映努力而非提供數值優勢。
3. 建立一個小任務或加入一個自律房。
4. 開始一次 5–25 分鐘行動。
5. Cloud Receipt 到達後才顯示正式進度、幣值和角色回應。
6. 提供下一個最小行動，不用一次介紹家庭、團體、健康、裝置全部功能。

### 實作方式

- 建立一個可測的 onboarding state，不以散落在多頁的本機布林值判斷。
- capability 與資料 readiness 決定步驟；沒有健康權限或裝置時仍可完成核心循環。
- 每一步可跳過非必要功能，並能從設定重新開啟教學。
- 文案區分「已存到手機」、「等待同步」、「Cloud 已確認」。

## 切片 B｜關係情境與角色介面（P1）

### 要做什麼

- 頂層清楚顯示目前是個人、某家庭或某團體情境。
- 使用 `relationship_context_switcher.dart` 切換，不改寫其他 active Membership。
- guardian／child、manager／member 顯示不同首頁摘要與操作，不只是把無權按鈕
  disable。
- 找不到或過期 Membership 時 fail closed 並回到個人情境。

### 角色差異

| 情境角色 | 可做 | 不可做 |
| --- | --- | --- |
| guardian | 提出共同目標、鼓勵、查看已同意的趨勢 | 替孩子完成活動、查看未授權健康細節 |
| child | 接受／拒絕、回應鼓勵、控制分享 | 冒充 guardian 變更權限 |
| manager | 管理成員／邀請／團體設定 | 替成員參與或修改成員進度 |
| member | 自主加入活動、分享摘要、退出 | 執行 manager 操作 |

## 切片 C｜裝置設定體驗（P0/P1）

### 畫面結構

- 「我的裝置」：指派狀態、韌體／協定版本、上次同步、允許房間。
- 「連線精靈」：權限 → 掃描 → 選擇 → 驗證指派 → 同步 → 測試。
- 「裝置測試」：螢幕、旋鈕、燈、環境光、提示音，各自顯示結果。
- 「復原」：藍牙關閉、權限拒絕、指派撤銷、context 過期、需 wipe 的清楚指引。

使用 `nudge_device_coordinator.dart` 管理流程，畫面不可直接拼 GATT JSON。

## 切片 D｜離線、同步與衝突（P1）

- 所有 outbox 狀態使用同一組視覺語言：pending、sending、accepted、rejected。
- 相同 event ID 的重送不製造新的完成卡、通知或動畫。
- 權限錯誤不自動無限重試；網路暫時錯誤採有限退避。
- task correction、health correction、focus lifecycle 分別顯示正確來源。
- 使用者登出前若有 pending device event，告知風險但不得用 UI 刪除裝置 queue。

## 切片 E｜角色、圖鑑與成果一致性（P1）

- 商城只顯示完整已發布系列的第一階。
- 圖鑑顯示完整進化鏈、解鎖條件和目前 Cloud XP；未解鎖階不可裝備。
- 家庭樹、團體星球、共同回憶和個人角色在視覺上相關，但資料與 XP 分開。
- 裝置只接收安全的角色名稱、階段、等級和圖示代號，不傳任意遠端 HTML／URL。
- archived 或失效 catalog 更新後，App 快取要可回復到安全預設角色。

## 可用性與無障礙

- 支援文字放大、對比、VoiceOver／TalkBack 標籤和 reduced motion。
- 重要狀態不能只靠顏色；成功、等待、錯誤皆有文字／圖示。
- 使用動畫時避免干擾計時與省電，低階裝置不得因粒子效果卡住 lifecycle 操作。
- 健康與家庭資料的通知／鎖定畫面只顯示安全措辭。

## 測試與證據

- Widget tests：onboarding、情境切換、角色表面、裝置每個狀態、離線重試。
- Contract tests：Membership、catalog、device assignment、Receipt 與 outbox。
- Android emulator：一般 App 流程；真實 Android：BLE 工作包的案例。
- iOS Simulator：乾淨安裝、啟動、登入前畫面和不含 BLE 的核心流程；不宣稱實體
  iPhone 通過。
- 每個 PR 附一條主要旅程和至少兩條失敗旅程的截圖／錄影。

## 不做

- 不讓 App 直接成為 catalog 或 device assignment 的管理後台。
- 不把個人、家庭、團體做成三個互斥帳號。
- 不以動畫完成代表 Cloud Receipt 已完成。
