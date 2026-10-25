# 10｜Issue、PR、驗收與交接模板

## A. 開發 Issue 模板

```markdown
# [領域] 使用者結果

## 問題
目前誰在什麼情境遇到什麼問題？請附現況證據。

## 這次的使用者結果
完成後，使用者可以……

## 目前基線
- 已存在的 Module/Interface/Adapter：
- 可重用的 service/model/test：
- 目前證據層級：implemented / source-verified / device-verified / production-verified

## 本次範圍
- [ ] 正常路徑
- [ ] 權限／拒絕路徑
- [ ] 離線、重送或失敗復原
- [ ] App/Web/Cloud/Rules/firmware 的契約影響

## 實作切片
1. 測試先保護的行為：
2. 修改的 Interface：
3. 修改的 Implementation/Adapter：
4. UI 或硬體回饋：
5. migration / rollback：

## 驗收條件
- [ ] Given / When / Then：
- [ ] 無權角色被拒絕：
- [ ] 重送不重複計分：
- [ ] 指定環境證據：

## 不做
-

## 依賴與風險
- 前置 Issue：
- 外部帳號／硬體：
- 回復方式：
```

## B. 給開發者／AI 的執行說明

```text
請實作 Issue <連結或內容>，基準為最新 main。

先讀 CONTRIBUTING.md、docs/work-packages/<文件>、被引用 ADR，以及目前程式和測試。
回覆開始實作前先列出：
1. 目前基線與不該重做的能力；
2. 修改的 Module、Interface、Adapter 和資料契約；
3. 最小 PR 切片與測試；
4. 哪些結果只能 source-verified，哪些可以在本次環境正式驗收。

限制：
- 不建立第二套 Ledger、Membership、catalog 或 DeviceAssignment。
- 不讓 client/firmware 直接發 coin、XP 或正式關係成果。
- 不以 UI 隱藏代替 Cloud/Rules 權限。
- 不提交 secret、個資或真實健康內容。
- 不把編譯、Simulator、燒錄成功寫成實體或 production 成功。

完成時提供：diff 摘要、測試輸出、失敗案例、畫面/實機證據、migration/rollback、
仍未驗證項目。只提交本 Issue 所需檔案。
```

## C. PR 補充摘要模板

專案既有 `.github/pull_request_template.md` 仍是正式模板；下列內容可貼在「這個
PR 完成什麼」最前面，幫助最後合併者快速判斷：

```markdown
### 結果
- 使用者現在可以：
- 正式真相仍由：
- 證據層級：

### 契約
- 新增／變更：
- 保持相容：
- 明確拒絕：

### 驗證
- 自動測試：
- 目標環境：
- 失敗／重試：
- 尚未驗證：

### 回復
- 回復 commit / feature gate / migration rollback：
```

## D. 實體裝置驗收紀錄

```markdown
# Nudge device acceptance YYYY-MM-DD

## 版本
- App commit：
- Firmware commit/hash：
- Protocol version：
- Hardware revision／零件料號：
- Android model／OS：
- Tester：

## 接線與供電
- Pin map：
- USB supply：
- 3.3V / 5V measured：
- I2C addresses：

## 測試
| 案例 | 預期 | 結果 | 證據檔 |
| --- | --- | --- | --- |
| Display cold boot ×10 | 完整 marker 與畫面 | | |
| Context exact revision | NVS 後才 ready | | |
| Disconnect before ACK | 重播且單一 Receipt | | |
| Power cycle | queue／selection 恢復 | | |
| Assignment revoke | lifecycle fail closed | | |
| 30-min mixed load | 無過熱／brownout | | |

## 跨系統對照
- Device event ID：
- Activity correlation：
- Cloud Receipt safe reference：
- Room contribution：
- Reward/character result：

## 結論
- 狀態：pass / fail / partial
- 可宣稱：
- 不可宣稱：
- 下一個可否證測試：
```

## E. 交接模板

```markdown
## 已完成
- commit / PR：
- 通過測試：
- 證據：

## 尚未完成
- 精確缺口：
- 阻擋條件：
- 下一個最小步驟：

## 重要決策
- 使用的 canonical source：
- 權限邊界：
- 相容／migration：

## 請勿重做或誤判
-
```
