# 30｜Orbit／Station 可直接分派的 Issue Backlog

## 使用方式

每個 ID 原則上是一個 PR；若超過約 3 個主要責任或無法在一份測試摘要說清楚，
再拆小。`Depends on` 未完成前可以研究／寫測試，但不可用假 Interface 合併 runtime。

## Epic A｜硬體身分與安全

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| HW-01 | Orbit identity/card/revision | — | 照片、官方 pin/power、serial identity |
| HW-02 | Station ESP32 + square display identity | — | driver/interface/resolution/logic/pin 已確認 |
| HW-03 | Station power/pin budget schematic | HW-02 | 無衝突、5V/3.3V/level shift/common GND |
| HW-04 | Purchased peripheral inventory | — | encoder/VEML/buzzer/LED/電源實物型號與狀態 |
| HW-05 | Measurement/recovery runbook | HW-01/02 | 萬用表、BOOT、flash、serial 可由組員重現 |

## Epic B｜Characterization 與 common core

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| CORE-01 | Lock current v1 lifecycle behavior | — | host tests 覆蓋合法／非法 transition |
| CORE-02 | Journal/power-loss characterization | CORE-01 | slot/corruption/lost ACK tests |
| CORE-03 | Extract portable core | CORE-01/02 | 無行為差異，無 Arduino include |
| CORE-04 | PresentationFrame Module | CORE-03 | phase/fault/capability mapping tests |
| CORE-05 | Hardware Interface definitions | CORE-03 | Orbit/Station 兩個真實 Adapter 使用 |
| CORE-06 | ControlLease Module | CORE-03 | acquire/expire/transfer/stale tests |

## Epic C｜Orbit bring-up

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| ORB-01 | USB/serial smoke | HW-01 | cold boot/reset/upload evidence |
| ORB-02 | GC9A01 display smoke | ORB-01 | colors/orientation/text ×10 |
| ORB-03 | Touch calibration | ORB-02 | center/edges/swipes ×100 |
| ORB-04 | RTC/wall-clock Adapter | ORB-01 | drift/restart；不影響 monotonic |
| ORB-05 | Orbit DisplayPort Adapter | CORE-04, ORB-02 | fake frame renders all states |
| ORB-06 | Orbit InputPort Adapter | CORE-05, ORB-03 | tap/long/swipe event tests |
| ORB-07 | Watch Face + Quick Focus | ORB-05/06 | 兩層導覽、5/15/25 流程 |
| ORB-08 | Active/Sync/Fault faces | ORB-07, CORE-03 | local/accepted/revoked 可辨 |
| ORB-09 | Character/Recovery | ORB-08 | canonical snapshot，reduced motion |
| ORB-10 | USB wearable enclosure | ORB-08 | 熱、腕帶、USB、維修、非防水標示 |
| ORB-11 | Battery feasibility | ORB-10, R3 gate | 保護/充電/熱/續航；獨立決策 |

## Epic D｜Station bring-up

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| STA-01 | USB/serial smoke | HW-02/03 | cold boot/reset/upload evidence |
| STA-02 | Square display smoke | STA-01 | colors/corners/rotation/text ×10 |
| STA-03 | I²C electrical/scanner | HW-03/04 | 0x10/0x34/0x36 + pull-up measure |
| STA-04 | Encoder Adapter | STA-03, CORE-05 | 500 detents、press/long/race |
| STA-05 | Ambient Adapter | STA-03 | dark/indoor/bright/filter/fallback |
| STA-06 | LED electrical + Adapter | HW-03/04 | level shifter、30m soak、missing |
| STA-07 | Buzzer Adapter | STA-03 | quiet/nonblocking/missing |
| STA-08 | Station DisplayPort Adapter | STA-02, CORE-04 | all presentation/fault states |
| STA-09 | Living Desk + Prepare | STA-04/08 | context selection/correlation wait |
| STA-10 | Active/Rest/Room Portal | STA-05/06/07/09 | local/accepted、room scope |
| STA-11 | Self-test/diagnostics | STA-03–10 | non-destructive capability matrix |
| STA-12 | Enclosure/power/soak | STA-10/11 | optics、導光、採光、2h/24h |

## Epic E｜Protocol、App 與 Cloud

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| DEV-01 | Protocol v2 device profile | CORE-03, HW-01/02 | v1/v2 parser + capability tests |
| DEV-02 | Firmware profile characteristic | DEV-01 | Orbit/Station correct read-only profile |
| APP-01 | My Devices multi-profile UI | DEV-01 | capability-driven cards/states |
| APP-02 | Exact context revision | DEV-02 | NVS readback, stale/oversize reject |
| APP-03 | Control lease coordinator | CORE-06, APP-01 | dual start race/transfer policy |
| APP-04 | Durable device outbox ACK | APP-02 | enqueue before exact-head ACK |
| CLD-01 | Assignment profile/capability validation | DEV-01 | wrong profile/user/room reject |
| CLD-02 | Lease authority/audit | CORE-06 | single controller、revision、expiry |
| CLD-03 | Verified wipe/transfer ADR | APP-04 | empty queue + receipt + lock lifecycle |

## Epic F｜內容與體驗

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| EXP-01 | Embedded semantic tokens | CORE-04 | Orbit/Station/LED/sound state map |
| EXP-02 | Character asset manifest/fallback | ORB-05, STA-08 | archive/missing/CJK/reduced motion |
| EXP-03 | Daily beat snapshot | APP-04 | accepted-only、idempotent celebration |
| EXP-04 | Weekly chapter/content review | EXP-02/03 | rules/source/privacy/locale |
| EXP-05 | Room Campfire on Station | STA-10 | opt-in/expiry/ack/no reward |
| EXP-06 | Family/group safe window | EXP-03 | Membership/consent/revoke tests |
| EXP-07 | Notification/quiet policy | APP-01 | safe payload、frequency、mute |

## Epic G｜E2E、可靠性與發布

| ID | Issue | Depends on | 驗收 |
| --- | --- | --- | --- |
| QA-01 | Orbit personal E2E | ORB-08, APP-04, CLD-01 | disconnect/lost ACK/single Receipt |
| QA-02 | Station room E2E | STA-10, APP-04, CLD-01 | exact room contribution/no fan-out |
| QA-03 | Dual-device conflict | APP-03, CLD-02 | one controller/read-only loser |
| QA-04 | Revoke/wipe/transfer | CLD-03 | nonempty queue lock/account change |
| QA-05 | Optional peripheral fault matrix | STA-11 | degraded vs fail-closed |
| QA-06 | Electrical/thermal soak | ORB-10, STA-12 | rail/temp/reset/log evidence |
| QA-07 | Accessibility/privacy matrix | EXP-01/07 | color/motion/sound/glance/roles |
| QA-08 | Rebuild-from-zero rehearsal | all release gates | new checkout → flash → pair → E2E |
| REL-01 | Acceptance manifest and binaries | QA-01–08 | commit/hash/BOM/log/known limits |

## 每個 Issue 的通用 Acceptance

- [ ] 從最新 main 建立小分支；只含本 Issue。
- [ ] 正常、缺席、錯誤、重試至少各一例。
- [ ] host/build/board/peripheral/device/production 證據層級正確。
- [ ] 不改 canonical reward/Membership/catalog/assignment authority。
- [ ] 無 token、個資、真實健康資料。
- [ ] 文件、測試、rollback/known issues 與操作證據。
- [ ] Required GitHub checks 綠燈並由 final reviewer 合併。

## 可立即開始

不需要知道方屏型號即可開始：HW-01、HW-04、CORE-01、CORE-02、文件化量測工具。

必須等待方屏 Gate 0：HW-03、STA-01 之後的所有 Station pin/driver/runtime Issue。

必須等待實機：任何 `device-verified`、BLE reconnect、電氣、熱與外殼 Issue。
