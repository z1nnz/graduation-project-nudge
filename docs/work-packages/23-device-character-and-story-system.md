# 23｜裝置角色、敘事、收藏與世界回應系統

## 目標

讓 Orbit 與 Station 不只是計時器，而是能反映正式行動與關係成果的夥伴。豐富度
來自「行動有因果、世界會改變、回來有新內容」，不是大量隨機動畫或另一套本機
XP。所有解鎖與成長仍來自 Cloud Reward/Outcome。

## 三層角色系統

### 個人角色

- 來源：正式 Activity Receipt、Reward Ledger、角色 catalog／series XP。
- 顯示：stage、level、姿態、最近一個 accepted milestone。
- 可出現於 Orbit、Station、App、PWA；裝置只收安全 snapshot。

### 家庭夥伴

- 來源：validated bond events、家庭樹與 deterministic memories。
- 顯示：共同樹的小變化、夥伴心情、最近一個雙方認可的回憶。
- 不把 child 精確健康、任務內容或 private recovery state傳到裝置。

### 團體夥伴

- 來源：active Membership、current challenge participation、member-owned summaries。
- 顯示：團體星球建設、共同路徑和非同步支持。
- 不把團體 XP 轉成個人 coin，不讓 manager 代填成長。

## 角色狀態語言

| Presentation state | 觸發 | Orbit | Station |
| --- | --- | --- | --- |
| sleep | idle/quiet | 低亮閉眼 | 暗場景 + LED off |
| ready | valid context | 小幅呼吸 | 角色 + 下一步 |
| prepare | correlation/lease | 外圈聚合 | 場景收斂、soft pulse |
| focus | active | 安靜凝視 | 低干擾姿態 + progress |
| pause | paused | 等待表情 | 靜態 paused 色 |
| waiting | local saved | sync 小包裹 | 角色搬運紀錄動畫 |
| celebrate | Cloud accepted | 一次短反應 | 角色 + LED/音效一次 |
| recovery | recent gap | 溫和邀請 | 小步驟卡片 |
| fault-safe | critical fault | 短代碼 | 診斷入口 |

重要動畫只在 state transition 播放一次；重開畫面不重播 accepted celebration。

## 故事結構

### Daily beat

一筆 accepted action 產生一個很小的世界回應，例如光點、葉片、足跡或角色一句
話。它不一定每次解鎖物品，避免養成通膨。

### Weekly chapter

根據最近 discipline days 的 activity mix 生成固定規則 chapter：開始、持續、恢復、
同行。只描述行動，不稱人格或能力高低。

### Milestone memory

個人：角色進化／第一次完成某類活動。
家庭：validated bond event 生成共同回憶。
團體：共同 Quest 的 aggregate milestone。

每個 memory 有 canonical source reference、createdAt、visibility、revocation policy；
裝置只顯示縮寫 snapshot。

## 收藏系統

### 可收藏

- 角色姿態／表情、已解鎖外觀、場景裝飾、故事頁、家庭共同回憶、團體建設。
- 內容來自正式 catalog 或 deterministic outcome，具有 asset fallback/version。

### 不做

- 不做隨機 loot box、付費戰力、限時恐嚇或必須每天登入才能保住的物品。
- 不讓裝置離線自行解鎖；pending 只顯示等待。
- 不因 catalog archive 刪除使用者已合法擁有的記憶呈現；使用 fallback asset。

## 裝置內容封包

```json
{
  "snapshotVersion": 1,
  "revision": 93,
  "character": {
    "seriesKey": "safe-key",
    "stage": 2,
    "level": 8,
    "assetKey": "builtin-orbit-forest-stage-2"
  },
  "story": {
    "beat": "recovery_returned",
    "textKey": "story.recovery.returned.1"
  },
  "relationship": {
    "type": "family",
    "safeStateKey": "tree_new_leaf"
  }
}
```

裝置使用內建 asset/text key，不接受任意 HTML、script、remote URL 或完整私人資料。
App 驗證 catalog/version 後才下發；NVS commit 後回 exact revision。

## 內容製作流程

1. Content writer 建立 text/animation key、語氣、適用 state、locale、reduced-motion 版。
2. Product reviewer 檢查不羞辱、不診斷、不暗示監控。
3. Designer 提供 Orbit/Station 不同構圖但同語意資產。
4. Developer 打包內建 asset manifest 和 fallback。
5. Cloud catalog 只上架已完整驗證的版本。
6. App preview Orbit/Station 畫面；裝置實機檢查 CJK、記憶體、frame rate。
7. Archive 保留 ownership/memory 相容策略。

## 內容豐富度配置

- 每個 phase 至少 2 個安全短句，但同一 session 不頻繁輪播。
- 每個 stage 至少 ready/focus/celebrate/recovery 四種姿態。
- 每個主要 milestone 有 static/reduced-motion 與 animated 兩版。
- 每週 chapter 重點是回顧和下一步，不用每日生成大量低品質文字。

## 測試

- 相同 Receipt 重送只觸發一次 celebration。
- pending/rejected/revoked 不解鎖故事或收藏。
- 角色資產缺失、archive、版本不相容時 fallback。
- family/group visibility、Membership ended、consent withdrawn。
- 中英長短字、未知 locale、CJK glyph、UTF-8 byte bound。
- reduced motion、sound off、quiet hours。

## 成功指標

- 使用者能把世界變化和哪一個正式行動連結起來。
- 第二次有效行動率與 recovery return，不以通知轟炸取得。
- 角色／故事畫面開啟率、跳過率、動畫關閉率作為品質護欄。
