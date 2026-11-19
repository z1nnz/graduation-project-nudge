# Nudge 競賽 Demo 交付準備包

**PREPARATION ONLY - 這不是已驗收韌體發布。兩台實機與影片均待驗，Station 獨立主控／接線未確認，P1／BLE OFF。**

本包完全採新版 Competition Demo v1（00-13），不含舊 32 份工作包。先讀 work-packages/README.md、00、09、11。
唯一最低目標是兩台各自穩定顯示 Home→Focus→Complete；App／BLE／Cloud 不是前置，不新增採購。

## 開始閱讀

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
