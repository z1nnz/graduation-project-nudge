# 28｜雙裝置隱私、安全、無障礙與倫理護欄

## 原則

Nudge 裝置服務使用者自己的自律，不成為家長、老師、團體管理者或旁人監控工具。
硬體多一個感測器、多一個通知或多一個分享功能，都要同時回答資料最小化、同意、
撤回、錯誤傷害和無障礙替代。

## 裝置可保存的最小資料

- device/profile/firmware/protocol version。
- assignment 的不可直接識別安全 reference。
- context revision、最多三個 safe room label/id、personal goal label。
- 角色 asset key/name/stage/level。
- quiet/brightness/preference。
- active session correlation、sequence、最多八筆未 ACK event。

## 不保存

- email、電話、密碼、Auth/App Check token、完整 UID。
- 精確家庭健康資料、child report、聊天全文、自由情緒文字。
- 完整 Activity Ledger、長期 sensor history、其他成員名單。
- credit/payment 或 staff credentials。

## 顯示隱私

### Orbit

- 腕上可被旁人看到，預設通知只顯示 icon/類型；內容需使用者開啟。
- 不顯示家庭關係稱謂、孩子健康、完整房間成員資訊。
- 提供 privacy glance mode：只顯示時間和角色。

### Station

- 桌上共用空間只顯示使用者本人安全摘要與 aggregate room state。
- 可設定 idle privacy screen；離開時不輪播任務全文或通知。
- diagnostics 不顯示 token、UID、完整 IDs。

## 家庭／團體護欄

- guardian/manager 無權遠端 start/pause/complete 他人裝置。
- 共同目標和分享需要接收者同意，可撤回。
- health category consent 不由家庭角色自動開啟。
- room resonance 固定 cue、24 小時過期、無精確數值、無 reward effect。
- removed/ended Membership 立即失去新 context/outcome visibility。

## 感測倫理

- VEML7700 只量環境光與調亮度。
- presence/IMU/temperature 未來若加入，狀態清楚可見、可關閉、用途限定。
- 不用感測器推論人格、情緒、疾病、工作效率或「是否偷懶」。
- 不把可能在席當成完成活動，不形成 reward evidence。
- 不加入隱藏麥克風／相機；若未來研究必須全新 consent/indicator/data policy。

## BLE 與 Cloud 安全

- BLE device ID/capability 不是 ownership proof；App 查 Cloud DeviceAssignment。
- 不信任 payload actor/role/room；App 依 occurrence-time scope 補齊。
- exact context/lease revision、stable event ID、queue-head ACK、Cloud idempotency。
- revoke 後 fail closed；cross-account transfer 需要 verified wipe receipt。
- protocol v1 沒有 device signature，不宣稱 cryptographic physical proof。

## 物理安全

### 共用

- 5V 不進 3.3V GPIO；LED 用 level shifter、獨立 5V rail、common ground。
- 上電前 continuity/short；不帶電熱插拔。
- 外殼無裸露導體、銳角、鬆線；USB/腕帶有應力釋放。

### Orbit

- 未完成 battery protection/thermal/charge/enclosure 不日常配戴。
- 不防水、不戴著充電；電池異常立即隔離。

### Station

- LED brightness/current hard cap；buzzer 音量上限。
- VEML 採光窗與 buzzer 聲孔不影響電氣隔離。

## 無障礙

- 所有狀態都有文字／形狀；LED 顏色不是唯一訊號。
- 高對比、大字、reduced motion、sound off、quiet、App fallback。
- Orbit touch target 避開圓邊；Station 旋鈕可完成核心流程。
- 觸控／旋鈕不可用時，App 可操作但仍遵守 assignment/lease。
- animation 不快速閃爍；錯誤不連續蜂鳴。
- 文案短、非羞辱、非醫療、可本地化；未知 glyph fallback。

## 心理安全與留存

- 不用 streak loss、倒數威脅、紅點轟炸或社交羞辱逼迫回來。
- recovery 提供縮小行動／換活動／休息，不扣回過去獎勵。
- 角色回應描述行動，不固定人格標籤。
- notification opt-in、quiet hours、頻率上限、可完全關閉。

## 威脅／濫用案例

- 旁人拿到裝置嘗試看通知。
- manager 指派裝置後控制 member。
- 舊帳號 queue 在 reassign 後送到新帳號。
- BLE spoof device ID、replay old event、wrong-head ACK。
- 調整手機時間增加 reward。
- 改 local asset/context 假裝高階角色。
- sensor stuck/covered 造成 presentation 異常。
- 維修人員取得 NVS image。

每項要有 prevention、detection、recovery、test 和 residual risk。

## Privacy lifecycle

- export 說明 device assignment、safe context、events/audits 的範圍。
- account deletion 建 PII-free transfer lock，不能藉刪帳號消除 wipe 要求。
- 裝置 local wipe 與 Cloud deletion 分開記錄；任一邊失敗不能假裝完成。
- logs/acceptance artifacts 去識別化，保存期限和刪除責任明確。

## 驗收

- 角色／surface 權限矩陣與負向測試。
- privacy screen、notification content、logout/login B cache isolation。
- color-blind/reduced motion/sound off/input fallback。
- physical short/thermal/brightness/sound checks。
- threat cases 的 emulator/real-device evidence。
