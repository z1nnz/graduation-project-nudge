# 20｜雙裝置組員執行、PR 順序與交接指南

## 團隊目標

讓不同組員可以平行做 Orbit、Station、App integration 與測試，但不在同一個
`main.cpp` 互相覆蓋，也不各自發明一套 protocol。每項工作要小到一個 PR 可審查、
大到能提供一個可驗收結果。

## 建議責任分工

| 角色 | 主要責任 | 不可單獨決定 |
| --- | --- | --- |
| Hardware lead | 身分卡、電源、接線、量測、外殼 | protocol/Cloud 權限 |
| Core firmware | portable lifecycle、journal、presentation | 板子 pin、App UI |
| Orbit owner | 圓屏、觸控、RTC、wearable UX | 共用 protocol 破壞性變更 |
| Station owner | 方屏、旋鈕、感測、LED、buzzer | reward/Membership 規則 |
| App/BLE owner | profile、capability、lease、outbox | 韌體偽造權限 |
| QA/evidence | 測試矩陣、fault、E2E、證據 | 以一次成功取代 gate |
| Final reviewer | 合併順序、契約與宣稱 | 跳過 required checks |

人數較少可以兼任，但每個 PR 的 author 與 reviewer 不應永遠是同一人。

## Issue 拆分與建議順序

### Wave 0｜不可平行猜測

1. `HW-01 Orbit hardware identity`
2. `HW-02 Station hardware identity and pin budget`
3. `ARCH-01 characterize protocol v1 and current firmware`

HW-01/02 可平行；ARCH-01 只加測試，不搬檔。

### Wave 1｜獨立 bring-up

4. `ORBIT-01 serial/display smoke`
5. `STATION-01 serial/display smoke`
6. `CORE-01 extract portable core without behavior change`

三項可平行，但 display PR 不修改 protocol core，core PR 不修改 pin/driver。

### Wave 2｜Adapter

7. `ORBIT-02 touch/RTC adapters`
8. `STATION-02 encoder adapter`
9. `STATION-03 ambient adapter`
10. `STATION-04 LED electrical + adapter`
11. `STATION-05 buzzer adapter`

每個 Station 周邊一個 PR；不得一次把所有 library 和 wiring 混進來。

### Wave 3｜共用協定與 App

12. `PROTO-02 device profile/capability v2`
13. `APP-01 capability-driven device cards`
14. `APP-02 context exact revision`
15. `APP-03 control lease and dual-device conflict`
16. `APP-04 durable outbox ACK integration`

合併順序：protocol tests → firmware profile → App parser → lease → real BLE。

### Wave 4｜整機與驗收

17. `ORBIT-03 local product flow`
18. `STATION-06 local product flow`
19. `E2E-01 Orbit personal`
20. `E2E-02 Station room`
21. `E2E-03 dual-device transfer`
22. `MECH-01 Orbit USB enclosure`
23. `MECH-02 Station enclosure/power soak`

### Wave 5｜選配

24. `POWER-01 Orbit battery feasibility` 只能在 Orbit USB 版通過後開始。

## 分支命名

```text
feature/<name>-orbit-display-smoke
feature/<name>-station-hardware-inventory
feature/<name>-device-core-extraction
feature/<name>-station-ambient-adapter
test/<name>-dual-device-lease-e2e
docs/<name>-device-acceptance
```

每個人開始前：

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/姓名-任務
```

只 `git add` 本任務檔案，禁止 `git add .`；不 push `main`、不 force push。

## 每個 Issue 必填

```markdown
## 使用者／硬體結果
完成後可以觀察什麼？

## 硬體前置
板型、driver、電壓、pin、照片和官方文件是否已確認？

## Module / Interface / Adapter
本次修改哪個責任？哪些核心規則不動？

## 正常與故障案例
冷開機、缺席、斷線、斷電、重送、權限撤銷怎麼測？

## Exit gate
可量測的通過條件與證據。

## 不做
避免把下一階段混進本 PR。
```

## PR 審查清單

- [ ] 從最新 main 開始，沒有混入別人的工作目錄或二進位垃圾。
- [ ] pin/driver/voltage 有實物或原廠依據，沒有複製另一塊板的設定。
- [ ] 硬體細節在 Adapter；portable core 不 include Arduino driver。
- [ ] 新 Interface 真的有 Orbit/Station 兩個 Adapter，沒有過度抽象。
- [ ] 正常、缺席、錯誤和 power-loss 都有測試或明確實機步驟。
- [ ] App/firmware 不直接 mint reward 或信任 BLE actor/role。
- [ ] 不把 build/upload 寫成 display/BLE/E2E 成功。
- [ ] log/照片沒有 token、帳號、個資。
- [ ] 已列 rollback firmware、known issues 和未驗證項目。

## 組員交付格式

每項任務提交：

1. source commit 和 PR。
2. 使用的 hardware identity/revision。
3. 完整指令，不只貼最後一行 `SUCCESS`。
4. 原始 serial log、量測表、照片／影片檔名。
5. 自動測試與實機測試結果。
6. 失敗過程、目前假設和下一個可否證步驟。
7. 需要下一位組員做的事，以及禁止誤判的事。

## 合併與 dependent PR

- PR base 預設 `main`；只有明確依賴尚未合併的 Interface 時才短暫 base 到前一分支。
- 前一 PR 合併後，把 dependent PR base 改回 `main`，重新看完整 diff 和 CI。
- Final reviewer 依 Wave/契約順序合併，不以建立時間先後決定。
- 發現 protocol/schema/pin 衝突時停止合併，更新 ADR/identity/pin budget 後再繼續。

## 每日同步只回答四件事

```text
昨天哪一個 Exit gate 通過？
今天要取得哪一份可觀察證據？
目前阻擋是程式、硬體、權限還是未知規格？
有沒有改到共享 Interface 或影響另一台裝置？
```

避免只回報「正在寫」「差不多」「有亮」；這些不能讓下一位組員接手。

## 最後交接

- Orbit/Station 各有一張操作卡與一張恢復卡。
- repo 內保存 source、lock、BOM、pin、identity、acceptance；大型影片放可追溯位置。
- 展示電腦、Android 手機、USB 線、電源和備用 firmware 在演示前離線演練。
- 組員可離開專案而不影響重刷、重建和故障診斷，才算真正交接完成。
