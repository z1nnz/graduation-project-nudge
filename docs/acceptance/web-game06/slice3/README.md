# WEB-GAME-06｜切片 3：研究、發表與營運工作台

Refs #106；base main @ 10cc51c。全部保持 Draft，審查與合併交給 z1nnz。不部署、不推 main、不 force push。

## 逐項核對

| 驗收指標 | 實際結果 |
| --- | --- |
| 九個工具頁去除舊 sidebar／shell／hero split 外框，改橫向選單、木框羊皮紙與金色主按鈕 | source 已完成，本機對應情境通過；非 production 驗收 |
| 研究彙總、經濟彙總、獨立審核佇列尚無正式來源：明確空狀態，不顯示假樣本／人數／健康推論 | source 已完成，本機對應情境通過；非 production 驗收 |
| 草稿由本人輸入，可產生、更新後失效、下載；發表講稿切換／複製／下載真的完成操作 | source 已完成，本機對應情境通過；非 production 驗收 |
| 舊 Demo 商品發布集中回正式 admin 上架流程；移除本機假折扣與偽造全站圖表／發布假交易列 | source 已完成，本機對應情境通過；非 production 驗收 |
| 保留正式上架／封存、完整進化鏈驗證、裝置指派、隱私案件與不可變 Cloud 稽核 | source 已完成，本機對應情境通過；非 production 驗收 |
| 後台 server role 確認、本人帳號與回應綁定、撤權／登出清空，未授權帳號無後台資料 | source 已完成，本機對應情境通過；非 production 驗收 |
| 修正隱藏頁籤巢狀結構、文字對比、商品圖片 alt，inline script 回歸語法測試 | source 已完成，本機對應情境通過；非 production 驗收 |

## 自評與保留

內容 24/25、任務指標 30/35、驗證 19/25、交接 14/15，**87/100**。最低85才上傳。
扣分包含正式環境、第三方登入／Storage、真人輔具與實機未驗；這些項目沒有計為通過。
個人書桌 personal-focus 的場景內部由 #104 負責；本包只接返回小鎮，未冒稱完成書桌場景。

## 實際測試

- 本分支 Node：232 pass、3 skip、0 fail。
- 本分支 Functions：136 pass、28 skip、0 fail；skip 不算通過。
- 三片整合目錄 Flutter analyze：No issues；Flutter test：345 pass。未改 Dart。
- Java21／Firebase CLI15.18.0：按 CI project 跑完整 Rules／Ledger／帳號刪除／關係／Reward emulator，exit0。前一次不同 Auth project 的失敗不計通過。
- 瀏覽器58項檢查通過；22頁360px無水平溢出；21頁 axe WCAG A／AA 零違規。personal-focus 只驗返回及版面，內部介面非本包範圍。
- 真實本機 Auth／Firestore SDK；callable 使用 loopback test handler adapter，Storage／App Check 為未使用的介面 stub，不能冒稱 production attestation 或檔案上傳驗收。
- SDK對外 HTTPS 全部阻擋；截圖都是明確標示的本機虛構帳號，不是正式網站或真人帳號。

## 測試發現及修正

1. 舊身分更新回應可能覆蓋離線狀態：加入版本與 auth generation 檢查。
2. 登出成功時 busy 狀態讓提示未更新：成功登出後立即改成待登入提示。
3. 後台外框轉換的換行與頁籤巢狀問題：修正結構，加入 inline script 語法回歸與實際頁籤操作。
4. 後台對比與商品圖片替代文字：修正後21頁 axe 零違規。

## 每頁前後證據

修改前為原 main 的靜態 HTML（未載入服務或舊圖表程式），修改後是三切片本機整合頁。額外標記為測試環境；不代表任一單片無依賴即可上線。

| 頁面 | 修改前 | 修改後 | 360px／減少動態 |
| --- | --- | --- | --- |
| research.html | [前](before-research.png) | [後](after-research.png) | [手機](mobile-research.png) |
| research-scenario.html | [前](before-research-scenario.png) | [後](after-research-scenario.png) | [手機](mobile-research-scenario.png) |
| research-anonymized.html | [前](before-research-anonymized.png) | [後](after-research-anonymized.png) | [手機](mobile-research-anonymized.png) |
| research-score-demo.html | [前](before-research-score-demo.png) | [後](after-research-score-demo.png) | [手機](mobile-research-score-demo.png) |
| presentation.html | [前](before-presentation.png) | [後](after-presentation.png) | [手機](mobile-presentation.png) |
| operations-economy.html | [前](before-operations-economy.png) | [後](after-operations-economy.png) | [手機](mobile-operations-economy.png) |
| operations-room-review.html | [前](before-operations-room-review.png) | [後](after-operations-room-review.png) | [手機](mobile-operations-room-review.png) |
| operations-shop-campaign.html | [前](before-operations-shop-campaign.png) | [後](after-operations-shop-campaign.png) | [手機](mobile-operations-shop-campaign.png) |
| admin_dashboard.html | [前](before-admin_dashboard.png) | [後](after-admin_dashboard.png) | [手機](mobile-admin_dashboard.png) |

## 依賴、限制與回復

- 三個切片皆從 main 獨立建立；本機用變更覆蓋整合，沒有 merge 他人的分支。
- 工具切片需先整合大門切片的 shared bootstrap 隔離；館內主模組使用 v2，新 shared app URL 沿 main v27 並加 surface query。
- #107 同樣修改首頁，沒有複製其分支；與 #104／#105 的設施／社交頁保持分工，整合順序由 z1nnz 裁決。
- 無新增 Cloud、Rules、集合或資料欄位；無 production migration／seed／apply，回復為 revert 對應切片。既有保護與正式 Cloud 契約維持。
- 研究與經濟彙總、獨立房間審核佇列尚無正式來源，故為空狀態；需要新的資料產品時另行審查。
- 真人螢幕閱讀器、實機、正式 App Check、Google／Facebook provider 與 Storage 上傳留待驗收，Issue 不冒稱全部 production 完成。
- exact-head六項 CI 待上傳後核對，最終結果補在 PR；此處不把尚未執行的遠端檢查寫成通過。
