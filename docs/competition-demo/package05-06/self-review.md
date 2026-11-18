# 05／06 自評與扣分

沿用固定配分：內容 25、指標 35、驗證 25、審查交接 15。使用者提交門檻 85。
分數表示這輪軟體可送審，**不表示完整硬體工作包通過**。實機稍後驗收的項目維持 0 分／未驗。

## 05：87/100

| 類別／子項 | 得分 | 核對 |
| --- | ---: | --- |
| 內容：身分與設定 | 6/6 | PCB／原圖／來源已知與未知分開，沒有假 GPIO |
| 內容：八幕／三幕實作 | 12/12 | 真實 ST7789 adapter、StationPainter、共用 core、task selection |
| 內容：建置／圖證／操作交付 | 7/7 | 11 種環境、source／binary／log／hash、軟體預覽與命令；不以預覽替影片 |
| 指標：driver 與 profile 防護 | 7/7 | 240×320、相異外露 GPIO、直向、未確認前拒絕 SPI／GPIO |
| 指標：P0-A 與場景控制 | 6/6 | 三幕 5/20/5、八幕 ID、restart／auto、晚到 tick 與回捲 |
| 指標：八幕內容與自主性 | 8/8 | 任務、支持／自己開始結束、結果／摘要、DEMO；中文用短英文 |
| 指標：五色／格線／版面 | 4/4 | 模式、8/12px 邊界、字級、native bounds、局部更新 |
| 指標：板上冷啟動／重播／操作 | 0/6 | 未 upload，無真實 3 次／3 圈／10 圈／10 次 |
| 指標：原廠現成 XIAO 範例／成功照片 | 0/2 | 目前為型號相符的 Adafruit 移植，無原廠現成 XIAO 例與成功接法照片 |
| 指標：獨立主控／實接事實 | 0/2 | 尚無持板者確認，不將 profile 範本當實物 |
| 驗證：native 行為／邊界／故障 | 10/10 | 真正執行 C++，非只比對文字 |
| 驗證：ESP32 交叉編譯／回歸 | 9/9 | 11 種設定與 root 113 項測試；正式 source 提交後再重建 |
| 驗證：版面／文件／雜湊 | 3/3 | 共用 Painter SVG 檢視、links／fences、binary identity／SHA-256 |
| 驗證：真實近拍／可讀／時序 | 0/3 | 全部未驗 |
| 審查交接 | 15/15 | 來源、查重、依賴順序、明確未完成、旗標、命令與 rollback |
| **總計** | **25＋25＋22＋15＝87** | 達本輪門檻，沒有關閉完整實機驗收 |

## 06：86/100

| 類別／子項 | 得分 | 核對 |
| --- | ---: | --- |
| 內容：五種 Adapter | 10/10 | GPIO button、seesaw encoder、NeoPixel、VEML7700、Qwiic Buzzer |
| 內容：Demo 模型 | 8/8 | debounce／長按、encoder 邊界、LED、三段光感、短音／靜音 |
| 內容：flag／矩陣／來源／決定 | 6/7 | 全停用與五種矩陣、原廠來源；未交 CHSC 觸控專用 driver，扣 1 |
| 指標：P0-A 與啟用門檻 | 7/7 | 兩台實機 P0-A 前不啟用，begin 前五項 gate；未偷改 accepted 值 |
| 指標：按鍵／旋鈕 | 6/6 | 40ms、1.2s、持鍵開機不誤觸、三任務／開始／Next／Restart |
| 指標：三種效果 | 6/6 | LED 限亮／2s、光感每秒平滑／遲滯／55 fallback、非阻塞低音量短音與 M |
| 指標：失敗隔離 | 6/6 | begin/update false 只停該模組，不重試、不影響自動與畫面；未買工具 |
| 指標：五種實機矩陣／影片 | 0/8 | 存在／拔除／異常／冷啟動／重播全部未驗 |
| 指標：真實觸控／既有按鍵對應 | 0/2 | 只有未配置 GPIO adapter 與已知 seesaw 系列；沒有實體成功或 CHSC 操作 |
| 驗證：兩裝置 driver 交叉編譯 | 10/10 | station_p1_check／orbit_p1_check 包含真 library；預設不初始化 |
| 驗證：模型／故障／門檻 | 7/7 | 逐模組失敗、異常資料、計時邊界、預設 gate 不呼叫 begin |
| 驗證：回歸／圖證／版本與 hash | 5/5 | root 113、source tree 與 binary 一致；文件與預覽 |
| 驗證：真實效果／拔除／聲光影片 | 0/3 | 未以 host 或編譯當實機 |
| 審查交接 | 15/15 | 型號／flag／決定／前置／取捨／回復與待驗 |
| **總計** | **24＋25＋22＋15＝86** | 僅 P1 軟體準備可送審 |

## 驗證紀錄與提交規則

- native：原有 core 測試與新增 Station／P1 測試兩個執行檔通過；root Node 仍 113 項，因沿用同一個測試入口。
- Station 每幕不同內容、DEMO、框線／字形在實際 viewport 內、task selection、Focus 不清整幕、支持自主性皆有測試。
- 按鍵 bounce／持鍵啟動／長按一次／回捲、旋鈕回捲／跳值、光感取樣與異常／遲滯、LED 2s、蜂鳴器不重播與靜音有測試。
- 五個 OptionalPeripheral slot 逐一初始化失敗，其他 slot 仍執行；update 失敗只停用一次；自動場景繼續。
- 第一輪 p1_check 因 Wire.beginTransmission 的 unsigned overload 失敗，已明確改為 uint8_t 並重跑 11/11 成功，沒有繞過編譯。
- 初次 native 測試的 rollover 預期值算錯，已修正到真正 1200ms 邊界並驗證 1199ms 不觸發、1200ms 才觸發。
- 人工檢視 Station SVG，修正 Focus 預覽字與角色線條重疊、任務選取的 bitmap 背景差異；SVG 不是實機截圖。
- source 提交後才建置正式 binary，再附 evidence；核對 clean、project Git tree、build id、11 個 SHA-256 與本機路徑掃描。
- 六個既有遠端 CI 都必須對最新 PR head 通過才交接。沒有改 workflow，也不宣稱遠端有 ESP32 交叉編譯。
- 若任何驗證失敗或重新評估低於 85，先修正、重測、重評，再更新 PR；最新 CI 全綠後才轉 ready 並請 z1nnz 審查。

沒有 USB 板、實際接線、第二主控對應、五色／冷啟動／影片或實際可讀距離證據；全部保留未驗。
不關閉完整工作包、不啟用 P1、不自行合併。完整核對見 [05](package05-acceptance.md)、[06](package06-acceptance.md)。
