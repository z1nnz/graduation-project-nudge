# 建置與紀錄驗證證據

## Gate A

[gate-a/gate-a.json](gate-a/gate-a.json) 保存完整 c4cb9fa source commit、韌體 tree、四個 environment 的 application binary／SHA-256／profile hash／embedded build id，以及七份命令 log 的 hash。
來源是未合併 #25 的固定 checkout，沒有把該韌體程式複製進本分支。
四檔均 clean build；Station 檔名 unconfigured，P1／BLE 未啟用，全部 physical_verified=false。
host-probe-run.txt 的 10／10／80 是 host 邏輯次數，不能填實機紀錄。
host executable 執行後刪除，只交付程式來源、log 與 ESP32 application image。

本機預覽／SUCCESS 不表示實物通過；application image 不可單獨寫到 0x0，稍後應由持板者依已審來源使用 PlatformIO upload。
沒有 local hardware profile；預設 profile hash 是 hardware_profile.h 與 hardware_profile.cpp 連接後的 SHA-256，不是已確認接線證據。

## 本輪準備驗證

- acceptance-tests.txt：20 個新增測試。
- node-tests.txt：root 132／132。
- source-analyze.txt：dart analyze lib test 無問題。
- flutter-tests.txt：201／201；既有負向測試會記錄未初始化 Firebase 的訊息，整體結果依測試結尾。
- cloud-tests.txt：120 通過、25 skipped；skipped 不是通過，CI emulator job 另外驗證。
- probe-gcc-syntax.txt：ESP32 GCC 8.4.0 對 probe 的嚴格語法檢查；實際 host probe 執行見 Gate A log。
- preparation-checks.txt：link／hash／Gate 分離與預期 exit 2 核對。

本機 Flutter 3.47.8／Dart 3.13.7；CI 固定 Flutter 3.41.7。最終六項 CI 的 run／head／結果寫在 PR 本文，不為記錄 CI 反覆改 commit 觸發新 run。
公開 log 保留輸出，只遮操作員家目錄／source checkout／output 的絕對路徑，去除行尾空白；本機 deliverables 留原始測試 log 與首次 probe 失敗紀錄。
沒有照片／影片／觀眾真回饋；目前 physical-status.json 只有 Gate A 為 true，其餘實測未通過或未採用。
