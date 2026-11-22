# Nudge 四包並行開發與交接入口

日期：2026-11-22。範圍對應使用者選定的原計畫 1、2、3、5；不是另外增加四套系統。

換電腦接手請先讀 [新電腦交接與 PR 審查流程](../handoff/new-computer-2026-11-22.md)。私人 Git／未提交檔案備份另存使用者 Google Drive，不放進 repository。

這是新一輪開發規格，不是已完成功能清單。先讀本頁，再讀自己負責的一包；無法確認的現況以原始碼、最新 PR、測試證據為準。

## 分工

| 包 | 執行者 | 範圍 | 文件 |
|---|---|---|---|
| A | Codex | 原第 1 項：既有 PR 審查、依賴與最終整合 | [A](A-codex-review-integration.md) |
| B | Codex | 原第 2 項：完整進化鏈、商城初始角色、App 圖鑑與安全遷移 | [B](B-codex-character-pipeline.md) |
| C | Claude | 原第 3 項：角色生活空間、狀態回應與成果回憶呈現 | [C](C-claude-companion-home.md) |
| D | Claude | 原第 5 項：自律房、家庭、團體的互動、角色身分與共同世界 | [D](D-claude-shared-worlds.md) |

兩包交給 Claude 是使用者自行交付給兩個 Claude 工作階段；本文件不表示已送出、已啟動或已完成。建議兩包分別開獨立工作階段，不共用分支。

## 本輪共同目標

形成「自己的小目標 → 自主行動 → Cloud 確認 → 角色回應 → 自願共享的共同成果」閉環。先把一條流程做完整，再增加玩法數量。

本輪不新增：七日旅程、抽卡、付費交易、PWA 離線快取、感測器功能、韌體畫面。這些不是被取消，而是不塞進這四包。既有韌體 PR 可以由 A 審查；無 ESP 時只驗軟體，不宣稱硬體通過。

## 開始前必讀

- 根目錄 `CONTRIBUTING.md`、`CONTEXT.md`、適用的 `AGENTS.md`／`CLAUDE.md`（若存在）。
- `docs/adr/0001-shared-catalog-and-relationships.md`。
- 自己功能對應的 ADR：B 看 0011；C 看 0017；D 看 0002、0004、0006、0007、0008、0015、0016、0018。
- 所有相對路徑都以 Git 儲存庫根目錄為基準。

2026-11-22 建立此規格時 main 為 `27f1e4d`；開始開發時仍須 fetch 最新 main。已合併 #67、#68 不重寫；#66 是角色管線草稿，#69 是 PWA 草稿，不把未合併 API 當成 main 已有功能。

## 檔案所有權與交界

| 區域 | 唯一主要擁有者 | 其他包的做法 |
|---|---|---|
| `lib/screens/home_page.dart`、`lib/widgets/daily_companion_card.dart`、`web_dashboard/dashboard.html` | C | D 的摘要元件由 C 放進首頁，不自行編輯這三檔 |
| 角色商城、圖鑑、進化、catalog 後台及角色 migration | B | C 使用現有公開資料，不複製 parser 或 XP 公式 |
| 家庭／團體／自律房頁面及其專用元件 | D | C 透過元件參數／導覽 callback 連接 |
| `lib/state/app_state.dart`、`web_dashboard/assets/app.js`、Cloud、Rules、索引、共用契約 | A 協調整合；B 可在角色範圍提出修改 | C、D 若需要改動，先在 PR 寫出介面需求及必要性；不要直接修改或複製另一套 state |
| `web_dashboard/assets/styles.css` | A 協調 | C、D 新增各自 scoped CSS，不做全站重設 |

共享檔案調整若必要，由 A 開獨立前置 PR，或明確重新指派後一次只讓一包修改。不得繞過這條規則來建立第二套 Firebase listener、Membership、Ledger 或獎勵來源。

## 可以並行與必須等待的工作

1. A 先做 PR 依賴盤點；B 在既有 #66 分支續做，避免重開重複管線。
2. C、D 從最新 main 的獨立分支開始，可先以固定 fixture 開發純呈現元件，但不得把假資料接到正式帳號。
3. B 與 D 若需改契約，先交 A 確認；C 的角色資料介接等 B 契約穩定。
4. D 交付獨立共同世界摘要元件；C 在自己的首頁 PR 接入。D 不依賴 C 的整頁改版才可完成。
5. 合併前各分支同步最新 main，再跑整合測試；不能只相信舊 commit 的綠燈。

## 不可違反的規則

- 正式活動與個人 XP／金幣由 Cloud Ledger 與既有獎勵服務決定。
- Family Bond／共同世界成長不是個人角色 XP，不得混算。
- 家長不能替孩子同意資料共享；管理者不能替成員開始或結束活動。
- 不依角色自填字串給權限；依 canonical Membership、Group／Family Link 與既有 capability resolver。
- 不推送 main、不 force push、不修改 production 資料或大批清除舊資料。資料遷移另附 dry-run、apply gate 與 rollback。
- 不提交金鑰、token、真實帳號資料或未去識別的日誌。

## 測試與交付

每包至少交：變更說明、測試指令與結果、適用狀態截圖、限制、未完成項目、PR 連結。UI 須看 360px 手機寬與桌面、長字串、深色模式（適用時），不只看測試數字。

```sh
flutter pub get
flutter analyze
flutter test
node --test test/*.js
npm ci --prefix functions
npm --prefix functions test
```

需要 emulator 的 Rules／交易驗證依既有 CI 工作流程執行；測試因環境缺少而 skipped 不算通過。PR 的六項 gate 以 `CONTRIBUTING.md` 名稱為準。

狀態分開記：規格完成／程式完成／CI 通過／已合併／已部署／真實帳號驗收／硬體驗收。不用「全完成」混稱。

## 給 Claude 的開場指令

### Claude 第一包

> 請閱讀 `docs/optimization-packages/README.md` 與 `C-claude-companion-home.md`，只承接 C 包。先讀實際程式與相依 ADR，從最新 main 建立 `feature/claude-companion-home`。遵守檔案所有權，不改共享 state／Cloud／Rules，不重寫已合併 #67／#68。先做 C1 可驗收切片，附測試、畫面與限制，開 PR 交 Codex 審查，不自行合併。發現必要介面缺口時列出需求，不自行創建第二套資料真相。

### Claude 第二包

> 請閱讀 `docs/optimization-packages/README.md` 與 `D-claude-shared-worlds.md`，只承接 D 包。從最新 main 建立 `feature/claude-shared-worlds`，先核對已存在的關係功能，不從零重做。依 canonical 角色與同意範圍開發，成員自主活動不受管理者控制。不修改 C 的首頁或共享 state／Cloud／Rules。先交 D1 角色工作區切片，再交互動與共同世界，附測試、畫面、限制並開 PR，不自行合併。
