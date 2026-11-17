# 05 逐項核對

本表區分軟體完成與實機稍後驗收，source／編譯不替代真實畫面。

| 工作包項目 | 本輪成果 | 待驗／未完成 |
| --- | --- | --- |
| 商品／PCB 身分 | 17344、240×320、ST7789 家族、SPI，固定原圖／官方連結 | 精確 V/VW 尾碼、第二塊獨立主控、實際線束對應 |
| STA-01 最小顯示 | ST7789 adapter、原廠型號資料、五色各 2s | 非原廠現成 XIAO 範例；尚未確認接線、upload 或顯示 |
| STA-02 格線／字型 | 8/12px 邊界、實際 rotation、8/16/32px 參考，短英文 | 50–80cm 可讀、中文、色序、rotation 實物方向 |
| STA-03 三幕 | Home 5／Focus 20／Complete 5s、離線無周邊依賴 | 冷啟動 3 次、10s 內 Home、板上 3 圈 |
| STA-04 八幕 | S0–S7 專用 Painter，進場清幕，Serial N | 真實殘影、破圖、記憶體與近拍 |
| STA-05 場景 core | 同 Orbit Scene ID；49s 自動一圈、任一幕 R 回 Boot | 板上 10 圈、Restart 10 次 |
| STA-06 互動 | 任務旋轉／開始；Serial N/R，seesaw 短按開始或 Next、長按 Reset；無旋鈕第一項 | 實體輸入、CHSC 觸控未接入；P1 gate 關閉 |
| STA-07 周邊 | 逐一可關閉／可失敗的 Adapter；參見 06 | 兩台實機 P0-A 前不啟用 |
| 不猜腳位 | 六個 LCD GPIO 都 -1；獨立主控／接線未確認時，在 SPI／GPIO 前拒絕初始化 | 實際 profile 等持板者核對 |
| 完整交付 | source、11 種編譯、binary／hash、log、操作與回復說明 | 沒有新實機影片／成功接法照片 |

## 八幕對照

| Scene | 內容 |
| --- | --- |
| S0 Boot | Nudge／Station、角色、右下短 build id |
| S1 Desk Home | NEXT／PROJECT、25 MIN FOCUS、角色／TODAY 2/3、DEMO |
| S2 Task Select | PROJECT、READ 25 MIN、WALK 3000，選取指示；無旋鈕自動第一項 |
| S3 Focus | 大型 20 秒展示倒數、任務、進度與角色；DEMO，不冒稱真 25 分鐘 |
| S4 Support | ROOM 3/5、鼓勵、YOU START / STOP；不顯示私人活動 |
| S5 Complete | FOCUS COMPLETE、25 MIN、完成角色與勾選 |
| S6 Growth | SPROUT LEVEL 7、新葉、DEMO XP+10；不發正式獎勵 |
| S7 Summary | 任務 2/3、50 MIN、Score82，8 秒回 Home |

資料都來自同一 DemoData。時間使用差值且可回捲；晚到 tick 不跳過 Complete。
可用 host 預覽及 native 測試確認所有字形框在 240×320／8px 安全邊內，不能當作實際可讀證據。
RGB565 buffer 約 153600 bytes heap；不足時退直接繪圖，實機速度／閃爍仍須觀察。
背光 PWM 可用時預設 55%；無 PWM 則回固定 ON 並記錄，不聲稱等同 55%。

## 稍後實機清單（全部未驗）

- [ ] 對應獨立 Station 主控、LCD／電源／現成接頭，保存成功接法照片與 profile 版本。
- [ ] 單機 USB upload、五色整屏、實際 rotation／invert、校正字型與 50–80cm 可讀。
- [ ] 三次冷啟動皆 10s 內 Home，關閉手機／網路，連續三幕 3 圈。
- [ ] 八幕自動 10 圈，Restart 10 次；沒有殘影、破圖、白屏或重啟。
- [ ] 不接 P1 仍可展示，保存近拍／完整影片、binary hash、source／profile id。

本輪沒有填任何實機通過，也沒有因 85 分提交門檻而關閉 05 的完整驗收。
