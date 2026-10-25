# 00｜寫作者與開發者使用指南

## 目的

把本目錄中的產品方向轉成可審查的程式變更，而不是只產生看似完整的說明文。
「寫作者」包含組員、外包開發者與 AI agent；無論由誰執行，都必須對現有程式、
測試和實際證據負責。

## 開始前

1. 從最新 `main` 建立新分支，一個分支只做一個可驗收切片。
2. 閱讀 `CONTRIBUTING.md`、相關 ADR、現有模型與測試，不能只看本工作包。
3. 先寫一句問題定義與一句使用者結果，若無法說清楚就先不要改程式。
4. 列出這次會碰到的 Module、Interface、Adapter 與資料集合。
5. 先確認工作是「補缺口」還是「替換既有真相」，避免建立第二套 Ledger、
   Membership、角色目錄或裝置狀態。

## 實作原則

### 保持單一真相

- 活動證據走 Activity Ledger；不可在畫面儲存完成後直接加幣或加 XP。
- 關係角色走 `relationship_memberships`；父文件陣列只可作查詢橋接。
- 角色系列與上架狀態走正式 catalog；不要在 App、Web 各藏一份角色規則。
- 裝置授權走 Cloud `DeviceAssignment`；BLE payload 不能宣告自己是誰。

### 讓模組夠深

高層畫面應呼叫小而穩定的 Interface，不應知道重試、去重、交易、BLE 封包或
Firestore 欄位的全部細節。若一個改動讓多個畫面重複相同判斷，先把判斷放回
擁有該規則的 Module，再由 Adapter 對接 Flutter、Web、Cloud 或韌體。

### 安全地改資料契約

任何 collection、欄位、索引、角色或事件格式變更都要同時交付：

- 版本或相容策略；
- 讀寫權限與拒絕案例；
- migration dry-run；
- apply gate；
- rollback 或不可回復時的保護措施；
- App、Web、Cloud、Rules 的共同契約測試。

### 先做失敗路徑

每個功能至少回答：離線怎麼辦、重送怎麼辦、權限被撤銷怎麼辦、資料過期怎麼
辦、另一端版本較舊怎麼辦。UI 不可把暫時性錯誤偽裝成成功。

## 每個切片必須交付

1. 一個 Issue 或等價任務說明，使用 `10-delivery-templates.md`。
2. 最小範圍程式碼與相對應測試。
3. 契約／ADR 更新；只有行為或決策真的改變才新增 ADR。
4. 操作證據：畫面變更附截圖；硬體附序列輸出與照片／影片；Cloud 附去識別化
   的結果摘要。
5. 已知未驗證項目與回復方式。
6. PR 只改本任務所需檔案，指定 `@z1nnz` 審查，不自行合併。

## 通用測試命令

依影響範圍選擇，不需要為純文件 PR 跑所有耗時測試，但必須檢查連結與內容：

```bash
flutter analyze
flutter test
node --test test/*.js
npm --prefix functions test
make -C firmware/nudge_focus_device test
pio run --project-dir firmware/nudge_focus_device
```

Firestore Rules／交易改動還要使用 `firebase emulators:exec` 執行對應測試；Android
native BLE 改動至少編譯 Kotlin，iOS 相依改動使用鎖定的 CocoaPods 版本。

## 禁止事項

- 不直接 push `main`，不使用 force push。
- 不以隱藏按鈕代替 Cloud 與 Rules 權限。
- 不用成功編譯宣稱真實裝置成功。
- 不重新實作已存在的服務，除非 Issue 明確說明替換及遷移策略。
- 不在同一 PR 同時做 UI 重設計、資料 migration、韌體協定與無關清理。
- 不因展示方便而讓管理者控制成員、讓家長查看未同意的健康細節。

## 給 AI coding agent 的任務開頭

```text
請執行 docs/work-packages/<工作包>.md 中的「<切片名稱>」。
開始前閱讀 CONTRIBUTING.md、被點名的 ADR、目前實作與測試。
只處理這個切片；先說明既有基線與預計修改的 Module/Interface/Adapter。
使用測試保護契約，保留 Cloud Ledger、Membership、角色 catalog 與裝置授權的
單一真相。不要宣稱未實機或未正式環境驗證的結果。完成後提供測試輸出摘要、
畫面/裝置證據、風險、回復方式與仍未驗證項目。
```
