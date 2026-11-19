# 13 準備驗證紀錄

- new-tests.txt：21 個新增案例，含實際 ZIP、安全解壓、不覆寫、舊包／混 binary／錯資料／假驗收／影片型別／版本與相同板號等拒絕情況。
- node-tests.txt：root 133／133。
- source-analyze.txt：dart analyze lib test，No issues found。
- flutter-tests.txt：201／201。
- cloud-tests.txt：120 passed、25 skipped；skip 不算 pass，CI emulator job 另檢整合。
- package-checks.txt：兩次同來源建置 byte 相同、真實解壓、獨立 evidence 預期 exit 2。
- draft-package-build.txt：發布前本輪 PR URL 尚未建立的初稿；最終包 URL／hash 以 preparation-evidence 與 PR 為準。

本機 Flutter 3.47.8／Dart 3.13.7，CI 固定 3.41.7。未提交本機 pub get 的 lock／analysis_options 差異，也未降低 CI／lint。
本輪不改 firmware；四份候選 image 的原 clean build／native log 來自固定 #26，隨包保存，沒有冒稱本輪 upload 或重新驗收兩台。
封包取固定 packaging source commit 的程式與七份模板／資料；後續 artifact／evidence commit 不改這些來源檔，才能保證不混版本。

真正本輪 PR 建立後會補到 VERSION／README／MANIFEST，再以相同來源重建、重驗、重評 85 後更新。最新 head 六個 CI 全成功才 Ready，作者不 merge。
公開 log 只遮操作員家目錄、去除行尾空白；本機 deliverables 保留原始 log。原 canonical 工作包保留版本供對照，可填模板用 evidence/templates，不沿用原巢狀 code fence。
沒有實物影片，不能測影片播放；README／STATUS／host fixture 不當作實物證據。工具只檢查檔案與所填紀錄，不提供硬體、影像真實性或簽章認證。
