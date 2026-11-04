# Nudge 後續開發工作包

- 基準版本：`origin/main` @ `c37c6ab`
- 建立日期：2026-10-25
- 適用範圍：Flutter App、Web Dashboard、Cloud、資料契約、實體裝置韌體與驗收
- 使用對象：專題組員、外部協作者、AI coding agent、最後審查與合併者

這個目錄不是願望清單，而是一組可分支、可測試、可驗收的開發工作包。每份
文件都說明目前基線、要解決的問題、建議修改位置、實作順序、測試方式、驗收
證據與明確不做的範圍。執行者一次只領取一個可獨立驗收的切片，不得把整份
工作包塞入同一個 PR。

## 先讀哪一份

1. [`00-author-guide.md`](00-author-guide.md)：所有寫作者與開發者的共同規則。
2. [`01-current-state-and-priorities.md`](01-current-state-and-priorities.md)：先確認什麼
   已完成、什麼只完成程式碼、什麼仍未驗收。
3. 再依任務選擇下列工作包。

| 編號 | 工作包 | 主要成果 | 優先級 |
| --- | --- | --- | --- |
| 02 | [韌體與硬體 Bring-up](02-firmware-and-hardware-bringup.md) | 螢幕、旋鈕、燈條、環境光、蜂鳴器可重現的實機證據 | P0 |
| 03 | [裝置協定與 Android BLE](03-device-protocol-and-android-ble.md) | 真實手機到裝置、App outbox、Cloud Ledger 的可靠閉環 | P0 |
| 04 | [Flutter App 改善](04-flutter-app-improvements.md) | 清楚的首次使用、裝置設定、關係切換與失敗復原 | P1 |
| 05 | [Web 與後台改善](05-web-and-admin-improvements.md) | 權限導覽、角色上架、裝置指派與營運稽核 | P1 |
| 06 | [Cloud、Ledger 與資料安全](06-cloud-ledger-security-and-data.md) | 統一真相、稽核、遷移與未來裝置可信身分 | P1/P2 |
| 07 | [家庭、團體、自律房與角色成果](07-relationships-rooms-and-characters.md) | 讓社群功能有誘因但不奪走個人自主權 | P1 |
| 08 | [新功能與產品實驗](08-new-features-and-experiments.md) | 有特色且可量測的下一批功能，不先堆大型功能 | P2 |
| 09 | [品質、發布與驗收](09-quality-release-and-acceptance.md) | 自動測試、實機矩陣、證據、回復與發布門檻 | P0 |
| 10 | [交付模板](10-delivery-templates.md) | Issue、PR、驗收紀錄與交接的可複製格式 | 共用 |
| 11 | [PWA 輕入口與新玩法](11-pwa-companion-and-new-play.md) | 可安裝、快速開始、離線續傳與低打擾回訪 | P1 |
| 12 | [App 吸引力與留存循環](12-app-delight-and-retention.md) | 把分散功能收斂成有角色、有回應的每日體驗 | P1 |
| 13 | [雙裝置總體計畫](13-dual-device-master-plan.md) | Nudge Orbit 圓形穿戴裝置與 Nudge Station 方形桌機的產品分工 | P0 |
| 14 | [共用韌體架構與協定](14-shared-firmware-architecture.md) | 共用核心加兩套硬體 Adapter，避免複製兩份韌體 | P0 |
| 15 | [Orbit 產品規格](15-orbit-wearable-product-spec.md) | 圓形螢幕的穿戴式個人夥伴體驗 | P1 |
| 16 | [Orbit 開發工作包](16-orbit-wearable-work-package.md) | 從圓屏 bring-up 到 App／Cloud 驗收的完整流程 | P0/P1 |
| 17 | [Station 產品規格](17-station-focus-hub-product-spec.md) | 方形螢幕與感測器整合的桌上專注中樞 | P1 |
| 18 | [Station 開發工作包](18-station-focus-hub-work-package.md) | 方屏、旋鈕、光感、燈條、蜂鳴器與 Ledger 閉環 | P0/P1 |
| 19 | [雙裝置測試與驗收](19-dual-device-test-and-acceptance.md) | 單元、硬體、BLE、App、Cloud、壓力與安全證據矩陣 | P0 |
| 20 | [組員執行與交接](20-dual-device-team-execution.md) | Issue、分支、PR 順序、責任分工與交付格式 | 共用 |
| 21 | [Orbit 功能目錄與畫面地圖](21-orbit-feature-catalog.md) | 圓形穿戴裝置的完整畫面、功能、狀態與互動 | P1 |
| 22 | [Station 功能目錄與畫面地圖](22-station-feature-catalog.md) | 方形桌機的完整畫面、周邊、專注與房間功能 | P1 |
| 23 | [角色、敘事與收藏系統](23-device-character-and-story-system.md) | 讓兩台裝置有持續成長感，但不建立第二套獎勵 | P1/P2 |
| 24 | [跨裝置連續體驗](24-cross-device-continuity.md) | Orbit、Station、App、PWA 與 Web 的接續及衝突處理 | P1 |
| 25 | [感測器智慧與環境行為](25-sensor-intelligence.md) | 光感、輸入、在席候選與 presentation policy | P1/P2 |
| 26 | [視覺、動態、聲音與觸覺語言](26-embedded-experience-language.md) | 跨圓屏、方屏、LED、聲音的一致設計系統 | P1 |
| 27 | [設定、診斷、更新與生命週期](27-device-settings-diagnostics-lifecycle.md) | 配對、自檢、fault、更新、重設、撤銷與轉移 | P0/P1 |
| 28 | [隱私、安全、無障礙與倫理](28-device-privacy-safety-accessibility.md) | 裝置資料最小化、安全護欄與包容性操作 | P0 |
| 29 | [功能優先級與版本路線](29-dual-device-release-roadmap.md) | MVP、完整專題版、進階版的依賴和停止條件 | P0/P1/P2 |
| 30 | [可分派 Issue Backlog](30-dual-device-issue-backlog.md) | 依 Wave 排好的細粒度 Issue、驗收與依賴 | 共用 |

## 建議執行順序

```mermaid
flowchart LR
  A[確認 main 與測試基線] --> B[02 螢幕獨立 Bring-up]
  A --> C[04 App / 05 Web 可用性改善]
  B --> D[02 完整周邊整合]
  D --> E[03 真實 Android BLE]
  E --> F[完整 Device → App → Ledger → Web 驗收]
  C --> F
  G[06 Cloud 與資料安全] --> F
  H[07 產品關係成果] --> C
  K[11 PWA 輕入口] --> C
  L[12 App 每日體驗] --> C
  M[13 雙裝置產品分工] --> N[14 共用韌體核心]
  N --> O[16 Orbit 工作包]
  N --> P[18 Station 工作包]
  O --> Q[19 雙裝置驗收]
  P --> Q
  F --> I[09 專題版凍結與展示驗收]
  I --> J[08 P2 實驗與商用強化]
```

韌體 Bring-up、App/Web 體驗改善可以平行進行，但「嵌入式系統已整合」必須
等真實 Android 手機、實體裝置、App outbox、Cloud Ledger、Web/房間/角色成果
整條鏈都有證據後才能宣稱完成。

## 全系統不可破壞的規則

- Cloud Activity Ledger 是活動、房間貢獻與獎勵的正式真相。
- App、Web、韌體不得直接增加自律幣、角色 XP 或正式成果。
- 家長不能替孩子控制活動；管理者不能替成員開始、暫停或完成活動。
- 同一活動可在多個獲授權情境中顯示，但只能結算一次個人獎勵。
- 家庭／團體角色取自有效 `relationship_memberships`，不能從本機角色選項猜測。
- 只有完整且已發布的三階角色鏈可進入圖鑑；商城只販售第一階。
- 裝置收到 GATT write 不代表已持久化；必須回報相同 `contextRevision`。
- 裝置事件只有先耐久寫入 App Ledger outbox 才能 ACK；重送不得重複計分。
- 不把 Simulator、編譯成功或燒錄成功寫成實體顯示／BLE／Cloud 驗收成功。
- 不提交 Token、service account、`.env`、真實使用者資料或可識別健康資料。

## 狀態標籤

每個 Issue、PR 與驗收紀錄都使用同一套標籤：

- `implemented`：程式碼已存在且自動測試通過。
- `source-verified`：介面與行為有程式碼／測試證據，但尚未在目標環境操作。
- `device-verified`：指定實體裝置與版本已完成重現測試。
- `production-verified`：已在正式 Cloud／真實帳號完成並保存清理結果。
- `deferred`：刻意不納入目前里程碑，並有清楚理由。
- `blocked`：缺少硬體、帳號、權限或外部服務，且已列出解除條件。

不要用「完成」同時代表以上不同層級。
