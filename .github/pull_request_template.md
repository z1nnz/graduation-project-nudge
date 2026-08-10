## 這個 PR 完成什麼

- （請填寫）

## 對應任務／Issue

- Issue：
- 負責人：

## 影響範圍

- [ ] Flutter App
- [ ] Web Dashboard
- [ ] Cloud Functions
- [ ] Firestore／Storage Rules
- [ ] 資料遷移或舊投影清理
- [ ] 家庭／團體角色權限
- [ ] Activity／Reward Ledger
- [ ] 角色、圖鑑、進化或商城
- [ ] 隱私、通知或後台稽核

## 資料契約與權限

- 新增或修改的 collection／document／欄位：
- 哪些角色可以讀取、建立、修改或刪除：
- App、Web、Cloud 是否使用同一份 canonical 資料：
- 是否需要 migration、dry-run 或 rollback：

## 驗證結果

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `node --test test/*.js`
- [ ] `npm --prefix functions test`
- [ ] 相關 Firebase emulator 測試
- [ ] 真實帳號角色切換
- [ ] iOS／Android 實際操作

請貼上測試輸出摘要：

```text

```

## 畫面與操作證據

請附修改前後截圖、錄影或操作步驟。後端 PR 請附 callable、Rules 或 emulator 證據。

## 風險與回復方式

- 已知風險：
- 回復方式：
- 尚未驗證項目：

## 提交前確認

- [ ] 只包含本任務範圍，沒有混入其他人的修改
- [ ] 沒有 `.env`、Token、金鑰、service account 或個資
- [ ] 沒有讓客戶端直接發放金幣、XP 或改寫 canonical Ledger
- [ ] 沒有只隱藏按鈕卻漏掉 Cloud／Rules 權限檢查
- [ ] 已從最新 `main` 更新並處理衝突
- [ ] 已指定 `@z1nnz` 為 Reviewer，且不會自行合併
