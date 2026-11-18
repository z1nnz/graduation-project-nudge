# 軟體建置證據，非實機驗收

本目錄 14 個 application binary 由乾淨 source commit `0b50e2d` 建置，精確 commit／firmware tree／build id／每檔 SHA-256 見 manifest.json。
後續提交僅增加 docs 證據，韌體 tree 必須與 manifest 相同。
打包器確認每一檔含同一 build id；不得拿別輪已成功的 binary 代替本輪。

全部 physical_verified=false、P1／Demo BLE armed=false；BLE check 只編譯 SDK／adapter，沒有啟動服務。
Station 檔名含 unconfigured，尚未確認第二塊主控與 LCD GPIO，不會操作未知接線。
應用映像不能單獨寫入 0x0；實機稍後驗收，應由持板者依韌體 README 用 PlatformIO upload 處理分區與 bootloader。

| 證據 | 命令／內容 |
| --- | --- |
| firmware-build.txt | PlatformIO 逐一指定 platformio.ini 的全部 14 個 env；14 succeeded |
| native-tests.txt | make -C firmware/nudge_competition_demo test；三執行檔 PASS |
| node-tests.txt | node --test test/*.js；115／115 |
| flutter-tests.txt | flutter test --no-pub；213／213 |
| source-analyze.txt | dart analyze lib test；No issues found |
| controller-visual-tests.txt | 12 個控制頁測試並匯出六姿態 PNG，NUDGE_EXPORT_DEMO_VISUALS=true |
| standalone-web-build.txt | flutter build web --no-pub --target lib/main_demo_controller.dart；成功 |

本機 Flutter 3.47.8／Dart 3.13.7、PlatformIO 環境 espressif32 6.12.0；CI 固定 Flutter 3.41.7，完整 analyze／test／Android Kotlin compile 以最新 PR head CI 為準。
本機分析用 source-only 命令避開 Unicode LSP 故障與 build 內上游快取；沒有修改 repository 分析範圍或 workflow。
未提供 Android APK／iOS BLE 成功聲明。Web 瀏覽器只驗證畫面；12 個測試內的 BLE 是 fake transport。

公開 log 保留完整輸出，只將操作員家目錄替成 `<operator-home>` 並去除行尾空白；原始 log 保留在本機 deliverables。
所有本輪測試／建置均通過，未把失敗行刪掉或把實機未測改成成功。
