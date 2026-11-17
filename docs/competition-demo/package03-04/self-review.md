# 工作包 03／04 自評（軟體切片提交門檻）

採用使用者固定的 25／35／25／15 配分，提交門檻 85。
本輪實機依指示稍後驗收。**評分不表示整包工作完成**；所有實機指標仍待驗，沒有關閉工作包。
若編譯、測試或最新 PR CI 失敗，必須修正、重新驗證並重評，不能沿用通過分數交接。

## 03：85/100

| 類別／子項 | 得分 | 理由 |
| --- | ---: | --- |
| 內容：場景 core／資料／port | 12/12 | source、三幕／八幕、固定資料與分離邊界 |
| 內容：兩種 environment／binary | 6/9 | Orbit 可編譯顯示路徑；Station 只有 diagnostic，LCD driver／可顯示 binary 未交付，扣 3 |
| 內容：build log／版面／操作交付 | 4/4 | 可重建 artifact、hash、host 預覽與重刷說明；不當作實拍 |
| 任務：順序／restart／Complete | 10/10 | native 固定順序、晚到 tick、回捲、reset |
| 任務：兩種時間軸／自動與命令 | 6/6 | P0-A 5/20/5、P0-B 8 幕、5 秒無輸入、N/R |
| 任務：資料／不同版面／失敗降級 | 6/6 | 同一 Frame、DEMO、EffectPort 與 DisplayPort 故障注入 |
| 任務：兩個編譯設定與交付 | 4/4 | Orbit 正常展示設定、Station 明示診斷設定；不重複把 driver 缺口當完成 |
| 任務：兩台 upload／冷啟動／實機重播 | 0/6 | 未連板、沒有影片，全數未驗 |
| 任務：實體 Next/Restart／移除 P1 | 0/3 | 無實體操作證據；Serial host 測試不計入 |
| 驗證：native 故障與時間測試 | 10/10 | 真正編譯執行 C++，包含負向／邊界，不只是搜尋字串 |
| 驗證：交叉編譯及 binary／來源對應 | 8/8 | 固定版本、六種 build、內嵌 identity 與打包核對 |
| 驗證：回歸／版面／文件 | 4/4 | root Node 測試、host 預覽檢視、連結與 diff |
| 驗證：兩台實拍與操作紀錄 | 0/3 | 沒有實機證據 |
| 審查交接 | 15/15 | 對應來源、接手查核、命令、範圍、限制、回復與待驗清單 |
| **合計** | **22＋26＋22＋15＝85** | 只達本輪送審門檻 |

Station LCD 未完成主要記於內容扣 3，實機未驗記於任務與驗證扣分；沒有把診斷版改稱可顯示版本。
工作包 03 的「兩台實機可展示」完成定義尚未達成。

## 04：85/100

| 類別／子項 | 得分 | 理由 |
| --- | ---: | --- |
| 內容：P0-A／P0-B 所有畫面 source | 12/12 | O0–O7、角色、倒數／進度、DEMO、N/R |
| 內容：五色／校正／靜態備援 | 7/7 | 可編譯模式、不同字級、安全區／方向標示 |
| 內容：binary／build log／版面／命令 | 6/6 | 可重建本機 artifacts 並隨 PR 交付，無偽造影片 |
| 任務：三幕與八幕語意／自動切換 | 12/12 | Scene 對照、專注／完成／成長等，host 與編譯路徑 |
| 任務：圓形資訊／可讀設計 | 6/6 | 中央安全區、主數字、短英文／固定時鐘與 DEMO；只給設計分 |
| 任務：core／輸入與降級 | 5/5 | Serial N/R、自動、重刷三幕、static 模式 |
| 任務：動畫 | 3/4 | 有增量環與角色／勾選；Boot 非平滑 alpha 淡入、Ready 無呼吸，扣 1 |
| 任務：板上五色／冷啟動／離線重播 | 0/4 | 無板上成功紀錄；host 模型不計 |
| 任務：板上手動／近拍／方向與影片 | 0/4 | 實機、觸控短長按、影片尚缺 |
| 驗證：native 正常與故障／計時 | 8/8 | 10 圈以上、8 幕任意 reset、Complete 完整停留等 |
| 驗證：各 Orbit 模式編譯／binary | 7/7 | 非只編譯 host；固定 SDK／driver 版本 |
| 驗證：軟體預覽／回歸／文件 | 4/4 | 同 Painter 輸出、人工檢視及 root 回歸 |
| 驗證：實機流暢／可讀／色序／記憶體／影片 | 0/6 | 全數未驗，沒有把 software preview 稱照片 |
| 審查交接 | 15/15 | 來源、操作、scope、回復、實機未驗、原廠設定與資源授權 |
| **合計** | **25＋26＋19＋15＝85** | 整包 P0-A／P0-B 實機驗收仍未完成 |

## 已做的驗證與待 CI

- `make -C firmware/nudge_competition_demo test`：C++17 警告視為錯誤，執行通過。
- `node --test test/*.js`：113/113 通過，包含執行 C++ 的新測試；不含未合併 #22 的 16 個規劃測試。
- `make -C firmware/nudge_competition_demo preview`：8 幕 SVG，另以本機 PNG 渲染人工檢視；字型近似。
- `pio run --project-dir firmware/nudge_competition_demo -e orbit_p0a -e orbit_demo -e orbit_static -e orbit_colors -e orbit_calibration -e station_demo`：六種全部成功；提交後再建置、核對乾淨 commit 的 binary。
- `python firmware/nudge_competition_demo/scripts/package_builds.py`：六個檔案／內嵌 identity 核對通過，Station 保留 diagnostic 標示。提交後再打包，不沿用 dirty build 當正式交付。
- 最新 PR head 的六個必要 CI（包含 Web 內的新 C++ native 編譯執行）必須全通過，run 連結寫進 PR；未通過不交接。

上傳 workflow 變更遭 GitHub 權限拒絕，已保留原 CI，沒有繞過權限修改設定。
ESP32 六種交叉編譯改以本機完整 log、binary、manifest 隨 PR 交付，不宣稱 CI 有交叉編譯。
本機交叉編譯仍有完整可重建證據，配分維持；六個必要遠端 check 仍必須全部通過。

本輪包含 #21 已查明的 iOS checksum 修復以維持嚴格 CI，建議先由 z1nnz 審查合併 #21。
base 維持 main，作者不合併、不啟用自動合併、不強推。尚未有第二位組員接手確認、
USB upload、實機畫面／影片或真人計時；見 [acceptance](acceptance.md) 與 [evidence](evidence.json)。
