# 13 逐項驗收與自評

標準：內容 25、任務指標 35、驗證 25、交接 15；先達 85 才上傳。實機按使用者指示稍後驗收。
本輪評交付準備，完整實物／影片未完成，不能以分數宣稱硬體通過。

| 新版指標 | 本輪準備 | 實物狀態 |
| --- | --- | --- |
| PR 模板所有段落／驗證七項 | 工作包、目標、實作、沒做、硬體、命令、證據、Demo truth、限制齊備；code fence 可用 | 沒有假勾 upload／冷啟動 |
| 最低實物影片 | 逐台原始連續影片、XIAO／螢幕、Boot、順序三幕、完成、互動與 Restart 條件；型別／hash 檢查 | 全未拍 |
| 單機交接卡全部欄位 | 每台獨立 card／record，預填固定來源、env、binary／hash、操作與限制 | 型號／接法、最後實測日、影片未驗 |
| 共用 Demo 資料 | 單一 JSON／表，逐值比對固定 C++ DemoData，包括小樹、小芽、82、3/5、+10、50 分鐘 | 不宣稱實物已顯示／Cloud 即時 |
| 指定發布包結構 | 單頂層 Nudge-Competition-Demo；README／新版工作包／source／雙 binary 目錄／三 evidence 區／scripts／VERSION | 仍是 preparation-only |
| VERSION 每一欄 | Package、Created at、repository、firmware／packaging commit、兩 env、兩 verified=false、BLE=false、limitations | 沒有已驗收版 |
| 壓縮驗收 | 可核對與安全解壓、README 首頁競賽 Demo、白名單、無 cache／憑證、4 候選檔明確分開、新版 00-13、PR／SHA 可追溯 | 真影片離線播放未驗 |
| 給組員訊息 | 新版取代舊 32、最低雙機三幕、不採購、P2 選配、先讀 00／09／11 | 只有草稿，未代發／未確認認領 |

## 自評：85／100（已完成準備驗證）

| 項目 | 分數 | 依據與扣分 |
| --- | ---: | --- |
| 內容 | 25／25 | 完整模板、交接、固定資料、版本與壓縮結構 |
| 任務指標 | 25／35 | 未取得實物／手部／Boot／三幕／Restart／照片等真實證據整組扣 10 |
| 驗證 | 20／25 | 程式、來源、hash、解壓、資料一致與拒絕偽通過；真影片離線播放、另一電腦／手機及實際 upload 缺失扣 5 |
| 交接 | 15／15 | 每台卡、來源 PR／commit、可用模板、缺項與重建方法完整 |
| 合計 | **85／100（準備範圍）** | 不是整包實物完成度 |

只有在程式測試、可解壓、資料與來源核對完成後，才將本評分用作提交門檻。具體測試、archive hash、source commit 與遠端查重保存 preparation-evidence／build-evidence。
本機 SDK 3.47.8，CI 固定 3.41.7；未改 App／Cloud／driver／workflow，不能因文件／打包工作省略六項 CI。
最新 head 六 CI 全綠前保持 draft，成功後只請 z1nnz 審查，不自行合併；不關閉缺影片的既有 Issue。

已實際完成兩次同 source 重建 byte 一致、安全解壓與獨立 evidence exit 2；新增 21／21、Node 133／133、Flutter 201／201、來源分析無問題。Cloud 120 通過／25 emulator cases skipped，未把 skipped 算通過。自評維持 85，先達門檻再發布。最終包將補上真正本輪 PR URL，重建／重驗後再交 CI；版控此表為上傳前快照。

已建立 PR #62，並把實際網址填入最終 README／VERSION／MANIFEST；同一 producer source 重建 byte 一致，安全解壓與獨立 evidence exit 2 重新通過。更新前重評仍為 85，來源檔未變，Node 133／133 與新增 21／21 再驗通過。此更新不含新韌體行為，實物條件仍未完成。
