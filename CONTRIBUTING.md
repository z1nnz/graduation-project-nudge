# Nudge 團隊協作規則

所有功能都透過分支與 Pull Request 進入 `main`。組員不得直接推送或自行合併 `main`；最後審查與合併由 `@z1nnz` 負責。

## 第一次準備

```bash
git clone https://github.com/z1nnz/graduation-project-nudge.git
cd graduation-project-nudge
git config user.name "你的名字"
git config user.email "你的 GitHub 驗證信箱"
git config pull.ff only
flutter pub get
npm ci --prefix functions
npm ci --prefix scripts
```

## 開始一項任務

先從最新 `main` 建立新分支：

```bash
git switch main
git pull --ff-only origin main
git switch -c feature/你的名字-功能名稱
```

分支範例：

- `feature/amy-family-tree`
- `feature/ming-group-planet`
- `fix/lin-health-ledger-sync`
- `test/wei-family-role-permissions`

一個分支與一個 PR 只處理一項可驗收功能。

## 提交前檢查

```bash
git status
git diff
flutter analyze
flutter test
node --test test/*.js
npm --prefix functions test
```

只加入本次需要的檔案，不要直接使用 `git add .`：

```bash
git add lib/指定檔案.dart test/指定測試.dart
git diff --cached
git commit -m "feat: describe the completed capability"
git push -u origin feature/你的名字-功能名稱
```

後續修改同一分支：

```bash
git add 指定檔案
git diff --cached
git commit -m "fix: address review feedback"
git push
```

## Pull Request

在 GitHub 建立 PR 時確認：

- Base：`main`
- Compare：自己的功能分支
- 完整填寫 PR template
- 指定 `@z1nnz` 為 Reviewer
- 不自行按 Merge

收到 `Request changes` 後，在原分支修正並 push；原 PR 會自動更新。

合併前必須看到以下四個 GitHub Actions 檢查全部通過：

- `Flutter analyze and tests`
- `Web and shared contract tests`
- `Cloud Functions tests`
- `Firestore rules and transaction tests`

若 GitHub Ruleset 要求填寫 status check 名稱，請逐字選擇以上四項；不要把 workflow 名稱 `Nudge Pull Request Checks` 當成單一檢查。

## 同步新的 main

```bash
git fetch origin
git merge origin/main
```

發生衝突時先理解兩邊內容再處理。不確定資料契約、Rules 或 migration 的取捨時停止修改並請求審查。禁止 `git push --force`。

## 安全與產品一致性

- 不提交 `.env`、Firebase service account、OAuth token、App Check token 或使用者資料。
- App 與 Web 不得直接發放 Reward、角色 XP 或改寫 canonical Activity Ledger。
- 家長／孩子、團體管理者／成員的限制必須同時存在於 UI、Cloud 與 Rules。
- App、Web、Cloud 必須共用同一 Membership、角色、圖鑑、進化鏈和 Ledger 契約。
- 修改欄位、索引或舊投影時，PR 必須附 migration dry-run、apply gate 與 rollback 說明。
- 離線、重試及重送不得重複建立 Reward 或關係成果。
