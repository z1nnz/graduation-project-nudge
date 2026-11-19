# 13｜交付與證據模板

## PR 模板

```md
## 工作包
- Issue:
- 裝置：Orbit / Station / Shared
- 優先級：P0-A / P0-B / P1 / P2

## 目標

## 實作

## 沒有做

## 硬體
- XIAO:
- 螢幕:
- 可選周邊:
- 插接／接線照片:

## 驗證
- [ ] PlatformIO compile
- [ ] Physical upload
- [ ] Cold boot 3/3
- [ ] Complete demo flow
- [ ] Restart（P0-B／P1 才需要）
- [ ] Offline fallback
- [ ] Optional peripherals removed

## 命令

```sh
# 實際執行的命令
```

## 證據
- Build log:
- 近拍影片:
- 完整影片:
- Binary:
- Commit:

## Demo truth
- 固定展示資料：
- 真實互動：
- 尚未完成的 App／Cloud：

## 已知限制
```

## 實機證據最低要求

影片必須同時拍到：

- 實體 XIAO／螢幕，而非只錄螢幕輸出模擬器。
- 開機；若宣稱 P0-B／P1 互動，再拍 Restart。
- P0-A 至少拍 Home、Focus、Complete 三個 Scene。
- 完成畫面。
- 操作者的按鍵／旋鈕動作（如果宣稱有實體互動）。

避免只拍終端機 `SUCCESS`，因為它只能證明燒錄完成，不能證明畫面正常。

## 單機交接卡

```md
# Device handoff

裝置：
負責人：
硬體型號：
PlatformIO environment：
Source commit：
Binary 路徑：
燒錄命令：
正常開機畫面：
Next 操作：
Restart 操作：
Auto Demo：
P1 周邊：
離線狀態：
已知限制：
最後實機驗收日期：
驗收影片：
```

## Demo 資料表

```md
使用者：小樹（虛構 Demo）
主要任務：完成專題韌體
其他任務：閱讀 25 分鐘、散步 3000 步
自律房：期末一起前進（Demo）
房間進度：3/5（Demo）
家庭訊息：今天也慢慢來，我們都在（Demo）
角色：小芽
角色等級：7（Demo）
Demo XP：+10
今日專注：50 分鐘（Demo）
今日分數：82（Demo）
```

兩台必須引用同一份資料，避免 Orbit 是 82 分、Station 卻顯示其他數字。

## 發布包結構

```text
Nudge-Competition-Demo/
  README.md
  work-packages/
  firmware-source/
  binaries/
    orbit_demo/
    station_demo/
  evidence/
    orbit/
    station/
    full-demo/
  scripts/
    competition-script.md
    runbook.md
  VERSION.txt
```

## VERSION.txt

```text
Package:
Created at:
Source repository:
Source commit:
Orbit environment:
Station environment:
Orbit device verified:
Station device verified:
BLE included:
Known limitations:
```

## 壓縮檔驗收

- [ ] 能解壓縮。
- [ ] README 第一頁明確寫這是競賽 Demo。
- [ ] 不包含 Token、service account、`.env` 或真實帳號資料。
- [ ] 不包含無關的大型 cache／build 資料夾。
- [ ] 兩個 binary 名稱不會混淆。
- [ ] 影片可離線播放。
- [ ] 舊 32 包沒有混入。
- [ ] GitHub PR 與 commit 可追溯。

## 寄給組員時的訊息

```text
這份是新的 Nudge 競賽 Demo 工作包，完全取代 2026-11-04 的 32 份舊版。
最低目標只有：讓 Orbit 與 Station 兩台實體機各自穩定顯示三幕自動 Demo。
不需要購買萬用電表、烙鐵、洞洞板或新零件；App/BLE 是 P2 選配。
請先讀 README、00、09、11，再認領對應裝置的 Issue。
```
