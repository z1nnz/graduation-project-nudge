# WEB-GAME-03：逐頁盤點與資料契約

來源：Issue #84，main 27f1e4d1c8e8bbeecd32e8466efd960d3917104b；日期 2026-11-23（Asia/Taipei）。
#84 分五個獨立 Draft PR，所有 base=main；不合併、不部署、不推 main、不 force push。

## 盤點（修改前）

| 頁面 | 固定／Demo／空操作 | 正式來源或處理 | 空狀態／限制 |
| --- | --- | --- | --- |
| personal-trends.html | 82 分、較上月 +11、18 天、+310 幣；圖表為樣本 | 無正式長期總結；新頁改讀本人 completed activity_sessions | 無資料、拒絕、讀取中明確呈現 |
| personal-weather.html | 固定七天天氣／高度、假預報；加入規劃只 toast | 沒有核定預測模型；僅回顧本人已確認活動 | 不預測或發出壓力警戒 |
| personal-pressure.html | 截止日 78%、睡眠54%、中斷42%；假診斷語氣／toast | 沒有壓力診斷資料來源；改生活整理與使用者自選草稿 | 不以活動量推論心理健康 |
| personal-skill-tree.html | 固定技能等級與假解鎖／toast | 正式技能 Lv／獎勵解鎖規則尚未提供 | 只呈現可測試的回顧書籤，與正式解鎖分開 |
| personal-template.html | 產生固定規劃、Demo 存取與下載 | 新增本人私有 growth_documents；明確確認才新增 tasks 草稿 | 保存／編輯／下載／衝突回復 |
| personal-letter.html | 固定信件文字；既有 tools 的 localStorage／user projection | 本人私有 growth_documents；只保存使用者輸入文字 | 未保存、空白、拒絕及離線失敗 |
| personal-time-capsule.html | 過期固定日期、預填正文；localStorage／users.timeCapsules 可立即讀 | 新 Cloud-only 私有正文區（由 Rules 隔離，不宣稱端到端加密），到期 callable 才回傳 | 未到期／到期／取消／刪除／重試／匯出 |
| planet.html | 前端週結算、固定70%／planetCount與示範ID fallback混用 | #82 擁有星球核心與正式解鎖整合；本包只盤點，不重寫或聲稱已修 | 紀錄館不引用其數值、不將其解鎖當正式成果 |
| personal.html | 連到分散功能，統計／展示界線不清 | 紀錄館入口，無固定個人數字；研究／發表／後台獨立 | 每頁固定返回路徑、不繞過既有登入／角色門禁 |

## 共用世界路線契約

#82 擁有世界核心，本包的穩定入口為 personal.html，八個館內路線列於 assets/growth_museum_core.js。
#82 可將紀錄館建築連到此入口；不建立第二個小鎮、不修改 #83 社交場景。
返回路徑只允許固定同來源 town.html；該檔未整合時固定退到 dashboard.html 並明說小鎮待整合，忽略使用者可控制的 redirect／uid 參數。
研究、發表、後台是獨立既有頁面；連結不授予角色權限。planet.html 由 #82 處理，本館不把其舊結算或示範解鎖當成自己的正式成果。

## 資料與事實／建議界線

- 正式事實：本人 actorUserId 的 Cloud-only activity_sessions，status=completed；本人 discipline_identity_snapshots 可另作 Cloud 摘要，絕不從本機補算正式分數或 XP。
- 回顧：採 Asia/Taipei 05:00 邏輯日、週一週起點、曆月；來源 ID、時間、類別、單位與比較視窗可展開查閱。比較前須讀完整選定視窗；缺頁／拒讀／快取不會顯示成完整總計。
- 同一 session 只計一次，roomIds 不會倍增個人成果；家庭／團體 outcomes 不納入個人 XP、自律幣或私人分析。
- 書籤條件是可解釋的閱讀回饋，不是核定的技能 Lv、物品或獎勵解鎖；未核定規則顯示尚未提供。
- 使用者策略／信件：users/{auth.uid}/growth_documents，schemaVersion=1、ownerUid、kind、title、body、revision、createdAt、updatedAt。只表示本人文字，不是正式成果。所有保存／刪除及新增任務都經 enforceAppCheck callable 與 account operation lease；Rules 只准本人讀文件、禁止 client 寫入。伺服器時間與遞增版本防止默默覆蓋另一裝置。growth_document_operations 只存無正文的刪除 tombstone，client 完全拒讀寫，延遲重試不能恢復刪除文件。
- 建立任務：只在使用者編輯並明確確認後，進現有 users/{auth.uid}.tasks 的手動／fixed／未完成任務流程。使用安全亂數 ID；不開始活動、不改 Ledger、不發獎勵。
- 新膠囊：users/{auth.uid}/growth_capsules 只含 metadata；growth_capsule_secrets 正文完全禁止 client 讀寫；growth_capsule_operations 只存 server retry tombstone。所有建立／開封／取消／刪除經 App Check callable，server clock 判定。
- 正式隱私匯出：包含新文件／膠囊 metadata；未到期不匯出正文，到期才可包含。帳號刪除的 user recursive purge 擦除全部三個膠囊集合及文件；到期站內通知不包含正文。
- 舊 users.timeCapsules／localStorage 不是安全膠囊；不自動搬移、不宣稱具備新保護。新紀錄館不再讀寫那些舊資料；若需要搬移，必須由本人重新確認與封存。
- 保存政策：本人文字與膠囊保留到本人刪除或帳號正式刪除；取消會擦除正文、保留可見取消狀態；刪除正文與 metadata 後只留不含正文的重試 tombstone，直到帳號刪除。隱私匯出檔沿正式七日到期政策。

## 整合依賴與界線

#73、#79 都尚未合併；本分支不把整個分支複製進來，不動 App 角色管線。沿用 main 現有 Firebase／App Check bootstrap，紀錄館僅加最小隔離接線，所有新功能都在專屬 JS／CSS。
五個切片各自從目前 main 建分支；2–5 的館內模組要在切片1入口合併後才會從正式頁載入。每份 PR 需獨立 CI，另作五片的本機整合測試；整合順序由 z1nnz 裁決。
新增 collection／index 僅加法，不搬既有資料。dry-run 為 emulator inventory／Rules／rollback 測試，不執行 production migration、seed、apply、deploy。
回復：停用新入口／callable，還原 PR 程式；不要刪掉已存在的本人文字。保留 deny-all secrets Rules，直到所有封存資料按保留政策處理完，避免 rollback 意外提早開封。
