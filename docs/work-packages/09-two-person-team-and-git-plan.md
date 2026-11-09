# 09｜兩人分工與 Git 流程

## 預設分工

若兩位組員沒有另外協調，使用下列分工：

| 組員 | 主要裝置 | 主要責任 |
| --- | --- | --- |
| `johnsnow94823@gmail.com` | Nudge Orbit | 圓屏最小顯示、8 幕畫面、圓形進度、手動／自動 Demo、Orbit 證據 |
| `roy930905@gmail.com` | Nudge Station | 方屏身分卡、最小顯示、8 幕畫面、Station 互動、Station 證據 |
| 專題負責人 | 整合與合併 | 範圍裁決、PR review、共用視覺、ZIP、比賽腳本與最終 merge |

兩人可以交換裝置，但必須在 Issue 留言後再換，避免兩人同時認為對方負責。

## 共用部分誰先做

為避免兩人同時修改相同 `main.cpp`：

1. 先建立 `demo-scenario-core` PR：Scene enum、DemoData、自動時間軸、host test。
2. 合併後 Orbit 與 Station 各自從最新 base 開分支。
3. Orbit 只新增／修改 Orbit adapter 與資源。
4. Station 只新增／修改 Station adapter 與資源。
5. Optional 周邊在兩台 P0 合併後再開新 PR。

若比賽時程很短，可建立兩個獨立 PlatformIO demo 專案，避免 driver 設定互相
破壞；共用架構留到比賽後整理。

## 分支命名

```text
feature/demo-scenario-core
feature/orbit-display-demo
feature/station-display-demo
feature/orbit-input
feature/station-input
feature/demo-visual-assets
feature/demo-ble-controller
fix/orbit-white-screen
fix/station-rotation
```

每個分支只處理一個可錄影驗收的成果。

## 開始工作

```sh
git switch main
git pull --ff-only
git switch -c feature/orbit-display-demo
```

如果團隊使用工作包 PR 分支作為暫時 base，Issue 必須明確寫出 base；功能正式
合併前仍要重新對 main。

## 每次開發循環

1. 先讓最小範例 compile。
2. 修改一個畫面或一個輸入。
3. 編譯。
4. 燒到自己的實體裝置。
5. 拍 10–30 秒影片。
6. Commit。
7. 再做下一小段。

不要累積數天後才第一次燒錄。

## Commit 格式

```text
feat(firmware): add Orbit focus ring scene
feat(firmware): add Station demo home
fix(firmware): correct square display rotation
test(firmware): cover demo scene restart
docs(demo): add Station hardware identity
```

## Push

```sh
git status
git add <這次修改的檔案>
git commit -m "feat(firmware): add Orbit focus scene"
git push -u origin feature/orbit-display-demo
```

不要使用 `git add .` 把不相關檔案全部送上去。不要直接 push main。

## PR 必須包含

- 對應 Issue。
- 做了什麼。
- 哪些檔案改動。
- 實際板子與螢幕型號。
- 編譯命令與結果。
- 實機燒錄結果。
- 影片／照片。
- P0、P1 或 P2。
- 失效時的降級方式。
- 尚未完成與未宣稱的項目。

## 合併順序

1. Demo scenario core。
2. Orbit 最小顯示。
3. Station 最小顯示。
4. 共用視覺與角色資源。
5. Orbit 完整流程。
6. Station 完整流程。
7. 既有輸入。
8. 既有 LED／感測器／蜂鳴器。
9. 選配 BLE。
10. 比賽日文件與 artifacts。

Station 不得等待 Orbit 的所有動畫，Orbit 也不得等待 Station 感測器；兩台 P0
可平行，但共用檔案要由 scenario core 先建立。

## Review 清單

專題負責人合併前確認：

- [ ] PR 沒有改到不相關的 App／Web／Cloud。
- [ ] 沒有 Token、帳號、私人資料或本機絕對路徑。
- [ ] PlatformIO compile 綠燈。
- [ ] 有實機影片，不只是終端機 SUCCESS。
- [ ] 裝置不連網仍可 Demo。
- [ ] Optional 周邊拔掉後不阻擋 P0。
- [ ] 畫面資料是 Demo 時有標記。
- [ ] 沒有新增採購需求。
- [ ] 可從影片看見完整結果。

## 衝突處理

- 不要各自在分支大改共用 `main.cpp`。
- 發現同檔衝突時先停止 rebase，於群組說明檔案與目的。
- 由共用架構 PR 先合併，其餘分支更新 base 再繼續。
- 不用 `git reset --hard` 或強推覆蓋別人的工作。

## 每日回報

```md
今天裝置：
目前 Scene：
實機成功：
影片：
下一步：
阻塞：
是否影響 P0：
```

阻塞超過半天就回報，不要自行購買新零件繞過。

