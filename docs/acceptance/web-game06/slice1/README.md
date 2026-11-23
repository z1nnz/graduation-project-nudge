# WEB-GAME-06｜切片 1：紀錄館收尾與小鎮返回

Refs #106；起始 base main @ 10cc51c；已同步 main @ 4e3eda4（#101含#107）。全部保持 Draft，審查與合併交給 z1nnz。不部署、不推 main、不 force push。

## 逐項核對

| 驗收指標 | 實際結果 |
| --- | --- |
| personal-identity 改為既有紀錄館場景；只讀本人 private Cloud snapshot，解析既有共用契約 | source 已完成，本機對應情境通過；非 production 驗收 |
| 明確缺資料／快取／拒讀／更新失敗；更新結果不覆蓋後來的離線與換帳號狀態 | source 已完成，本機對應情境通過；非 production 驗收 |
| 十個 personal 頁面均載入 town_routes／town_return 並標 data-town-return，回到對應建築門口 | source 已完成，本機對應情境通過；非 production 驗收 |
| 回收 dashboard fallback 與 HEAD 探測；沿 main app.js?v=27，用新 cache key 與場景模組版本避免舊腳本 | source 已完成，本機對應情境通過；非 production 驗收 |
| 身分回饋與下一步不診斷、不自發獎勵；明確標示的獨立 Demo 保持唯讀 | source 已完成，本機對應情境通過；非 production 驗收 |

## 自評與保留

內容 25/25、任務指標 31/35、驗證 20/25、交接 14/15，**90/100**。最低85才上傳。
扣分包含正式環境、第三方登入／Storage、真人輔具與實機未驗；這些項目沒有計為通過。
個人書桌 personal-focus 的場景內部由 #104 負責；本包只接返回小鎮，未冒稱完成書桌場景。

## 實際測試

- 本分支 Node：250 pass、3 skip、0 fail。
- 本分支 Functions：136 pass、28 skip、0 fail；skip 不算通過。
- 三片整合目錄 Flutter analyze：No issues；Flutter test：345 pass。未改 Dart。
- Java21／Firebase CLI15.18.0：按 CI project 跑完整 Rules／Ledger／帳號刪除／關係／Reward emulator，exit0。前一次不同 Auth project 的失敗不計通過。
- 瀏覽器58項檢查及另外3項訪客／登入門禁檢查通過；22頁360px無水平溢出；21頁 axe WCAG A／AA 零違規。personal-focus 只驗返回及版面，內部介面非本包範圍。
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
| personal.html | [前](before-personal.png) | [後](after-personal.png) | [手機](mobile-personal.png) |
| personal-identity.html | [前](before-personal-identity.png) | [後](after-personal-identity.png) | [手機](mobile-personal-identity.png) |
| personal-trends.html | [前](before-personal-trends.png) | [後](after-personal-trends.png) | [手機](mobile-personal-trends.png) |
| personal-weather.html | [前](before-personal-weather.png) | [後](after-personal-weather.png) | [手機](mobile-personal-weather.png) |
| personal-pressure.html | [前](before-personal-pressure.png) | [後](after-personal-pressure.png) | [手機](mobile-personal-pressure.png) |
| personal-skill-tree.html | [前](before-personal-skill-tree.png) | [後](after-personal-skill-tree.png) | [手機](mobile-personal-skill-tree.png) |
| personal-template.html | [前](before-personal-template.png) | [後](after-personal-template.png) | [手機](mobile-personal-template.png) |
| personal-letter.html | [前](before-personal-letter.png) | [後](after-personal-letter.png) | [手機](mobile-personal-letter.png) |
| personal-time-capsule.html | [前](before-personal-time-capsule.png) | [後](after-personal-time-capsule.png) | [手機](mobile-personal-time-capsule.png) |
| personal-focus.html | [前](before-personal-focus.png) | [後](after-personal-focus.png) | [手機](mobile-personal-focus.png) |
| museum-demo.html | [前](before-museum-demo.png) | [後](after-museum-demo.png) | [手機](mobile-museum-demo.png) |

## 依賴、限制與回復

- 三個切片皆從 main 獨立建立；本機用變更覆蓋整合，只同步正式 main，沒有合併他人的功能分支。
- 工具切片需先整合大門切片的 shared bootstrap 隔離；館內主模組使用 v2，新 shared app URL 沿 main v27 並加 surface query。
- #101（含 #107）已進 main；本輪同步後保留公開探索與舊總覽入口。#104／#105 設施／社交頁依原分工。
- 無新增 Cloud、Rules、集合或資料欄位；無 production migration／seed／apply，回復為 revert 對應切片。既有保護與正式 Cloud 契約維持。
- 研究與經濟彙總、獨立房間審核佇列尚無正式來源，故為空狀態；需要新的資料產品時另行審查。
- 真人螢幕閱讀器、實機、正式 App Check、Google／Facebook provider 與 Storage 上傳留待驗收，Issue 不冒稱全部 production 完成。
- exact-head六項 CI 待上傳後核對，最終結果補在 PR；此處不把尚未執行的遠端檢查寫成通過。
