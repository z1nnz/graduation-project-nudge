# Nudge 競賽 Demo 交付準備包

**PREPARATION ONLY - 這不是已驗收韌體發布。兩台實機與影片均待驗，Station 獨立主控／接線未確認，P1／BLE OFF。**

本包完全採新版 Competition Demo v1（00-13），不含舊 32 份工作包。先讀 work-packages/README.md、00、09、11。
唯一最低目標是兩台各自穩定顯示 Home→Focus→Complete；App／BLE／Cloud 不是前置，不新增採購。

## 開始閱讀

- evidence/audit00-13/README.md：本輪 00–13 總表、逐條來源與未達項目；source_prepared 表示準備，並非整包驗收。
- evidence/reference-deliveries/docs/competition-demo/：00 範圍／01 零件卡與 17 張既有照片／02 修正後腳本，保留原相對路徑；不是新實機成功證據。
- work-packages/：固定需求 9ace911 的 14 包與索引，保留原文供對照。
- evidence/templates/pr-template.md：可直接填的 PR 模板，已整理成有效 Markdown。
- evidence/templates/device-handoff-template.md：空白單機卡；evidence/orbit、station 有預填來源的待驗卡。
- evidence/demo-data.json／demo-data.md：兩台共用同一虛構固定資料。
- scripts/competition-script.md／runbook.md／field-card.pdf：前輪已核對的口白與紙本操作，仍未現場排練。
- firmware-source/：追溯來源與完整第一方韌體專案；不是 `.pio` 或工具鏈 cache。
- binaries/orbit_demo、station_demo：四個候選 application image，default 為各自 p0a；Station 檔名 unconfigured。
- evidence/*／evidence/full-demo：目前沒有實機影片，只有明確待填紀錄與原建置 log。
- VERSION.txt、MANIFEST.json、SHA256SUMS.txt：版本／來源／hash／缺項。

## 版本與 PR

Packaging source commit：{{PACKAGE_COMMIT}}
Created at：{{CREATED_AT}}
本輪 PR：{{PACKAGE_PR}}
韌體來源：PR #25，c4cb9fa；原 Gate A：PR #26，3a55966；操作稿：PR #61，e3bd9e5。
這些 PR 尚待合併；本包沒有假稱它們已進 main。

## 不可誤用候選檔

所有 candidate physical_verified=false，沒有已驗收 binary。Station 接線不明前不 upload。
application image 不可單獨寫到 0x0；稍後應以已確認來源／profile 與 PlatformIO upload 處理 bootloader／partitions。
本包只保存 PlatformIO pin／版本紀錄，不含 toolchain／library cache 或全新電腦離線安裝器；另台電腦燒錄未驗。
沒有真正影片，所以「影片可離線播放」尚未通過；README／status 檔不能當成影片。

## 離線檢查

在有 Python 3 的既有筆電上：

```sh
python3 scripts/prepare_competition_delivery.py verify /path/to/package.zip
python3 scripts/prepare_competition_delivery.py extract /path/to/package.zip --out /path/to/new-folder
python3 scripts/prepare_competition_delivery.py evidence evidence/delivery-record.pending.json --root .
```

verify 成功只表示結構／hash 可檢查，非硬體通過。evidence 目前正常 exit 2；0 也只是紀錄可送人工審核。
不依賴網路就能閱讀本包文字／PDF；既有上游 README 的歷史 PR 連結可能需要網路。字型授權與來源隨 scripts/font-license 保存。
寄組員訊息只有草稿，未代發；認領與真正實機裁定仍由組員及 z1nnz 完成，作者不自行合併。

## 總檢查

在本包根目錄執行：

    python3 scripts/audit_competition_packages.py --root evidence/audit00-13
    node evidence/reference-deliveries/scripts/validate_competition_demo_story.cjs

第一條只查來源對照與準備總表，CI 欄是檢查開始時的歷史快照，不能代表更新後 head 的 CI。最新版 CI 以 PR 頁為準。
第二條核對紙面八幕時長與 #25 固定 core.cpp；Ready 3 秒、Summary 8 秒、Home 起算 49 秒一圈。未量測真板 render／操作延遲。
原工作包 02 的 4 秒／6 秒是舊建議，已在本輪規劃修正；沒有變更 canonical 需求或韌體。歷史文件內連到未納入項目的相對路徑請用其來源 PR，不能據此推定已整合 main。
