# 實物證據（目前沒有影片）

每台原始連續影片需同時看見實體 XIAO／螢幕、開機、Home、Focus、Complete 與完成畫面。
若宣稱 P0-B／P1，另拍 Restart；有實體輸入時，鏡頭要看見操作者按鍵／旋鈕動作。
不能用模擬器、電腦截圖或終端 SUCCESS 代替。沒有影片就留 null／空清單，不建立假的 mp4。

每份 media 填角色（closeup／full）、相對檔名、SHA-256、kind=physical_video、連續影片、時長、日期、操作者代號、可見內容與實際 Scene。
同一長片可以兼有近拍與全程角色，但必須由人看過，不能只改 JSON 旗標。
P0-A 至少 Home→Focus→Complete；P0-B 八幕與重播請同時保留 package 10 的完整紀錄。
兩台三分鐘一鏡到底放 full-demo，另記兩個 build id 與版本；不宣稱程式預覽是同硬體影片。

工具只檢查提交紀錄及檔案 hash／位置，不辨識影像內容、驗證簽章或替 z1nnz 做實物認證。
填完可用 evidence 命令檢查，exit 2 是尚未完整，exit 0 也只代表可送人工審查；hardware_certified 永遠 false。
所有真實結果目前未填，沒有備援影片，也沒有可宣稱的離線影片播放成功。
