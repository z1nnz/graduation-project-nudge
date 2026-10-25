# 05｜Web Dashboard 與管理後台改善工作包

## 定位

Web 用於長期回顧、家庭／團體管理、角色與裝置營運、稽核及專題展示；它不應
複製 App 的日常操作，也不能成為繞過 Cloud authority 的捷徑。

## 切片 A｜依能力導覽與頁面瘦身（P1）

### 問題

頁面多、功能入口分散，登入者容易看到與自己無關或無權操作的功能。只在共用
sidebar 注入更多選單會繼續增加雜訊。

### 怎麼做

1. 定義 Web route manifest：route、label、required capabilities、data readiness、
   role-specific landing page。
2. 登入後先解析個人能力與目前 `relationship_membership`，再產生導覽。
3. personal、guardian/child、manager/member、staff 分成不同資訊架構；共同元件
   重用，但不可共用錯誤權限假設。
4. 不具能力的 URL 直接 fail closed 到說明頁，不能只隱藏導覽連結。
5. 把 demo-only 假資料與正式 Firebase 狀態明確分區並加永久標示。

### 驗收

- [ ] 四種關係角色與一般個人帳號有導覽快照測試。
- [ ] 直接輸入無權 URL 不顯示敏感摘要或管理按鈕。
- [ ] keyboard、focus order、窄螢幕與 reduced motion 可用。

## 切片 B｜完整角色系列上架（P1）

### 管理流程

1. 建立 draft series，設定不可變／唯一 `seriesKey`。
2. 一次輸入三個 stage 的名稱、圖鑑描述、全身圖、icon、等級、XP 與 predecessor。
3. 圖片先上傳 Storage 暫存位置；metadata 驗證成功才發佈。
4. 預覽 App 商城、圖鑑、進化路線與裝置安全快照。
5. Cloud transaction 驗證完整性、unlock 遞增、asset 存在、只有 stage 1 可販售。
6. publish／archive 產生稽核事件；失敗 publish 清除孤兒資產。

### 必須保護的規則

- draft、archived、expired、不完整系列不進 App catalog。
- stage 2/3 不可直接購買；裝備時由 Cloud 驗證正式 ownership 與 series XP。
- Firestore 只存 metadata 和 Storage path，不放大型 base64 圖片。
- Web 前端驗證只改善體驗，Cloud 仍必須重做所有驗證。

### 主要位置

- `web_dashboard/assets/admin_catalog.js`
- `functions/src/catalog-management-service.js`
- `functions/src/reward-purchase-service.js`
- `functions/src/reward-avatar-service.js`
- `storage.rules`、`firestore.rules`
- `test/admin_catalog_test.js` 與 functions catalog tests

## 切片 C｜裝置指派營運台（P0/P1）

- 依 deviceId 查詢 current assignment、狀態、使用者安全代號、允許房間、更新時間。
- 指派前顯示 transfer/wipe 限制；revoke 不是跨帳號重綁許可。
- 新增／移除房間 scope 或重新啟用 revoked assignment 時，沒有 verified empty queue
  receipt 就明確拒絕。
- 每次 assign/revoke 記錄 actor、原因、request ID、結果，不記 BLE payload 或個資。
- 顯示「source-verified」「device-verified」等證據狀態，避免營運者誤判。

## 切片 D｜家庭與團體管理（P1）

### 家庭

- guardian 可發出邀請、提出共同目標、調整已同意的分享層級與解除連結。
- child 能接受／拒絕、撤回分享與查看自己曾同意的範圍。
- 報告預設只顯示趨勢和共同成果，不揭露精確健康值。

### 團體

- manager 可邀請／移除、轉移管理權、管理團體設定和官方房間。
- member 自主管理參與、分享摘要和退出；manager 不得代填。
- 團體尚有其他成員時不得直接解散，需先轉移或處理成員。

所有 mutation 使用 Cloud callable／transaction 和 formal Membership，不直接從
Web 修改父文件陣列。

## 切片 E｜安全與維護性（P1）

- 所有使用者／catalog 字串用 DOM text API 或統一 escaping，不用 `innerHTML`
  拼接未受信任內容。
- inline event handler 改成 `addEventListener`；更新 CSP 後補 XSS surface tests。
- 共用 asset 版本和 cache busting，避免某些頁面載入舊 contract。
- 將多頁重複的 Auth、App Check、error mapping、loading state 收進共用 Adapter。
- runtime config 不含 secret；App Check site key 是 public config，仍需 domain restriction。

## 測試與證據

```bash
node --test test/*.js
npm --prefix functions test
```

另需：

- Firestore/Storage Emulator：無權讀寫、catalog publish、孤兒資產、裝置指派。
- 五種能力角色的 browser 操作矩陣。
- draft → preview → publish → App sync → archive 的一條完整角色證據。
- assign → Android connect → revoke 的一條裝置證據；實機部分與工作包 03 共用。

## 不做

- 不在 Web 手動填健康數據或替成員完成活動。
- 不讓 staff 身分自動讀取私人健康、家庭內容或所有 Activity Ledger。
- 不把 presentation/demo data 混成 production verified 證據。
