# WEB-GAME-06｜切片 2：小鎮大門與登入

Refs #106；base main @ 10cc51c。全部保持 Draft，審查與合併交給 z1nnz。不部署、不推 main、不 force push。

## 逐項核對

| 驗收指標 | 實際結果 |
| --- | --- |
| 首頁以既有小鎮素材、木造大門與紫金色票呈現；訪客入口 town.html，不寫入假身分或假統計 | source 已完成，本機對應情境通過；非 production 驗收 |
| 原生登入／註冊按鈕、具標籤表單、密碼顯示、錯誤後可重試；Google／Facebook 沿 Firebase provider | source 已完成，本機對應情境通過；非 production 驗收 |
| Email 真實 Auth emulator 登入與註冊、確認密碼錯誤、登出與既有登入帳號繼續皆可操作 | source 已完成，本機對應情境通過；非 production 驗收 |
| 本人 profile 交易只在不存在時建立；重試保留既有任務，不初始化獎勵或 staff 權限 | source 已完成，本機對應情境通過；非 production 驗收 |
| 登入完成固定 town.html，清除舊任意 redirect；身分驗證或資料同步未完成不冒稱成功 | source 已完成，本機對應情境通過；非 production 驗收 |
| 最小 app.js 隔離大門／工具，保留既有 Firebase/App Check 初始化；工具切片需此隔離先合併 | source 已完成，本機對應情境通過；非 production 驗收 |

## 自評與保留

內容 25/25、任務指標 30/35、驗證 20/25、交接 14/15，**89/100**。最低85才上傳。
扣分包含正式環境、第三方登入／Storage、真人輔具與實機未驗；這些項目沒有計為通過。
個人書桌 personal-focus 的場景內部由 #104 負責；本包只接返回小鎮，未冒稱完成書桌場景。

## 實際測試

- 本分支 Node：231 pass、3 skip、0 fail。
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
| index.html | [前](before-index.png) | [後](after-index.png) | [手機](mobile-index.png) |
| login.html | [前](before-login.png) | [後](after-login.png) | [手機](mobile-login.png) |

## 依賴、限制與回復

- 三個切片皆從 main 獨立建立；本機用變更覆蓋整合，沒有 merge 他人的分支。
- 工具切片需先整合大門切片的 shared bootstrap 隔離；館內主模組使用 v2，新 shared app URL 沿 main v27 並加 surface query。
- #107 同樣修改首頁，沒有複製其分支；與 #104／#105 的設施／社交頁保持分工，整合順序由 z1nnz 裁決。
- 無新增 Cloud、Rules、集合或資料欄位；無 production migration／seed／apply，回復為 revert 對應切片。既有保護與正式 Cloud 契約維持。
- 研究與經濟彙總、獨立房間審核佇列尚無正式來源，故為空狀態；需要新的資料產品時另行審查。
- 真人螢幕閱讀器、實機、正式 App Check、Google／Facebook provider 與 Storage 上傳留待驗收，Issue 不冒稱全部 production 完成。
- exact-head六項 CI 待上傳後核對，最終結果補在 PR；此處不把尚未執行的遠端檢查寫成通過。
