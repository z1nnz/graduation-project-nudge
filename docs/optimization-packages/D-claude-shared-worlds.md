# D 包：自主自律房、家庭樹與團體星球

負責：Claude 第二個工作階段。對應原第 5 項。分支建議 `feature/claude-shared-worlds`。

先讀 [共同規則與檔案所有權](README.md)。此包是實作任務，不只整理建議。不要自行合併。

## 目的與現況

共同世界提供一起前進的理由，但不變成家長監控或管理者控制。現有 Membership、Consent、Room Session、relationship outcome、room resonance 已有核心實作；先確認並改善，不重建一套資料庫。

讀取 `CONTEXT.md` 與 ADR 0002／0004／0006／0007／0008／0015／0016／0018。以既有模型與 gateway 為基礎，Cloud outcome 才是共同成果來源。

## D1：身分清楚的工作區（第一個可獨立 PR）

- 每個家庭／團體頁面清楚顯示目前關係、身分與可做的操作。
- 支援既有多關係切換；切換時先清空前一關係的摘要，再顯示新結果。
- 家長：可見孩子已同意的摘要、提出共同目標、送鼓勵。
- 孩子：管理同意、接受／拒絕目標、回應鼓勵；不能使用家長管理操作。
- 團體管理者：成員與邀請、挑戰發布、合法彙總。
- 成員：參與挑戰、自己的貢獻與共享選擇；不能修改管理內容。
- 無綁定、邀請待接受、關係停用、被移除、讀取失敗均有明確 UI。
- UI 不只隱藏按鈕；以現有後端拒絕測試確認越權不可執行。若契約缺口須由 A 協調修正。

入口包括 `guardian_center_page.dart`、`guardian_parent_page.dart`、`group_management_page.dart`、`group_manager_page.dart`，以及 Web `guardian*.html`／`groups*.html`。先讀各頁現況，不為了統一樣式移除既有能力。

## D2：自律房整理

入口包括 `study_room_list_page.dart`、`study_room_detail_page.dart`、`study_room_live_page.dart`、Web `rooms.html`。

- 房間列表以活動類型、共同目標、我的參與狀態為主，降低管理欄位干擾。
- 房內整理成「我的行動」「共同進度」「夥伴支持」，成員不用先找房主管理面板。
- 計時類呈現自己的 session；步數等累積類依現行來源契約顯示，不全部套倒數計時。
- 成員自行開始、暫停與結束；房主只管理設定、准入與秩序。
- 使用 canonical Activity Session 與既有 ledger gateway，App／Web 不各自創建同一活動。
- 使用既有 opt-in resonance／固定支持回應；不新增無限制訊息刷獎勵。
- 不預設公開精確健康數值，不增加總量競爭排行榜。
- 本輪若共同場景沒有 canonical outcome 資料，只整理既有進度；新里程碑規則須另提 A 評估，不前端自行累加。

## D3：共同世界與回憶

- 家庭樹呈現 Cloud 已確認的關係成長、近期共同回憶與下一個已定義里程碑。
- 團體星球呈現 Cloud 彙總與我的合法可見貢獻；不可拿個人原始健康資料作全團展示。
- 未生成、同意不足、無成果、cache／error 不冒充零分或已完成。
- 以既有 outcome 資料呈現，不新增本機計分規則。若缺下一里程碑欄位，可先省略或提出 API 需求，不硬編門檻。
- 提供獨立摘要 widget 給 C，參數包含名稱、角色、合法可見 outcome、載入狀態與導覽 callback；widget 不自行抓取所有家庭資料。
- 回憶先做既有事件可支持的呈現。新增永久回憶資料表／公開分享需要先定義權限與生命週期，交 A 協調。
- 每個成果都能說明「怎麼來的」，並明示關係成長不會增加個人角色 XP。

## 檔案邊界

可修改：家庭／團體／房間專用頁面、專用 widget、專用 scoped CSS／JS 與測試。每個切片盡量獨立 PR。

不得直接修改 C 的 `home_page.dart`、`daily_companion_card.dart`、`dashboard.html`；共享 AppState、`app.js`、Cloud、Rules、索引和核心契約的改動先交 A。不要把整份 `app.js` 複製出來改成新資料來源。

## 測試與完成條件

建立角色／關係矩陣：家長、孩子、管理者、成員、未加入者、已被移除者；逐項確認可見資料與可執行操作。

至少覆蓋：

1. 家長不能替孩子開啟同意、接受目標或寫私人資料。
2. 撤回同意／解除綁定／移除成員後舊畫面與操作失效。
3. 管理者不能開始／結束其他人的活動；成員不能發布管理內容。
4. 多家庭、多團體與帳號切換不殘留前一關係資料。
5. Cloud outcome 只呈現一次，不因重開頁面增加 Bond 或個人 XP。
6. App／Web 接續同一合法活動，無重複 session；錯誤時可安全重試。
7. 手機與桌面、長名稱、無資料、載入／失敗皆能使用。

沿用 `relationship_role_surfaces_test.dart`、`relationship_membership_test.dart`、`relationship_outcome_test.dart`、`app_state_study_room_test.dart` 與既有 Web／Rules 測試補缺口。跨帳號權限需 emulator 證據，不只 snapshot。

交付各身分畫面、測試帳號角色設計（不含憑證）、測試結果、PR 與尚缺的真實帳號驗收。完成是使用者知道「我是誰、可以做什麼、為何值得參與」，同時底層權限一致；不是只換頁面標題。
