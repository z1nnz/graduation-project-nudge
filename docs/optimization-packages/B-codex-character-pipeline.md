# B 包：角色完整進化閉環

負責：Codex。對應原第 2 項。先讀 [共同規則](README.md)。

## 目的與既有工作

讓管理者發布一整條角色成長路線，而玩家只能購買初始階段，後續靠合法活動成果成長。故事、圖鑑與進化必須使用同一組穩定識別。

續接既有草稿 PR #66，先核對最新差異及 CI，不重新實作其穩定 series key、排程刷新、嚴格 parser 與 migration planner。依 `CONTEXT.md` 現行規格先支援三階進化，不擅自改成任意分支。

## B1：先完成舊資料安全性

- 比對舊名稱鍵與穩定 series key，拒絕模糊、重複、衝突對應。
- planner 輸出保留 XP、對應依據、阻擋原因與輸入指紋；不能只產生看似成功的總數。
- apply 必須有明確目標、cutover／寫入隔離策略、交易前置條件與逐筆結果。
- 保存受限存取的 before-image；rollback 不得覆蓋遷移後的新活動成果。
- 用 emulator 驗證首次執行、重跑、部分失敗、指紋變更、同時寫入與 rollback。
- production 先唯讀 dry-run；有歧義就停下來處理，不猜測角色歸屬。

本工作包不等於 production 資料寫入授權。正式 apply／部署前由 A 明列範圍、風險與回復方式，確認授權；不可為了讓 PR 綠燈刪掉舊玩家資料。

## B2：後台發布流程

依現有 `web_dashboard/assets/admin_catalog.js`、Cloud catalog service 與 ADR 0011 延伸。

- 編輯系列名稱、故事、三個階段的資產與條件；穩定 key 不隨改名改變。
- 顯示完整進化路線與發布檢查，錯誤要指出哪個階段、哪個欄位。
- 明確呈現 starter-only 商城政策與有效發布時間。
- 拒絕缺階、重複階、非法數值、缺少必要資產或前置關係不符。
- 下架停止新購買，既有擁有者與進度的處理遵守既有契約，不擅自刪除。
- 保留操作者與變更稽核，UI 與 Cloud 都驗證，不只依前端 disabled 按鈕。

## B3：商城、圖鑑、進化

檢查並延伸 `lib/screens/avatar_shop_page.dart`、`avatar_codex_page.dart`、`avatar_evolution_page.dart` 及既有 catalog／gateway。

- 商城只出現可販售初始角色；偽造請求購買進階角色也會由 Cloud 拒絕。
- 圖鑑呈現故事、擁有狀態、三階資產、目前與下一階段。
- 條件不足顯示還缺什麼，不用模糊的「不能進化」。
- 離線／pending 不顯示進化已完成；確認後角色、裝備與圖鑑一致。
- 重送、重複點擊與多端操作不得重複扣款或重複進化。
- 為 C 提供既有模型的讀取方式與狀態說明，不新增第二套 XP 計算。

## 測試案例

涵蓋 catalog 不完整／未知版本、改名後保留進度、上下架邊界、非 starter 購買、餘額不足、重複 purchase、未擁有角色進化、XP 不足、跨帳號、重送與遷移衝突。

先跑既有 `test/admin_catalog_test.js`、`test/published_avatar_series_test.dart`、`test/avatar_purchase_test.dart` 及 Cloud reward／catalog 測試，再補上述缺口、跑全套與 emulator。

## 完成條件

一組測試角色能從後台發布一路走到 App 合法進化；角色狀態跨端一致；migration 的 apply／rollback 有可重現測試與明確 production gate。交付畫面、測試紀錄與殘餘風險，不以只有 parser 測試通過宣稱整條完成。
