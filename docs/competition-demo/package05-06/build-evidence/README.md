# 建置證據：未進行實機驗收

- manifest.json 記錄乾淨 source commit、韌體 project Git tree、內嵌 build id、11 個 SHA-256。
- 後續 evidence commit 不修改該 project tree；可與 PR head 比對。
- 11 種 ESP32 environment 皆成功。Station 檔名含 unconfigured，沒有已確認接線，不會操作 LCD GPIO。
- 兩個 p1_check 包含實際周邊 library，但所有 P1 接受條件與旗標預設 false，不能拿來宣稱模組成功。
- build-output.txt 是完整編譯結果，只遮去操作者路徑及正規化行尾空白。其他兩檔為 native 與 root 113 項測試結果。
- 每個檔案皆 physical_verified=false；沒有 upload／近拍／冷啟動或模組拔除證據。
- binary 是 application image，不能單獨寫入 0x0。稍後先核對硬體 profile 與 USB port，再以 PlatformIO upload。
- 來源、設定、原廠與操作命令見[韌體說明](../../../../firmware/nudge_competition_demo/README.md)。
- 公開打包器拒絕本機硬體 override，避免把不同接線設定混入預設交付；本輪未提供接線推薦。
