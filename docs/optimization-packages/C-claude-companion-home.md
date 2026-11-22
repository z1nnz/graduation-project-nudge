# C 包：角色生活空間與陪伴回饋

負責：Claude 第一個工作階段。對應原第 3 項。分支建議 `feature/claude-companion-home`。

先讀 [共同規則與檔案所有權](README.md)。此包是實作任務，不只交設計稿。不要自行合併。

## 目的

打開 App／個人 Web 首頁時，先看到「我的夥伴、現在能做的一件小事、已確認的成果」，不是一整排功能與數字。角色回應是真實狀態的呈現，不是另一套獎勵系統。

## 先確認現況

main 已有 `DailyNextAction`、`DailyCompanionCard`、`ConfirmedActivityFeedback`、`activityFeedbackStatus`，Web 有 `daily_next_action.js`、`confirmed_activity_feedback.js`。先沿用這些能力；不要重建活動 listener。

主入口：`lib/screens/home_page.dart`、`lib/widgets/daily_companion_card.dart`、`web_dashboard/dashboard.html`。先讀實際公開 API；未合併的 #66／#69 不能直接當成已存在。

## C1：角色生活空間（第一個可獨立 PR）

- 將陪伴卡提升為個人首頁的清楚視覺重心，保留必要導覽與現有家庭／團體入口。
- 顯示真實裝備角色；無法取得資產時有穩定 fallback，不閃退。
- 只保留一個主要行動；沿用 DailyNextAction 導向任務，不替使用者自動完成或開始。
- 區分「準備下一步」「今日無待辦／可休息」「登入／同步中」「有 Cloud 確認成果」的文案與視覺。
- 沒有可靠活動中資料時，不假造正在專注、睡眠或健康狀態。
- Guest、cache、pending、error 都有明確呈現；不能把舊成果標成今天剛完成。
- 家庭／團體尚未綁定時保留原本 gate，不能靠首頁改版繞過身分檢查。

角色回應可先用輕量表情框、對話與場景色彩；不假設現有靜態資產已具備完整動畫。尊重減少動態設定，不能靠持續晃動吸引用戶。

## C2：成果回憶與回應

- 使用已確認回饋呈現「這筆活動已被記錄」與角色正向回應。
- 如果現有 API 只提供最新活動文字、沒有 receipt ID／時間／已讀狀態，先請 A 提供最小介面，不用文字 hash 當正式 receipt identity。
- 自動慶祝僅對本帳號登入期間觀察到的新 confirmed receipt；初次載入歷史紀錄不自動慶祝。記錄方式須帳號隔離；不要隨便把健康內容存 localStorage。
- 第一版優先做內嵌成果卡，可手動查看；跨裝置永久收藏／持久已讀需要 Cloud 支援，未具備時明確列待辦，不能假稱一次性已完成。
- 不顯示推算的「本次 +XP／+金幣」；只有既有正式服務可提供的確定結果才呈現。
- 分享若實作，先提供預覽與敏感資料遮蔽，必須由使用者點擊；不得自動公開。

## C3：串接角色與共同世界

- B 的角色契約穩定後，顯示目前階段與下一階段條件，進入既有圖鑑／進化頁。
- 不在首頁重寫等級與 XP 門檻公式。
- D 的摘要元件可接到首頁，但只顯示目前選定且合法可見的關係。
- D 尚未交付時先不放假家庭樹／假團體進度；保持 C1 可獨立交付。
- 角色個人成長與 Family Bond／團體成果分開呈現。

## 可修改與不可修改

可改：上述主入口、專用 presentation model／widget、專用 scoped Web 腳本和 CSS、相關測試。

不得直接改：`lib/state/app_state.dart`、`web_dashboard/assets/app.js`、全站 styles、Cloud、Rules、角色 parser、D 的頁面。確實需要時在 PR 列介面需求交 A 協調。

不做七日旅程、配件交易或新獎勵；不為了展示直接寫 Firebase fixture 到正式資料庫。

## 驗收矩陣

- 未登入、沒有任務、手動任務、只有自動健康任務、全部完成。
- receipt 初次載入／新確認／重複快照／錯誤／cache。
- A 帳號退出後登入 B，不能看到 A 的回饋或角色。
- 360px／桌面、長任務名、大字體、深色／減少動畫，主要按鈕均可操作。
- 個人／家長／孩子／團體身分不因改版失去既有入口。

測試應驗公開呈現與操作結果，不只比對原始碼字串。補純 resolver 與 widget／Web 行為測試，附實際畫面。最終交付 C1、C2、C3 各自完成／受阻狀態與 head SHA；不把 mock 圖當成實際已連動。
