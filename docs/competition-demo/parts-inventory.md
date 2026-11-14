# Package 01｜既有零件盤點與開發限制

日期：2026-11-14（Asia/Taipei）。範圍：`DEMO-01`／`DEMO-02` 零件卡的文件部分，P0-A。
依據：[package 00](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/00-scope-reset.md)、
[package 01](https://github.com/z1nnz/graduation-project-nudge/blob/9ace911bf892dfb3a451acce7e2ecbeb41904f7d/docs/work-packages/01-demo-parts-and-constraints.md)。

## 零件卡與證據

- [Orbit 零件卡](orbit-parts.md)：Round Display 組件正反面、主控標籤與原廠插接方向。
- [Station 零件卡](station-parts.md)：Waveshare 17344 方屏、240×320、ST7789 系列、八訊號與線束。
- [17 張原始照片的 SHA-256 manifest](evidence/manifest.json)：2026-11-08 收到的既有原圖，2026-11-14 重新核對；未修改影像，不包含先前附件的私有路徑。

這份盤點完成文件整理，不代表完成 `DEMO-01` 的 USB 燒錄紀錄、`STA-01` 五色測試
或任一實機任務。使用者指定實機稍後驗收，沒有用照片或歷史 host tests 代替實機證據。

## 分級與可做的事

沿用 package 01 的 A／B／C／D：A 為型號明確且已成功；B 為型號明確但未成功；
C 為型號或接線不明；D 為仍需要焊接、電平轉換或額外工具的接法。
同一零件可有已確認的產品身分與未確認的連接，分別記錄；沒有項目標 A。

| 物件／路徑 | 等級 | 本次判定與後續 |
| --- | --- | --- |
| Orbit XIAO＋Round Display 組件 | B | 型號與插接外觀可辨識；依原廠方向確認後作獨立顯示測試；開關狀態與功能未驗證 |
| Station Waveshare 17344 螢幕 | B | 型號、driver 家族、解析度與介面已知；尚未顯示成功 |
| Station XIAO 主控照片 | B（型號） | 單獨拍攝的背面與圓屏組件上的主控照片可辨識系列；照片是否分屬兩塊獨立主控仍未確認，歸檔名稱不等於實物對應 |
| Station LCD→XIAO 實際接線 | C | 未取得成功接法；線束顏色與逐訊號對應不明，不產生猜測 GPIO 表 |
| USB 資料線／目標 serial port | C | Orbit 有歷史插線外觀，資料能力與成功燒錄未知；Station 來源規劃為電腦 USB，不等於驗證 |
| seesaw 旋鈕接入路徑 | C | 已有產品系列正反面；採購 SKU、現有線材對應與接法未閉合；屬 P1，P0-A 不接入 |
| SparkFun VEML7700 SEN-29211 接入路徑 | C | 包裝與模組可見；Qwiic 線材／主控轉接未確認；屬 P1 |
| SparkFun Qwiic Buzzer BOB-24474 接入路徑 | C | 型號已辨識；Qwiic 線材／主控轉接未確認；屬 P1 |
| 10-WS2813 Mini LED＋SN74AHCT125N 候選接法 | D | 有實物，既有構想尚需完整電平轉換接法；本 Demo 延後，不加購配件、不接入 P0-A |
| MB-102 麵包板與盒裝跳線 | C（連接） | 合照確認存在；沒有已成功配線紀錄，不用其存在推論線路已接通 |

## P0-A 後續只做最小顯示

1. Orbit 由預設負責人確認現有插接方向、開關與單一 USB port，保存第一次燒錄紀錄。
2. Station 先對照 LCD 本體標示、原廠介面與 XIAO pin map，確認現成接頭／已焊排針可用，
   再保存成功接法照片；此階段不接 LED、旋鈕、光感或蜂鳴器。
3. 各自先作五色畫面，再進 Home → Focus → Complete 的獨立自動展示。
   不等 P0-B 共用 core，不以 App、BLE、Cloud 或採購作前置。
4. 沒有成功實機證據前維持 B／C，不填 `device-verified`。

不需要補拍已可辨認的螢幕正反面，也不要求為此買電表、烙鐵、洞洞板、電池或外殼。
尚未確認的接法依原廠／店家資料補齊，不帶電改線、不硬插、不推定線色。

## 降級與交接

| 失敗元件 | 預定降級 |
| --- | --- |
| 觸控／按鍵／旋鈕 | 三幕自動輪播 |
| LED | 使用螢幕完成畫面 |
| 光感 | 固定亮度，不顯示未驗證 lux |
| 蜂鳴器 | 靜音 |
| BLE／手機／網路／帳號 | 本機固定 Demo 資料，標示 DEMO |

以上為後續韌體的要求，尚未宣稱 fallback 已實作或實測。
原圖雜湊、文件連結與分級已核對；沒有編譯、upload、冷啟動、影片或 binary。
本次不修改 runtime、GPIO、資料契約或採購清單。回復方式為 revert 本 PR。

## 本次重新核對

使用者維持「實機稍後驗收」，未補充第二塊主控及目前接線的文字確認。
[逐項自評](package01-self-review.md)為 **88/100，未達更新 PR 門檻**。
本次補正照片歸檔與實物數量的區別，補齊 22 個卡片欄位的結果表與重驗紀錄；
沒有把 C 級紀錄、欄位存在或既有 CI 全綠當成已確認硬體與實際接法。
