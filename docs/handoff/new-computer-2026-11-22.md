# Nudge 新電腦完整交接

建立：2026-11-22（Asia/Taipei）。這是交接快照，不是所有功能已完成的證明。開始工作先重新查 GitHub 狀態。

## 1. 先知道要搬什麼

原始碼正式來源：https://github.com/z1nnz/graduation-project-nudge

建議 clone，不建議只用 Code → Download ZIP：clone 保留版本歷史，也能取得遠端功能分支；ZIP 只是選定分支的檔案快照，不含未提交檔案，也不包含所有其他分支。

本交接資料分成：

- 本文件：產品邊界、現況、環境、續作和 PR 審查。
- 四包工作規格：`Nudge-四包並行開發-2026-11-22.zip`，或 PR #70 的 `docs/optimization-packages/`。
- `nudge-all-committed.bundle`：本機 Git 中已有的提交與 refs 備份，不含未提交修改。這是私有備份，可能含歷史內部資訊，不要放公共雲端或 GitHub release。
- `local-original-uncommitted.tar.gz`：原工作目錄中未提交的指定文件、素材與 iOS 修改。
- `local-hardware-uncommitted.tar.gz`：硬體學習分支未提交的指定文件、PlatformIO 設定與兩套螢幕 smoke test。
- Orbit 開發包與韌體預覽：展示、建置與組員燒錄交接用，不代表實機已成功。

兩個 local archive 是指定範圍備份，不是整台電腦鏡像。沒有搬 SDK、build／node_modules／Pods／.pio 快取、全域憑證、CodeGraph 索引或獨立存在其他資料夾的文件。全域登入與簽章要重新設定；舊電腦暫時保留。

## 2. 下載與開啟專案

先安裝 Git、GitHub CLI（gh）；用自己的 GitHub 帳號登入，確認具有 repository 權限。另一位使用者要先被邀請為 collaborator。使用你本人的帳號時不用重邀，但需重新登入。

```sh
gh auth login
gh auth status
git clone https://github.com/z1nnz/graduation-project-nudge.git
cd graduation-project-nudge
git fetch origin
git status
git branch -r
```

新機如果只有本地 bundle 或需救回未推送提交，另建救援 clone，不覆蓋正常工作目錄：

```sh
git clone nudge-all-committed.bundle nudge-rescue
cd nudge-rescue
git remote set-url origin https://github.com/z1nnz/graduation-project-nudge.git
git fetch origin
git branch -a
```

bundle clone 的預設分支未必是 main，備份內的本機 main 也可能過時。重新 fetch GitHub 後，若要從最新遠端版本工作，可在乾淨目錄使用 `git switch -c recovery-current-main origin/main`；不要直接把舊 main 當成最新。不要執行 `git push --mirror` 或 `git push --all`，避免把歷史分支全部推上去。

檢視單一 PR（建議在獨立 clone 進行）：

```sh
gh pr checkout 66
git status
git log -1 --oneline
```

PR #70 尚未合併，所以 clone main 看不到四包文件是正常的。可從 GitHub #70 的 Files changed 閱讀，或在獨立工作目錄 checkout #70；不需要先合併才能閱讀規格。

## 3. 建議兩個 AI 用不同目錄

避免 Claude 與 Codex 在同一工作目錄切換分支、覆蓋檔案。初學者可用三個獨立 clone：`nudge-codex`、`nudge-claude-home`、`nudge-claude-worlds`。它們指向同一個 GitHub repository，但各有工作分支。每個 clone 各跑一次依賴安裝。

- Codex：A 審查整合，B 角色進化管線。
- Claude 第一個工作階段：C 角色首頁。
- Claude 第二個工作階段：D 自律房／家庭／團體。

完整要求不重複寫在這裡，讀四包 README 與自己的 MD。不要讓兩個 AI 都接同一包、不要同時寫相同共享檔案。CodeGraph 若新機沒有 `.codegraph/` 就直接用一般工具；不要複製舊索引當成新機現況，也不擅自建立索引。

## 4. 目前版本與進度

建立交接時，遠端 main 為 `27f1e4d`。舊電腦原資料夾停在較舊的 `7f14669`，不能把那個資料夾的 HEAD 誤認為最新 main。

- #67 已合併：App／Web 下一步小任務建議。
- #68 已合併：Cloud 確認的活動回饋。不是自動發放新獎勵，也不是完整慶祝系統。
- #66 草稿：角色穩定識別、嚴格進化資料與排程；仍缺安全 apply／rollback 與正式遷移驗收。分支 `codex/avatar-evolution-pipeline`，已知 head `0405f7c`。
- #69 草稿：PWA 安裝入口／備援提示；先前 CI 六項全綠，真實安裝尚未驗。分支 `codex/web-companion-install`，已知 head `08af5dc`。沒有新增 Service Worker 離線私有資料快取。
- #65：Orbit 韌體預覽與展示，head `9eb40f2`；base 是 `feature/roy-package07-08-demo-controller`，不是 main。先看 #25 依賴。
- #70 草稿：四包交接規格，head `4146280`，分支 `codex/companion-world-loop`。只有文件，不是功能已完成。
- 組員其他待審：#18、#19、#20、#22、#23、#24、#25、#26、#61、#62；重新查依賴及最新 SHA，不照編號盲合併。

查看最新：

```sh
gh pr list --state open --limit 50
gh pr view 66
gh pr checks 66
```

GitHub Pages：https://z1nnz.github.io/graduation-project-nudge/ 。已部署的來源與本機新分支不同，不能看到網頁就認為所有 PR 都已上線。

## 5. 新機工具與安裝驗證

版本依本次查到的 `.github/workflows/ci.yml`，不是自動追最新版：Flutter 3.41.7、Dart 需求 `^3.11.5`、Node.js 22、Java 21、Gradle 8.14、CocoaPods 1.16.2（macOS iOS）、Firebase CLI 15.18.0（emulator gate）。開始時再對照最新 CI。

必要：Git、gh、Flutter SDK、Node.js 22。完整 Rules 測試加 Java 21／Firebase CLI；Android 加 Android Studio／SDK；iOS 必須 macOS＋Xcode，Windows 不能做本機 iOS 建置。韌體另裝 PlatformIO，版本及板子／螢幕依該分支設定，不先升級依賴。

```sh
git --version
gh --version
flutter --version
flutter doctor -v
node --version
npm --version
java -version
flutter pub get
npm ci --prefix functions
npm ci --prefix scripts
flutter analyze
flutter test
node --test test/*.js
npm --prefix functions test
```

CI 的 Rules gate 用 `firebase emulators:exec --only auth,firestore` 跑 Rules 與交易測試；完整命令見 `.github/workflows/ci.yml`。一般測試若因缺少 emulator 而跳過，不算 Rules 驗證已完成。只啟動本機 emulator 不等於部署 production；不要執行 seed、migrate --apply 或 deploy 來試工具是否安裝成功。

macOS 需要 iOS 依賴時，先確認 Xcode 與相容 Ruby，再用專案 pin 的 CocoaPods：

```sh
pod _1.16.2_ install --deployment --project-directory=ios
```

不要用刪 lockfile／任意 pod update 掩蓋版本差異。使用者明確不要求實體 iPhone 安裝驗收，不能把這件事重新列為阻擋。

## 6. Firebase／Cloud 不要搬錯

搬電腦是更換開發環境，不是遷移雲端資料庫。繼續使用現有專案 `nudge-discipline-app`，不要新建另一個 Firestore 或重置使用者資料。

版本庫已有 `.firebaserc`、`firebase.json`、`lib/firebase_options.dart`、Android `google-services.json`、iOS `GoogleService-Info.plist`。這些 client 設定不是 Admin 授權；不要因有 Firebase API key 就以為取得管理權限，也不要直接重新產生設定覆蓋。

Web 若需要 App Check runtime 設定，參照 `web_dashboard/assets/runtime-config.example.js` 與 ADR 0012，先確認實際頁面如何載入；不要把 placeholder 當成正式設定。公開 site key 也不能取代 Cloud 私密憑證。

- GitHub、Firebase CLI、Google Cloud CLI 在新機各自登入需要的帳號；角色不足請管理者授權，不共享密碼。
- Cloud Functions secrets、GitHub Actions secrets、Rules、雲端資料仍在原服務，不會隨 clone 下載。
- service account JSON、OAuth／refresh token、App Check debug token、Apple 憑證、`.env` 不可放 PR、聊天或公開壓縮包；由擁有者以安全管道管理。
- 不複製整個 `.config/gcloud`、`.config`、瀏覽器 cookie 或 `.codex` 資料夾給別人。
- 本機模擬與單元測試優先，不因要測 UI 而發放 Admin 權限。

之前已建立活動 receipt 索引的證據在 `docs/acceptance/2026-11-22-activity-feedback-index.md`；新機先讀文件及查現況，不重複部署整份 indexes。

## 7. 不能違反的系統邊界

先讀根目錄 `CONTEXT.md`、`CONTRIBUTING.md` 與 `docs/adr/`，詳細規格引用原文件，不另建第二套定義。

- Cloud Activity Ledger 是正式活動、獎勵、room contribution 的依據；App／Web／韌體不能自行鑄造 XP／金幣。
- canonical Membership 決定身分，不用使用者自行填的角色字串授權。
- 家長不能替孩子開同意；團體管理者／房主不能控制別人的活動開始結束。
- 家庭／團體共同成長與個人角色進化分開，不混算。
- Guest／離線快取／pending／錯誤不是 Cloud confirmed。
- 保留既有使用者改動，禁止 reset --hard、clean、覆蓋 dirty worktree、force push 或任意刪資料。

## 8. 硬體與報告交接

目前兩套裝置定位：圓形 Orbit 為隨身陪伴／專注畫面，方形 Station 為桌面夥伴／已購買周邊。先做到競賽 demo，不擅自追加電表、電池系統或心率／睡眠偵測。

可寫畫面、跑 native 測試及 PlatformIO build，附預覽、依賴版本、指令、接線與限制開 PR；持有 ESP 的組員下載對應 commit 燒錄，回傳完整開機／輪播影片、板型、螢幕型號與錯誤日誌。未實測的腳位或供電不能靠猜測。

`Nudge-Orbit-韌體畫面預覽.png` 是韌體繪圖程式的軟體渲染，不是實機照片。不要用另張 AI 概念圖宣稱韌體已做到，也不要把離線 DEMO 記進正式獎勵。#65 尚待與前置韌體 PR 整合。

三頁專題簡介需求：基本資料、緣起、系統架構、功能特色、系統貢獻；標楷體大標 14 粗體、小標 12 粗體、內文 12，文字靠左、圖表置中且編號、不加頁碼、最多三頁。場次／報告順序／組員資料需使用者確認，不臆造。此交接包不保證包含 Downloads 中所有舊 Word／PDF，舊機相關文件須另行挑選搬移；只用最新版並註明預覽／實拍。

## 9. 本機未提交備份怎麼還原

只有需要找回舊稿時才用；不要直接解到最新 main 覆蓋檔案。

1. 先把 local archive 解壓到空白的「參考資料」目錄，檢視清單。
2. 原資料夾備份基準為 `7f14669`／`codex/relationship-evidence-purge`；硬體備份基準為 `2d6d07e`／`codex/hardware-bringup-lesson`。
3. 原備份含 iOS Podfile／lock 的未提交版本，可能與已合併 #21 不同；只作比較，不直接還原到 main。
4. 硬體備份有兩套歷史 smoke test 和改過的 PlatformIO 設定，不等於推薦的最終韌體，也不代表螢幕故障原因已確定。
5. 用新的 recovery 分支挑選必要內容，檢查敏感資料，測試後開 PR。不要整包 git add。

已略過 embedded worktree 的 `android/build/`，屬建置產物；略過 CodeGraph 資料庫與快取。Git bundle 本身不保存這些未提交檔案。保留舊電腦到新機確認原始碼、素材、分支與報告都可取得後，再決定如何清理。

## 10. 怎麼審 PR：不是按綠燈就合併

### 在 GitHub 網站

1. Repository → Pull requests → 開啟目標 PR。
2. Conversation 看需求、限制、前置 PR；確認 base 與最新 commit。
3. Files changed 看真正差異。檢查有無金鑰、無關檔案、大量刪檔、錯誤角色／資料契約。
4. Checks 看六項 gate 的最新執行。舊 commit 的通過不代表新 head 通過。
5. 有 UI 改動看實際畫面與主要流程；Cloud／Rules／migration 看越權、交易與回復證據。
6. Files changed → Review changes：有問題選 Request changes；只討論選 Comment；確認可接受才選 Approve，再 Submit review。
7. Approve 是審查意見，Merge 是另一個操作。前置已整合、討論已處理、gate 全過才選可用的合併方式。不要擅自更改全站 Ruleset。

同一 GitHub 帳號在兩台電腦仍是同一個人，不能核准自己開的 PR。AI 協助審查也不會變成第二位 reviewer。若遇 REVIEW_REQUIRED，請其他有權限組員核准；有政策允許的管理員 bypass 也不是修正 CI／權限缺陷的替代方式。

### 給新 AI 的安全審查指令

> 請審查 PR #N。先讀 START-HERE 與 CONTRIBUTING、CONTEXT、對應 ADR，查最新 base/head，建立依賴關係。以 PR 的 base merge-base 為比較基準，不一律假設 main。先提供需求與程式兩軸 findings、檔案行號、重現方式、嚴重度與建議，並執行適用測試。不要因 CI 綠燈就說完成。這一步只審查，不部署、不執行 production migration、不合併；列出需要我或其他組員決定的事項。

如果要 AI 修正／合併，另明確交代範圍。已授權修正時仍保留他人變更；最後確認 exact head 與新 gate，不因舊對話曾同意 bypass 就自行擴張權限。

### CLI 檢查

```sh
gh pr view 66
gh pr diff 66
gh pr checks 66
```

要在本機跑程式，先用乾淨的獨立 clone，再 `gh pr checkout 66`，依該 PR 說明與 CI 安裝測試。不要在有未提交工作時隨便切分支。不要把審查他人程式時得到的執行權限當成 deploy 權限。

六項 gate：Flutter analyze and tests；Android Kotlin compile；iOS dependency lock；Web and shared contract tests；Cloud Functions tests；Firestore rules and transaction tests。

官方參考：

- Clone：https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository
- Review：https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/reviewing-proposed-changes-in-a-pull-request

## 11. 建議技能（新機存在才使用）

- `handoff`：續作交接；`implement`：按工作包實作；`code-review`：需求／規範雙軸審查；`diagnosing-bugs`：疑難排查；`resolving-merge-conflicts`：實際 merge 衝突。
- Flutter／Node 的既有測試優先；使用 `tdd` 前依技能確認測試 seam。
- 三頁 Word 用文件技能並實際 render 檢查；不能只看程式生成成功。
- 新機工具與 skills 不假設會隨專案 clone 自動出現。個別安裝需要的技能即可；不要複製含登入資料的整個 AI 設定資料夾。缺技能時說明並用一般 Git／測試流程，不要假裝工具可用。

## 12. 新機第一段交代（可貼給 Claude／Codex）

> 你正在接手 Nudge。請先讀本 START-HERE，再讀 repository 的 CONTRIBUTING.md、CONTEXT.md、docs/adr/ 與 PR #70 的四包工作規格。先回報本機 OS、目前分支／dirty 狀態、最新 main 與開啟 PR，確認我指派哪一包；不要重做已合併 #67／#68，不把未合併分支當 main。Codex 負責 A/B，Claude 分別負責 C/D，遵守檔案所有權。使用新分支與獨立工作目錄；不覆蓋備份、不搬 token、不重新建 Firebase、不擅自部署或執行 production migration。現階段沒有 ESP，只能軟體建置與畫面預覽，實機驗收交持有 ESP 組員。先確認環境與一個可驗收切片，再開始寫程式。
