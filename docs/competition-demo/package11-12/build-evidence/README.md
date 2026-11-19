# 準備成果驗證

## 本輪執行

| 紀錄 | 實際結果 |
| --- | --- |
| operations-tests.txt | 新增 22／22，涵蓋認領 gate、查重、版本／影片／線材、到場表、離線包竄改 |
| node-tests.txt | root 134／134，無略過 |
| source-analyze.txt | dart analyze lib test，No issues found |
| flutter-tests.txt | Flutter 201／201 |
| cloud-tests.txt | 120 passed、25 skipped；skipped 不是通過，CI emulator job 另檢整合 |
| kit-build.txt | 兩個不同輸出目錄重建，ZIP bytes／hash 一致；實際 34 Issue 與目前工具版本 |
| pdf-build.txt | 四頁可列印 PDF 的產出 SHA-256，另有 pdf-qa.json 與逐頁 PNG 目視檢查 |

本機 Flutter 3.47.8／Dart 3.13.7；CI 固定 Flutter 3.41.7 的完整 analyze／test、Kotlin、iOS lock、Node、Cloud、Firestore 六項才是最新 head 送審門檻。
沒有提交 pub get 的 pubspec.lock／analysis_options 自動差異；沒有改 workflow 或放寬 CI。
公開 log 只遮操作員家目錄、去行尾空白；本機 deliverables 留原始 log 與預備版本。

## 來源與候選 binary

本輪沒有改 firmware 或重新做實機驗收。ZIP 透過固定 Git object 收入 #25 c4cb9fa 的 source 與 #26 3a55966 的 Gate A 四檔，並核對 source tree、binary SHA 與 embedded id。
Gate A 的原 clean-build／native log 隨包保存，不能冒稱本輪又燒錄兩台。
Station 名稱含 unconfigured；source／version／hash 都不能替代真正接線與實物影片。
候選 image 是 application image，不可單獨寫到 0x0；配置工具鏈與燒錄分區仍由已驗來源的 PlatformIO upload 處理，這輪沒有執行。

## PDF

Noto Sans TC 原字型由 Google Fonts 官方目錄取得，Git blob 與 SHA 檢查，SIL OFL 全文保存。只在 PDF 內嵌使用字型子集，不散布 12MB 原字型檔。
renderer 使用 ReportLab、fontTools 4.68.0 的 Regular instance；四頁 A4 已逐頁看過 PNG，未見缺字、裁切或重疊，pypdf 重開亦確認四頁與嵌入字型。
若重生：提供 source.json 記錄相同字型後，以 scripts/render_demo_field_card.py --content field-card.json --font 字型檔 --out PDF；須重新 render／目視檢查。

## 紀錄含義

Issue registry／publication audit 是發布時快照，往後狀態以 GitHub 為準。預設角色不是對方已認領；34 項發布不等於完成硬體工作。
readiness 的輸入仍全未驗，正常 exit 2；即使日後資料完整，工具仍只給人工核對，不驗證影片真實內容／簽章，不自動指派、關閉 Issue、發布韌體或合併 PR。
