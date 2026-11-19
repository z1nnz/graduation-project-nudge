# 競賽 Demo PR（待填）

## 工作包
- Issue：真實連結；沒有則明寫未建立，不填虛構編號
- 裝置：Orbit / Station / Shared
- 優先級：P0-A / P0-B / P1 / P2

## 目標
待填：解決什麼問題、使用者會看見什麼結果。

## 實作
待填：本輪檔案、來源 commit／tree、依賴 PR；不要把未合併依賴冒充 main。

## 沒有做
實機稍後驗收時，明列未 upload／影片／線材／互動／App／Cloud，不把程式準備當實物通過。

## 硬體
- XIAO：實際型號／獨立板號，未知則寫未知
- 螢幕：實際型號／driver／解析度
- 可選周邊：未採或真正已驗者
- 插接／接線照片：未拍或真檔／hash／日期

## 驗證
- [ ] PlatformIO compile（本輪或固定來源的命令與 log，兩者分開）
- [ ] Physical upload（真板與 USB 線、port；SUCCESS 不等畫面通過）
- [ ] Cold boot 3/3
- [ ] Complete demo flow（至少 Home、Focus、Complete）
- [ ] Restart（P0-B／P1 宣稱才需要）
- [ ] Offline fallback
- [ ] Optional peripherals removed（未採可說明不適用，不假勾通過）

## 命令
只記實際執行者，未執行的操作另列為範例。

```sh
# 實際執行的命令
```

## 證據
- Build log：
- 近拍影片：未拍或實物檔／hash／時間碼
- 完整影片：未拍或實物檔／hash／時間碼
- Binary：對應裝置／environment／SHA-256，候選／已驗狀態
- Commit：firmware 與 packaging source 分開

## Demo truth
- 固定展示資料：小樹／小芽／任務／房間／82 分等是虛構 DEMO
- 真實互動：未驗或確實已驗的動作，不以 callback／host test 代替實物
- 尚未完成的 App／Cloud：未完成真實資料閉環；不發正式 XP／幣

## 已知限制
接線、獨立主控、影片、另一台電腦／手機、排練與人員確認逐項明列。
六個最新 head CI 全綠後才 Ready／請 z1nnz 審查；作者不自行合併，缺實物證據不簽硬體通過。
