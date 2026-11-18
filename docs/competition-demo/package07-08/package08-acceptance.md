# 08 角色與視覺驗收

## 指標與證據

| 新版工作包指標 | 本輪結果 | 待補 |
| --- | --- | --- |
| Orbit／Station 主色、角色、完成色一致 | 共用 JSON 生成 RGB565／Flutter Color；兩個 Painter 同用 CharacterPainter | 兩塊真螢幕並排比色 |
| 同 Scene、同意義、不同版面 | 八幕 SVG 由兩個正式 Painter 產生；Station 保留直式文字與進度，Orbit 保留圓屏中心布局 | 真屏裁切／實際中文字型不在此聲明 |
| 六角色對應行為 | Home=idle、Ready=ready、Focus=focus、Encouragement=support、Complete=complete、Growth=growth；Boot／Summary=idle | 已有 source／host 渲染；板上待驗 |
| 30–80cm 可讀 | 已檢視軟體圖，主標／倒數不與角色重疊，Focus 角色縮小 | **未測距，未通過實機指標** |
| 固定資料標 DEMO | 兩台各幕及 App 示意固定值保留 DEMO；不發正式 XP | 真屏標記可讀待驗 |
| 動畫可關閉、仍完整展示 | orbit_static／station_static 編譯；300ms 一階、900ms 收束，Focus 靜止，無 delay／整屏快閃 | 實際幀率與眼睛舒適度待驗 |
| 圖像來源／授權 | 本輪原創幾何六姿態，共用 source 與生成器入版控；來源見下 | 無第三方圖片待清權 |

## 唯一視覺資料與文案

`shared/demo_contract.json` 定義 64×64 幾何 mark、六姿態、Scene 對應與八 token；
生成 C++／Dart／Kotlin，`node scripts/generate_demo_contract.cjs --check` 防止三端手動分歧。
不是兩套看似相似而各自維護的素材。

| Token | sRGB | 語意 |
| --- | --- | --- |
| Background | #081018 | 安靜背景 |
| Primary | #8B69FF | Nudge／Focus |
| Ready | #BDAAFF | 自主準備 |
| Paused | #F0B356 | 暫停、非失敗 |
| Complete | #5AD2BD | 完成 |
| Support | #4AD2EF | 支持 |
| Text | #F7F7EF | 主文字 |
| Muted | #6B7D94 | 次要標籤 |

韌體字型沿用 ASCII `READY`／`FOCUS`／`KEEP GOING`／`DONE`／`GROW`，避免未驗證中文字型。
中文展示解說：準備好了嗎？／你自己決定何時開始／慢慢來，也是在前進／完成 25 分鐘／今天已前進 2 次／家人傳來一句鼓勵。
固定家庭訊息、分數、群組人數、成長能量都是 DEMO，不連真帳號、不發正式貨幣。
沒有監看、落後懲罰或強制開始文案；本輪只更新獨立原型頁，沒有重做正式 App。

## 動畫與來源紀錄

角色只在 scene 改變時做一次 900ms 的小幅位移，300ms 一階，幅度 1 pixel；Focus 全程靜止。
CharacterPainter 快取 pose／phase，只清角色區域。Next／Restart 與自動 tick 維持非阻塞。
Complete 900ms 小於 2 秒；靜態環境禁用動畫後同樣走八幕。
App 角色預覽採靜態，六姿態仍相同，不用動畫掩蓋 BLE 狀態。

原創資產：本輪新增的 circle／line 幾何、葉片、眼睛、嘴型與六姿態資料由本專案此次實作產生，原始可編輯 JSON 入版控；沒有下載／描摹第三方插畫。
衍生產物是 generated_contract.h、generated_demo_contract.dart、DemoBleSpec.kt 與本目錄軟體預覽。
專案目前沒有總體 LICENSE；這是來源聲明，不替維護者授予額外的公開再授權。
Seeed／Adafruit 等依賴仍遵守各上游庫既有授權，版本鎖定同韌體 README；沒有複製其圖像。
App PNG 的文字使用本機 Flutter SDK 內 Roboto 做測試渲染，不散布字型檔。SVG 字型近似，非實物照片。

## 待實機驗收

- [ ] 同一照明下，兩台並排記錄八 token 與角色完成色。
- [ ] 30／50／80cm 看主標、倒數、DEMO，記錄手機／螢幕／亮度與可讀結果。
- [ ] 六姿態、八幕逐一拍照；固定資料不被誤認成真人資料。
- [ ] 動畫開／關各完整重播，Focus 不干擾，Next／Restart 不等待動畫。

目前實機全部未勾選；軟體圖不代替照片、錄影或觀看距離結果。
