# 34 份已發布 Issue 本文（快照）

全部已查回核對；之後的認領狀態以 GitHub 為準，未代表實機通過。

# [DEMO-00][P0-A] 確認舊 32 包作廢

<!-- nudge-demo:CompetitionDemoV1:DEMO-00 -->
## 目標
確認舊 32 包作廢。驗收重點：README、群組訊息與新 ZIP 都指向新版。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：全員（不是已認領／GitHub assignee）。估計專注工作 30-60 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-00，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：無其他細項依賴；仍需核對範圍與零件。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/18
- https://github.com/z1nnz/graduation-project-nudge/pull/19
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：README、群組訊息與新 ZIP 都指向新版
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-01][P0-A] 建立 Orbit 零件卡

<!-- nudge-demo:CompetitionDemoV1:DEMO-01 -->
## 目標
建立 Orbit 零件卡。驗收重點：圓屏正反面、型號、插接方向、USB 燒錄紀錄。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 30-60 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-01，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：無其他細項依賴；仍需核對範圍與零件。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：圓屏正反面、型號、插接方向、USB 燒錄紀錄
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-02][P0-A] 建立 Station 零件卡

<!-- nudge-demo:CompetitionDemoV1:DEMO-02 -->
## 目標
建立 Station 零件卡。驗收重點：方屏正反面、商品頁、driver、解析度、連接方式。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 30-60 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-02，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：無其他細項依賴；仍需核對範圍與零件。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：方屏正反面、商品頁、driver、解析度、連接方式
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-03][P0-B] 固定 Demo 資料與 3 分鐘腳本

<!-- nudge-demo:CompetitionDemoV1:DEMO-03 -->
## 目標
固定 Demo 資料與 3 分鐘腳本。驗收重點：兩台使用相同人物、任務、房間與 XP。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：專題負責人（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-03，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-00](https://github.com/z1nnz/graduation-project-nudge/issues/27)、[DEMO-01](https://github.com/z1nnz/graduation-project-nudge/issues/28)、[DEMO-02](https://github.com/z1nnz/graduation-project-nudge/issues/29)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/22
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：兩台使用相同人物、任務、房間與 XP
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-10][P0-B] 建立 DemoScene 與 DemoData

<!-- nudge-demo:CompetitionDemoV1:DEMO-10 -->
## 目標
建立 DemoScene 與 DemoData。驗收重點：host test 覆蓋 8 幕。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-10，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-03](https://github.com/z1nnz/graduation-project-nudge/issues/30)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：host test 覆蓋 8 幕
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-11][P0-B] 自動時間軸

<!-- nudge-demo:CompetitionDemoV1:DEMO-11 -->
## 目標
自動時間軸。驗收重點：無輸入可走完整流程。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-11，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-10](https://github.com/z1nnz/graduation-project-nudge/issues/31)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：無輸入可走完整流程
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-12][P0-B] Next／Restart API

<!-- nudge-demo:CompetitionDemoV1:DEMO-12 -->
## 目標
Next／Restart API。驗收重點：任一 Scene 可重新開始。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-12，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-10](https://github.com/z1nnz/graduation-project-nudge/issues/31)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：任一 Scene 可重新開始
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-13][P0-B] Optional adapter 失敗策略

<!-- nudge-demo:CompetitionDemoV1:DEMO-13 -->
## 目標
Optional adapter 失敗策略。驗收重點：周邊 begin 失敗仍進畫面。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-13，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-10](https://github.com/z1nnz/graduation-project-nudge/issues/31)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：周邊 begin 失敗仍進畫面
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-01][P0-A] 圓屏整屏色彩與方向

<!-- nudge-demo:CompetitionDemoV1:ORB-01 -->
## 目標
圓屏整屏色彩與方向。驗收重點：五色輪播＋影片。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-01，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-01](https://github.com/z1nnz/graduation-project-nudge/issues/28)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：五色輪播＋影片
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-02][P0-A] Home／Focus／Complete 靜態畫面

<!-- nudge-demo:CompetitionDemoV1:ORB-02 -->
## 目標
Home／Focus／Complete 靜態畫面。驗收重點：三幕可辨認。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-02，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-01](https://github.com/z1nnz/graduation-project-nudge/issues/35)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：三幕可辨認
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-03][P0-A] 三幕自動播放

<!-- nudge-demo:CompetitionDemoV1:ORB-03 -->
## 目標
三幕自動播放。驗收重點：冷啟動 3/3＋實機影片。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-03，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-02](https://github.com/z1nnz/graduation-project-nudge/issues/36)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：冷啟動 3/3＋實機影片
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-04][P0-B] 字型、圓形安全區與 8 幕

<!-- nudge-demo:CompetitionDemoV1:ORB-04 -->
## 目標
字型、圓形安全區與 8 幕。驗收重點：完整 Scene 對照。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-04，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-03](https://github.com/z1nnz/graduation-project-nudge/issues/37)、[DEMO-10](https://github.com/z1nnz/graduation-project-nudge/issues/31)、[DEMO-11](https://github.com/z1nnz/graduation-project-nudge/issues/32)、[DEMO-12](https://github.com/z1nnz/graduation-project-nudge/issues/33)、[DEMO-13](https://github.com/z1nnz/graduation-project-nudge/issues/34)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：完整 Scene 對照
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-05][P0-B] Focus 圓環與完整故事

<!-- nudge-demo:CompetitionDemoV1:ORB-05 -->
## 目標
Focus 圓環與完整故事。驗收重點：8 幕完整。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-05，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-04](https://github.com/z1nnz/graduation-project-nudge/issues/38)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：8 幕完整
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-06][P0-B] Orbit Restart 與重播

<!-- nudge-demo:CompetitionDemoV1:ORB-06 -->
## 目標
Orbit Restart 與重播。驗收重點：10 輪＋10 次。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-06，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-05](https://github.com/z1nnz/graduation-project-nudge/issues/39)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：10 輪＋10 次
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-07][P1] 現有觸控／按鍵

<!-- nudge-demo:CompetitionDemoV1:ORB-07 -->
## 目標
現有觸控／按鍵。驗收重點：短按 Next、長按 Restart。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-07，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-03](https://github.com/z1nnz/graduation-project-nudge/issues/37)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：短按 Next、長按 Restart
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [ORB-08][P1] 精簡動畫

<!-- nudge-demo:CompetitionDemoV1:ORB-08 -->
## 目標
精簡動畫。驗收重點：Boot、Focus、Complete 三種。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Orbit：XIAO ESP32-S3＋Seeed 圓屏，實物方向／USB 仍需持板者驗。
預設責任角色：johnsnow（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 ORB-08，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-05](https://github.com/z1nnz/graduation-project-nudge/issues/39)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：Boot、Focus、Complete 三種
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-01][P0-A] 方屏官方最小範例

<!-- nudge-demo:CompetitionDemoV1:STA-01 -->
## 目標
方屏官方最小範例。驗收重點：五色輪播＋影片。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-01，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-02](https://github.com/z1nnz/graduation-project-nudge/issues/29)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：五色輪播＋影片
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-02][P0-A] Home／Focus／Complete 靜態畫面

<!-- nudge-demo:CompetitionDemoV1:STA-02 -->
## 目標
Home／Focus／Complete 靜態畫面。驗收重點：三幕可辨認。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-02，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-01](https://github.com/z1nnz/graduation-project-nudge/issues/43)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：三幕可辨認
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-03][P0-A] 三幕自動播放

<!-- nudge-demo:CompetitionDemoV1:STA-03 -->
## 目標
三幕自動播放。驗收重點：冷啟動 3/3＋實機影片。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-03，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-02](https://github.com/z1nnz/graduation-project-nudge/issues/44)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：冷啟動 3/3＋實機影片
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-04][P0-B] 字型、rotation、版面格線與 8 幕

<!-- nudge-demo:CompetitionDemoV1:STA-04 -->
## 目標
字型、rotation、版面格線與 8 幕。驗收重點：完整 Scene 對照。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-04，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-03](https://github.com/z1nnz/graduation-project-nudge/issues/45)、[DEMO-10](https://github.com/z1nnz/graduation-project-nudge/issues/31)、[DEMO-11](https://github.com/z1nnz/graduation-project-nudge/issues/32)、[DEMO-12](https://github.com/z1nnz/graduation-project-nudge/issues/33)、[DEMO-13](https://github.com/z1nnz/graduation-project-nudge/issues/34)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：完整 Scene 對照
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-05][P0-B] 任務、支持與完整故事

<!-- nudge-demo:CompetitionDemoV1:STA-05 -->
## 目標
任務、支持與完整故事。驗收重點：8 幕完整。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-05，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-04](https://github.com/z1nnz/graduation-project-nudge/issues/46)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：8 幕完整
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-06][P0-B] Station Restart 與重播

<!-- nudge-demo:CompetitionDemoV1:STA-06 -->
## 目標
Station Restart 與重播。驗收重點：10 輪＋10 次。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-06，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-05](https://github.com/z1nnz/graduation-project-nudge/issues/47)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：10 輪＋10 次
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-07][P1] 現有旋鈕／按鍵

<!-- nudge-demo:CompetitionDemoV1:STA-07 -->
## 目標
現有旋鈕／按鍵。驗收重點：選任務、確認、Restart。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-07，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-03](https://github.com/z1nnz/graduation-project-nudge/issues/45)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：選任務、確認、Restart
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-08][P1] 現有 LED 完成效果

<!-- nudge-demo:CompetitionDemoV1:STA-08 -->
## 目標
現有 LED 完成效果。驗收重點：拔除後仍可 P0-A。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-08，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-03](https://github.com/z1nnz/graduation-project-nudge/issues/45)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：拔除後仍可 P0-A
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [STA-09][P1] 現有光感／蜂鳴器

<!-- nudge-demo:CompetitionDemoV1:STA-09 -->
## 目標
現有光感／蜂鳴器。驗收重點：固定亮度 fallback／靜音。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
Station：Waveshare 17344 ST7789V／VW 240×320；獨立第二塊 XIAO 與 pinmap 未確認，不猜 GPIO。
預設責任角色：roy（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 STA-09，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[STA-03](https://github.com/z1nnz/graduation-project-nudge/issues/45)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：固定亮度 fallback／靜音
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-30][P0-B] 共用色彩與角色姿態

<!-- nudge-demo:CompetitionDemoV1:DEMO-30 -->
## 目標
共用色彩與角色姿態。驗收重點：同 Scene 同意義。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：專題負責人（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-30，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-05](https://github.com/z1nnz/graduation-project-nudge/issues/39)、[STA-05](https://github.com/z1nnz/graduation-project-nudge/issues/47)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：同 Scene 同意義
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-31][P0-B] 固定資料加入 DEMO 標記

<!-- nudge-demo:CompetitionDemoV1:DEMO-31 -->
## 目標
固定資料加入 DEMO 標記。驗收重點：兩台可辨認。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：全員（不是已認領／GitHub assignee）。估計專注工作 30-60 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-31，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-30](https://github.com/z1nnz/graduation-project-nudge/issues/52)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：兩台可辨認
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-32][P0-A] 兩台斷網三幕展示

<!-- nudge-demo:CompetitionDemoV1:DEMO-32 -->
## 目標
兩台斷網三幕展示。驗收重點：各 3 輪。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：全員（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-32，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-03](https://github.com/z1nnz/graduation-project-nudge/issues/37)、[STA-03](https://github.com/z1nnz/graduation-project-nudge/issues/45)。
- P0-A 裝置工作可平行，未知零件先核對，不等動畫／感測器。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：各 3 輪
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-33][P0-B] 3 分鐘一鏡到底

<!-- nudge-demo:CompetitionDemoV1:DEMO-33 -->
## 目標
3 分鐘一鏡到底。驗收重點：影片與計時。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：全員（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-33，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-03](https://github.com/z1nnz/graduation-project-nudge/issues/30)、[ORB-06](https://github.com/z1nnz/graduation-project-nudge/issues/40)、[STA-06](https://github.com/z1nnz/graduation-project-nudge/issues/48)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：影片與計時
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-34][P0-B] 保存 binary 與 build id

<!-- nudge-demo:CompetitionDemoV1:DEMO-34 -->
## 目標
保存 binary 與 build id。驗收重點：可在另一台電腦找到並燒錄。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：專題負責人（不是已認領／GitHub assignee）。估計專注工作 30-60 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-34，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[ORB-06](https://github.com/z1nnz/graduation-project-nudge/issues/40)、[STA-06](https://github.com/z1nnz/graduation-project-nudge/issues/48)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：可在另一台電腦找到並燒錄
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [DEMO-35][P0-B] 比賽日故障排練

<!-- nudge-demo:CompetitionDemoV1:DEMO-35 -->
## 目標
比賽日故障排練。驗收重點：不開 App／拔 P1 仍可說明。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：全員（不是已認領／GitHub assignee）。估計專注工作 60-240 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 DEMO-35，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-33](https://github.com/z1nnz/graduation-project-nudge/issues/55)、[DEMO-34](https://github.com/z1nnz/graduation-project-nudge/issues/56)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/19
- https://github.com/z1nnz/graduation-project-nudge/pull/20
- https://github.com/z1nnz/graduation-project-nudge/pull/22
- https://github.com/z1nnz/graduation-project-nudge/pull/23
- https://github.com/z1nnz/graduation-project-nudge/pull/24
- https://github.com/z1nnz/graduation-project-nudge/pull/25
- https://github.com/z1nnz/graduation-project-nudge/pull/26
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：不開 App／拔 P1 仍可說明
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [BLE-01][P2] App 掃描 Demo 裝置

<!-- nudge-demo:CompetitionDemoV1:BLE-01 -->
## 目標
App 掃描 Demo 裝置。驗收重點：真實手機影片。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：有餘力者（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 BLE-01，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[DEMO-30](https://github.com/z1nnz/graduation-project-nudge/issues/52)、[DEMO-31](https://github.com/z1nnz/graduation-project-nudge/issues/53)、[DEMO-33](https://github.com/z1nnz/graduation-project-nudge/issues/55)、[DEMO-34](https://github.com/z1nnz/graduation-project-nudge/issues/56)、[DEMO-35](https://github.com/z1nnz/graduation-project-nudge/issues/57)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：真實手機影片
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [BLE-02][P2] App 傳 Next／Restart

<!-- nudge-demo:CompetitionDemoV1:BLE-02 -->
## 目標
App 傳 Next／Restart。驗收重點：各 10 次。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：有餘力者（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 BLE-02，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[BLE-01](https://github.com/z1nnz/graduation-project-nudge/issues/58)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：各 10 次
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。


# [BLE-03][P2] 斷線降級

<!-- nudge-demo:CompetitionDemoV1:BLE-03 -->
## 目標
斷線降級。驗收重點：裝置自動 Demo 不停止。
來源：新版 package 11，固定需求 9ace911bf892dfb3a451acce7e2ecbeb41904f7d。

## 裝置與零件
兩台各自驗證；兩塊獨立主控／版本／影片必須分開記錄。
預設責任角色：有餘力者（不是已認領／GitHub assignee）。估計專注工作 60-180 分鐘，非承諾；阻塞半天回報。

## Scope
- In：只完成 BLE-03，每個 Issue 一分支一個可驗收 PR，base main。
- Out：不加購、不改正式帳號／Cloud／Ledger／OTA，不為消警告猜 pin，不順便認領其他 Issue。
- 前置：[BLE-02](https://github.com/z1nnz/graduation-project-nudge/issues/59)。
- 目前不可認領：全體 P0-A 實機門檻未通過；本 Issue 只建待辦，不因先前軟體準備而跳過前置。

## 既有來源參考
- https://github.com/z1nnz/graduation-project-nudge/pull/25
以上只是已有軟體／文件參考，尚未合併與未驗項目按原 PR 揭露；不是本 Issue 已 source-complete 或 device-verified。

## 實作步驟
1. 確認認領與前置；從最新 main 建自己的分支，只改此成果。
2. 核對零件／型號，先最小 compile，再一個畫面或輸入一輪。
3. 實機由持板者稍後 upload／錄影；目前使用者已明確暫緩，不代填成功。
4. 存 source commit、env、build id、profile／binary hash、影片與失敗紀錄；六 CI 全綠後請 z1nnz 審查，不自行 merge。

## 驗收
- [ ] compile／文件驗證：貼命令、版本與完整結果；不適用須說明，CI 不省略
- [ ] physical upload：實際裝置／USB／版本，SUCCESS 不是畫面驗收
- [ ] physical display/input：裝置自動 Demo 不停止
- [ ] fallback：無 App／網路／P1 仍可最低 P0-A；未採項目明示
- [ ] video：連續實物畫面、相同硬體版本、hash、時間碼；不是電腦預覽

## 交付
- Branch：待認領（單 Issue）
- Commit／Environment／Build id：待補
- Video／SHA-256：未拍
- Binary／Profile hash：待補
- Known limitations：實機稍後驗收、團隊認領未確認；P1／BLE OFF、Station pinmap 未配置

## 狀態與關閉
維持 open、無 assignee。沒有影片與版本不得關閉；沒有實機證據至多標 source-complete，不能標 device-verified。本 Issue 建立不等於認領、啟用周邊或驗收通過。
