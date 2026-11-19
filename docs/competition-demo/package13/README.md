# 13：交付與證據準備

2026-11-19。來源：[新版工作包 13](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/13-delivery-evidence-template.md)。
使用者要求先查重、自評至少 85 才上傳、六項最新 head CI 全綠後請 z1nnz 審查；實機稍後驗收。

**交付準備不等於實物發布：沒有 upload、實機影片、已驗 Station pinmap 或另一台電腦燒錄結果。**
候選 image 仍 physical_verified=false，P1／BLE OFF。這輪不新建或關閉 Issue、不替組員認領、不代發訊息。

## 查重與本輪新增

查 27 PR、28 分支、61 個 Issue／PR 紀錄及 #61 留言；沒有新版 13 的專屬成果。34 個硬體 Issue 均尚未實物驗收。
#61 已有操作卡與離線準備包，但不含完整 13 結構、新版全套工作包、單機交接卡與獨立證據模板。本輪補齊交付層，不重做韌體／操作稿。
不能排除他人未推送工作；查重為當時快照。Refs #56（binary／build id 保存）、#37／#45／#54／#55 的實物條件仍待補，不因本 PR 而關閉。

## 交付入口

- [完整交付 ZIP](../../../output/delivery/Nudge-Competition-Demo-preparation-2026-11-19.zip)／[SHA-256](../../../output/delivery/Nudge-Competition-Demo-preparation-2026-11-19.zip.sha256)
- [PR 模板](templates/pr-template.md)／[單機交接模板](templates/device-handoff-template.md)
- [影片／版本規則](templates/evidence-instructions.md)／[未代發的組員訊息](templates/team-message-draft.txt)
- [唯一 Demo 資料](demo-data.json)／[版本鎖定](source-lock.json)／[逐項自評](self-review.md)

ZIP 頂層是 Nudge-Competition-Demo，依 13 保存 README、work-packages、firmware-source、分裝置 binaries、三個 evidence 區、scripts 與 VERSION.txt。
work-packages 是固定 9ace911 的 00-13 加索引，不含舊 32 包；canonical 原文供對照，可直接填的模板在 evidence/templates，已修正原文件範例的巢狀 code fence 排版。

每台都有預填已知來源的 HANDOFF.md 與獨立待驗記錄；硬體／日期／影片仍未填。Demo 資料只用一份，並與固定 firmware 的 DemoData 逐值核對，避免 Orbit／Station 分數不一致。
小樹、小芽、82 分、3/5、+10 XP、50 分鐘皆固定示意，不是即時真人／健康資料，不發正式獎勵。

## 重建與核對

需原 repo 具備 source-lock 的固定 Git objects 與 packaging source commit；未合併來源不可當成 main。以 ZIP MANIFEST 記錄的 packaging_source_commit 重建，不用模糊 HEAD。

```sh
python3 scripts/prepare_competition_delivery.py build --git-source . --source-commit <完整packaging-source-SHA> --out <新的zip路徑> --delivery-pr <真正PR網址>
python3 scripts/prepare_competition_delivery.py verify output/delivery/Nudge-Competition-Demo-preparation-2026-11-19.zip
python3 scripts/prepare_competition_delivery.py extract output/delivery/Nudge-Competition-Demo-preparation-2026-11-19.zip --out <不存在的新資料夾>
```

Created at 採 packaging source commit 的時間以利重現，非實機驗收日。每個固定來源有 commit／Git blob／SHA；最終包補上真正本輪 PR，來源與候選 image 同時可追溯。
verify／extract 只表示結構與 hash 正常，不認證影片、簽章或硬體。解壓目的資料夾若已存在，工具拒絕覆寫。
封包沒有 `.env`、Token、service account、App 帳號／健康資料或大型 cache；公開新版工作包的原組員聯絡規劃保留作版本對照，沒有新增私人資料。

解壓後用既有 Python 3 也可獨立執行 scripts/prepare_competition_delivery.py verify。標準函式庫不需網路；閱讀既有 PDF 的內嵌字型不需下載。
PlatformIO toolchain／library cache 與新電腦離線安裝器未附，不宣稱另一台電腦可直接燒錄。application image 不可單獨寫到 0x0；Station 未確認接線前不 upload。

## 真實證據稍後補

在解壓出的根資料夾，複製 evidence/delivery-record.pending.json 另存填寫；目前正常 exit 2：

```sh
python3 scripts/prepare_competition_delivery.py evidence evidence/delivery-record.pending.json --root .
```

每份原始影片需連續看見實體 XIAO／螢幕、Boot、Home→Focus→Complete 與完成；宣稱 P0-B／P1 時還需 Restart，P1 時拍操作手部。
工具核對 Scene 順序、版本、binary／media 檔案 hash／相對路徑與所填紀錄，不辨識影片真假。minimum_device_records_complete 與全包影片分開，hardware_certified 永遠 false，由 z1nnz 看原始證據裁定。
終端 SUCCESS／模擬器／單張預覽不是實物影片。沒有影片時，STATUS.md 只表示缺項，絕不算離線播放通過。
P0-B／P1 的詳細重播、Restart 與排練仍依 package 10（#26），本工具不替代完整實物驗收。

## 分支與限制

本輪從最新 main c37c6ab 建立獨立分支，僅沿用 #21 的已知 iOS checksum metadata 修復，保持嚴格 CI；未帶入 #25／#26／#61 整包歷史。
固定來源只是讀取參考：#25 firmware c4cb9fa、#26 Gate A 3a55966、#61 操作稿 e3bd9e5。來源未合併由 z1nnz 裁決，不自行合併。
實機、近拍／完整影片、照片、另一位確認、手機／第二台電腦播放與燒錄皆未驗。自評只評本輪準備，不可把 85 分當實物通過率。
