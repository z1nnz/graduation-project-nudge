# Package 02｜雙裝置展示故事與評審流程

本次交付展示腳本、固定資料、雙機 Scene 對照、操作卡及錄影驗收清單。
使用者已要求進行 package 02，實機則延續「稍後驗收」；此處準備 P0-B 文件，
沒有提前宣稱 P0-A、P0-B 韌體或實體畫面已完成。

來源：[工作包 02](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/02-demo-story-and-judge-flow.md)、
[範圍 00](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/00-scope-reset.md)、
[交付模板 13](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/13-delivery-evidence-template.md)。
任務對照為 DEMO-03 的固定資料與三分鐘腳本；不是 DEMO-10–13 的韌體場景引擎。

## 使用入口

| 文件 | 用途 |
| --- | --- |
| [presenter-script.md](presenter-script.md) | 六段 180 秒口白、畫面提示、八幕對照與三項產品目標 |
| [cue-card.md](cue-card.md) | 現場前置、30 秒 P0-A、三分鐘操作、故障備援與重設條件 |
| [scenario.json](scenario.json) | 兩台共用的唯一固定 Demo 資料及紙面時間軸 |
| [evidence.json](evidence.json) | 五段必要實機錄影的待補清單；檔案、雜湊、版本與實測時間均未填造 |
| [self-review.md](self-review.md) | 逐項驗收、自評、扣分與 85 分提交判定 |

## 三項產品結果

1. 讓行為得到身邊可見的回應：專注後顯示完成與小芽成長，而不是只勾一項清單。
2. 讓兩台的使用位置有差異：Orbit 快速看一個重點；Station 提供桌面任務與支持脈絡。
3. 串起任務 → 自主開始 → 可選支持 → 完成 → 角色回饋；支持者不能替個人控制活動。

全部人物、房間、時間與 XP 都是固定 Demo 資料；兩台可獨立輪播，沒有即時連動宣稱。
目前 `runtimeImplemented=false`、`deviceVerified=false`，自動模式與重設也只是後續實機要求。

## 時間與控制決策

- P0-A：Home 5 秒、Focus 20 秒、Complete 5 秒，30 秒一圈。
- P0-B：Boot 1.5 秒，之後 Home 4、Ready 4、Focus 20、Support 5、Complete 4、Growth 5、Summary 6 秒。
- 第一次自 Boot 共 49.5 秒；之後 Summary 回 Home，每圈 48 秒。沒有 Scene 8。
- 採工作包 02 的 Ready 4／Summary 6 秒規劃；03 的建議時間不同，未來接入韌體時須同步設定後重新驗證。
- 三分鐘是口白長度，不把單輪場景拉長到三分鐘，也不要求停住 Home 等待講完。
- 紙面計時在「看見 Home」時歸零；兩台獨立起跑，實機漂移時依 Scene 提示等待下一圈。
- 紙面重設提示在 2:20；必須先拍到 Complete，再使用已驗證的 Restart／板上 RESET，並確認回 Home。

預設自動輪播優先；已驗證實體輸入其次，開發板／已驗證 serial 再次，App／BLE 最後且可省略。
`N`／`R` 只是其他工作包的候選介面，本包沒有建立可用的韌體命令。

## 重現文件驗證

從 repository 根目錄執行，不需 Firebase、手機、外接周邊或 Node 套件下載：

```sh
node scripts/validate_competition_demo_story.cjs
node scripts/validate_competition_demo_story.cjs --timeline
node --test test/competition_demo_story_test.js
```

輸出只能證明紙面資料／時間軸一致，不是螢幕模擬器或實機驗收。
測試放在既有 `test/*.js`，會納入現有 Web and shared contract tests，不改六項 CI 的名稱或門檻。

## 邊界與回復

本次沒有 firmware driver、GPIO、BLE、Cloud、實體按鍵或畫面渲染實作；沒有 binary、影片或上電操作。
實機門檻仍須完成後才採用完整 P0-B。沒有備援影片／binary 時，現場卡明定如實說明，不能假設它們存在。
回復可 revert 本次腳本文件、規劃驗證工具與測試，保留既有韌體及前面各工作包。
