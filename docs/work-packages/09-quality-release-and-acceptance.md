# 09｜品質、發布與驗收工作包

## 目的

用同一套 gate 回答三件事：程式是否正確、目標環境是否可用、我們可以對外宣稱
到什麼程度。測試全綠不等於實體或 production 已驗收，但沒有自動測試也不能靠
一次展示取代。

## PR 自動 gate

所有功能經分支與 PR 進 `main`。GitHub 必須通過：

1. `Flutter analyze and tests`
2. `Android Kotlin compile`
3. `iOS dependency lock`
4. `Web and shared contract tests`
5. `Cloud Functions tests`
6. `Firestore rules and transaction tests`

韌體變更應新增／維持 host C++ test 與 PlatformIO build gate；在 CI 尚未正式加入
前，PR 必須貼上同 commit 的本機輸出。

## 測試矩陣

| 層級 | 必要驗證 | 不能替代 |
| --- | --- | --- |
| Flutter | analyze、unit/widget、contract | 真實 BLE、production Cloud |
| Android | Kotlin compile、emulator fresh install | 實體 peripheral BLE |
| iOS | CocoaPods lock、clean Simulator smoke | 實體 iPhone、App Attest、APNs receipt |
| Web | Node contract、XSS、能力導覽、瀏覽器 smoke | Cloud Rules／callable authority |
| Cloud | unit、Emulator Rules/transaction、migration | production real-account E2E |
| Firmware | host state machine、PlatformIO build | display、power、sensor、BLE 實物 |
| Hardware E2E | Android + device + Cloud + Web evidence | 商用 claim/signature/OTA |

## 功能完成條件

每個切片必須同時具備：

- 需求與不做範圍清楚。
- 正常、拒絕、離線／重試案例。
- App/Web/Cloud/Rules 契約一致。
- 無 secret、無真實個資、無權限旁路。
- 自動測試與指定環境證據。
- rollback／feature disable 路徑。
- 文件與狀態標籤更新。

## 實體裝置驗收流程

1. 記錄硬體料號、接線版本、firmware hash、App commit、Android 型號與 OS。
2. 先做工作包 02 的螢幕／I2C／LED／供電獨立測試。
3. 再做工作包 03 的 context、活動、斷線、重播、撤銷指派。
4. 對照 event ID、correlation、Receipt、room contribution、reward、角色成果。
5. 斷電重開，確認 NVS 選擇和未 ACK queue 恢復。
6. 至少 30 分鐘混合負載，記錄溫度、brownout、重連和資料重複。
7. 保存原始 log、照片／影片、去識別化 Cloud 結果與 tester 簽名。

只有以上完成，該硬體／App／firmware 組合才是 `device-verified`。更新任一協定、
腳位、driver 或關鍵電源設計都要重跑受影響項目。

## Production 驗收

- 使用短效權限與短效 App Check token 執行 `production_real_account_e2e.mjs`。
- 結果每個步驟為 passed，cleanup 為 completed；不保留測試密碼或 token。
- schema migration 必須 dry-run → apply → second dry-run，並保存 run-bound evidence。
- fresh install：Android device/emulator 與 iOS Simulator；專題 gate 不要求實體 iPhone。
- catalog store release 另驗證一次真實付費購買及 evolved-character equip。
- App Check enforcement、Functions、Rules、indexes、Storage 分別記錄部署結果。

## 發布與回復

- 每次發布建立版本清單：App、Web asset、Functions、Rules、indexes、firmware。
- 先部署向後相容 server，再發布 client；最後才收緊 enforcement。
- firmware protocol 不相容時保留舊版 server/adapter 支援期或明確阻擋升級。
- Cloud feature 使用 server-side kill switch／fence；UI feature flag 不能取代權限。
- rollback 後重跑最小 E2E，確認沒有半套 projection 或重複 settlement。

## 審查者怎麼判斷 PR

1. PR 是否只解一個問題，diff 有沒有混入格式化／無關檔案。
2. 新規則是不是放在擁有該責任的 Module，而非多個 UI 複製。
3. 是否同時有正向與拒絕測試；權限不只藏按鈕。
4. 是否破壞 canonical Ledger、Membership、catalog 或 DeviceAssignment。
5. migration／rollback 是否可重跑，是否有 race 和 partial failure 測試。
6. 證據是否屬於同一 commit／firmware hash，而非舊截圖。
7. 「未驗證」是否老實列出；宣稱層級是否與證據一致。

## 專題展示最低版本

- 一個新使用者可完成核心 App 循環。
- 一個家庭情境與一個團體情境能顯示正確角色差異與共同成果。
- 一個自律房由成員各自活動，不由管理者控制。
- 一個完整角色系列從 Web 上架到 App 商城／圖鑑／進化路線一致。
- 一台實體裝置完成 Android → Ledger → Web/成果閉環。
- 失敗展示：斷線重送不重複計分、錯誤角色或撤銷指派被拒絕。
