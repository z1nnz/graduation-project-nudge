# 夥伴小屋（App）與家具商城 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 App 首頁的陪伴卡換成像素風「夥伴小屋」：房間依真實成果成長，並能用自律幣在 Cloud 購買、擺放家具款式。

**Architecture:** 房間是分層的像素素材（底圖、可換款式、成長物件），位置寫在 `assets/home/cabin_layout.json`。純函式 `CabinPresentation` 從 AppState 已有資料算出每層要顯示什麼，`CompanionCabinView` 用 Stack 疊出畫面。家具價格只有一份 JSON，Cloud 與 App 各存一份副本，由契約測試鎖住內容相同。購買沿用 `purchaseRewardItem`（新增 `homeDecor` 類別）；擺放走新的 Cloud callable `arrangeHomeDecor`，寫入受 Rules 保護的 `users.homeDecor`。

**Tech Stack:** Flutter 3.41.7／Dart、Provider、Firebase Cloud Functions v2（Node 22, ESM）、Firestore Rules、Pillow（素材整理）、Codex CLI 影像生成。

**Spec:** `docs/superpowers/specs/2026-11-23-nudge-companion-cabin-design.md`

## Global Constraints

- 不新增金幣或經驗值來源，不改獎勵公式；Cloud／Rules 只做家具商城的最小延伸。
- 慶祝動畫只在 ConfirmedActivityFeedback 回報新的 Cloud 確認時播放；pending 不顯示數字。
- 不修改 `app_state.dart` 的既有資料邏輯，只新增 `homeDecor` 的讀取、getter 與 `arrangeHomeDecor`、`avatarItemPrice` 的 `homeDecor` 分支。
- 全部採像素風，與 `assets/avatar/characters/` 同一畫風；素材放 `assets/home/`。
- 360px 寬、深色、減少動態設定都要可用；減少動態時角色不移動、不播放粒子。
- 每個位置的款式 0 免費且預設擁有。
- clientRequestId 用 `newClientId`（`lib/utils/client_ids.dart`，來自 PR #73；本分支若尚未包含，先 cherry-pick #73 的該檔）。
- Commit 作者為 repo 設定的 z1nnz noreply 身分，不加 AI 署名行。

## Review Focus

1. 沒登入（guest）時：小屋照樣顯示，款式只用免費款，購買按鈕導向登入，不呼叫 Cloud。→ Task 6、Task 7 測試。
2. Cloud 回傳的 `homeDecor` 含未知位置或超出範圍的編號：App 退回該位置款式 0，不閃退。→ Task 5 測試。
3. 餘額不足、重複購買、重送同一個 clientRequestId：Cloud 不重複扣款，App 顯示明確訊息。→ Task 3、Task 7 測試。
4. 擺放一件沒有擁有的款式（偽造請求）：Cloud 拒絕。→ Task 4 測試。
5. 帳號切換：B 登入後不能看到 A 的家具擺設。→ Task 5 測試（登出時清空）。

---

## File Structure

| 檔案 | 責任 |
|---|---|
| `tool/cabin_art/prompts/*.txt`、`tool/cabin_art/key_sprites.py` | 產圖提示詞；把洋紅背景的產圖去背、裁切、縮成像素格 |
| `assets/home/*.png`、`assets/home/cabin_layout.json` | 房間各層素材與位置（0–1 正規化座標） |
| `assets/home/home_decor_catalog.json`、`functions/src/home-decor-catalog.json` | 家具位置、款式、價格（兩份內容必須相同） |
| `lib/models/home_decor_catalog.dart` | 讀取家具目錄的模型 |
| `lib/models/cabin_presentation.dart` | 純函式：AppState 資料 → 每層顯示狀態 |
| `lib/widgets/companion_cabin_view.dart` | 小屋畫面（Stack 疊層、HUD、對話、委託板點擊） |
| `lib/widgets/home_decor_sheet.dart` | 家具商城底部面板（預覽、購買、擺放） |
| `lib/services/cloud_home_decor_gateway.dart` | 呼叫 `arrangeHomeDecor` |
| `functions/src/home-decor-service.js` | `arrangeHomeDecor` handler |
| `functions/src/reward-purchase-service.js` | 新增 `homeDecor` 類別與價格 |
| `functions/index.js` | 匯出 `arrangeHomeDecor` |
| `firestore.rules` | `homeDecor` 加入受保護欄位 |

---

### Task 1: 小屋像素素材與版面檔

**Files:**
- Create: `tool/cabin_art/prompts/base_room.txt`、`rug.txt`、`curtain.txt`、`lamp.txt`、`books.txt`、`plant.txt`
- Create: `tool/cabin_art/key_sprites.py`
- Create: `assets/home/room_base.png`、`rug_0..2.png`、`curtain_0..2.png`、`lamp_0..2.png`、`books_0..3.png`、`plant_0..3.png`、`badge.png`、`globe.png`
- Create: `assets/home/cabin_layout.json`
- Modify: `pubspec.yaml`（assets 加 `assets/home/`）
- Test: `test/cabin_layout_test.dart`

**Interfaces:**
- Produces: `cabin_layout.json` 格式 `{"baseImage": "assets/home/room_base.png", "aspect": 0.5625, "layers": {"<layerId>": {"rect": [left, top, width, height], "z": int, "images": ["assets/home/..."]}}, "character": {"rect": [...]}, "questBoard": {"rect": [...]}, "doors": {"family": {"rect": [...]}, "group": {"rect": [...]}}}`。layerId 固定為 `rug`、`curtain`、`lamp`、`books`、`plant`、`badges`、`globe`。

- [ ] **Step 1: 寫失敗測試** `test/cabin_layout_test.dart`：`cabin layout references existing assets inside the frame`。讀 `assets/home/cabin_layout.json`，斷言：
  - 7 個 layerId 都存在；
  - 每個 rect 四個數都在 0–1 之間，且 `left + width ≤ 1`、`top + height ≤ 1`；
  - `images` 裡每個檔案 `File(path).existsSync()` 為真；
  - `rug`、`curtain`、`lamp` 各 3 張，`books`、`plant` 各 4 張。
- [ ] **Step 2: 執行** `flutter test test/cabin_layout_test.dart`，預期 FAIL（檔案不存在）。
- [ ] **Step 3: 產圖**。底圖提示詞＝概念圖的房間，但：不畫角色、地毯、窗簾、書櫃內的書、盆栽、桌燈、地球儀；書櫃留空格。其餘物件各自在純洋紅 `#FF00FF` 背景上單獨產生，參考圖附 `docs/superpowers/specs/2026-11-23-companion-cabin-concept.png` 與 `assets/avatar/characters/character_0.png` 以鎖定畫風。指令：`codex exec --skip-git-repo-check --approve-for-me -C <dir> -i <ref...> -o last.txt -`（提示詞由 stdin 傳入）。
- [ ] **Step 4: 實作** `tool/cabin_art/key_sprites.py`：`key(src: Path, dst: Path, target_width: int) -> None`。洋紅色距離 < 60 的像素設為透明，裁到不透明範圍，以 NEAREST 縮到 `target_width`。
- [ ] **Step 5: 寫 `cabin_layout.json`**，rect 依底圖實際位置量測；在 `pubspec.yaml` 加入 `- assets/home/`。
- [ ] **Step 6: 執行** `flutter test test/cabin_layout_test.dart`，預期 PASS。
- [ ] **Step 7: Commit** `feat(home): add pixel cabin art layers and layout`。

### Task 2: 共用家具目錄

**Files:**
- Create: `assets/home/home_decor_catalog.json`、`functions/src/home-decor-catalog.json`（內容相同）
- Create: `lib/models/home_decor_catalog.dart`
- Test: `test/home_decor_catalog_contract_test.js`、`test/home_decor_catalog_test.dart`

**Interfaces:**
- Produces（JSON）：`{"version": 1, "slots": [{"slot": "rug", "label": "地毯", "variants": [{"index": 0, "name": "星夜圓毯", "price": 0}, {"index": 1, "name": "...", "price": 30}, {"index": 2, "name": "...", "price": 60}]}, ...]}`，slot 依序為 `rug`、`curtain`、`lamp`。
- Produces（Cloud item key）：`homeDecor:<slotOrder*100 + index>`。rug＝0–2、curtain＝100–102、lamp＝200–202。
- Produces（Dart）：`class HomeDecorCatalog { static Future<HomeDecorCatalog> load(AssetBundle bundle); List<HomeDecorSlot> get slots; HomeDecorVariant? variant(String slot, int index); int itemIndex(String slot, int index); }`；`HomeDecorSlot { String slot; String label; List<HomeDecorVariant> variants; }`；`HomeDecorVariant { int index; String name; int price; }`。

- [ ] **Step 1: 寫失敗測試** `test/home_decor_catalog_contract_test.js`：`App and Cloud share one home decor catalog`。斷言兩個 JSON `deepEqual`；每個 slot 的 variant 0 價格為 0，其餘價格為 1–200 的正整數；slot 名稱集合等於 `["rug","curtain","lamp"]`。
- [ ] **Step 2: 寫失敗測試** `test/home_decor_catalog_test.dart`：`itemIndex maps slot order and variant`。斷言 `itemIndex('curtain', 2) == 102`；`variant('lamp', 9) == null`。
- [ ] **Step 3: 執行** 兩個測試，預期 FAIL。
- [ ] **Step 4: 建立兩份 JSON 與 Dart 模型**。款式名稱與價格：地毯（星夜圓毯 0、紅磚方毯 30、雲朵絨毯 60）、窗簾（紫絨窗簾 0、星點紗簾 25、晨光碎花 50）、桌燈（燈塔小燈 0、月亮夜燈 35、水晶星燈 70）。
- [ ] **Step 5: 執行** 兩個測試，預期 PASS。
- [ ] **Step 6: Commit** `feat(home): add shared home decor catalog`。

### Task 3: Cloud 購買支援 homeDecor

**Files:**
- Modify: `functions/src/reward-purchase-service.js`（`normalizeInput` 的類別白名單；`resolvePrice`）
- Test: `functions/test/reward_purchase_service.test.js`

**Interfaces:**
- Consumes: `functions/src/home-decor-catalog.json`、Task 2 的 item key 規則。
- Produces: `purchaseRewardItem({category: "homeDecor", index, catalogItemId: null, ...})` 回傳 `itemKey: "homeDecor:<index>"`。

- [ ] **Step 1: 寫失敗測試**（三個）：
  - `home decor purchase debits the catalog price once`：餘額 100 買 `homeDecor:101`，`disciplineCoins === 75`，`unlockedAvatarItems` 含 `homeDecor:101`；同一 clientRequestId 重送回傳 `replayed: true`，餘額仍是 75。
  - `free or unknown home decor variants are not purchasable`：`homeDecor:0` 與 `homeDecor:150` 都丟 `failed-precondition`。
  - `home decor purchase rejects a catalog document claim`：帶 `catalogItemId` 丟 `invalid-argument`。
- [ ] **Step 2: 執行** `npm --prefix functions test`，預期新測試 FAIL。
- [ ] **Step 3: 實作**：用 `createRequire` 或 `import ... with { type: "json" }` 載入目錄，建出 `HOME_DECOR_PRICES: Map<number, number>`（只放 price > 0）；`homeDecor` 類別必須 `catalogItemId === null`，且 index 在表內。
- [ ] **Step 4: 執行** `npm --prefix functions test`，預期全部 PASS。
- [ ] **Step 5: Commit** `feat(cloud): sell home decor variants through purchaseRewardItem`。

### Task 4: Cloud `arrangeHomeDecor` 與 Rules

**Files:**
- Create: `functions/src/home-decor-service.js`
- Modify: `functions/index.js`（比照 `equipRewardAvatar`：`enforceAppCheck: true`、`withAccountOperation`、錯誤訊息 "The home decor arrangement could not be saved."）
- Modify: `firestore.rules`（`hasProtectedRewardFields` 與 `changesProtectedRewardFields` 加 `'homeDecor'`）
- Test: `functions/test/home_decor_service.test.js`、`test/firestore_home_decor_rules_test.js`

**Interfaces:**
- Produces: `createArrangeHomeDecorHandler({ firestore, clock })`。輸入 `{ arrangement: { rug: int, curtain: int, lamp: int }, clientRequestId: string, sourceSurface: "app" | "web" }`，回傳 `{ rewardEntryId, homeDecor: {rug, curtain, lamp}, replayed }`。寫入 `users/{uid}.homeDecor`，並建立 `reward_ledger_entries/decor_<hash>`（`entryType: "decorArrangement"`、兩個 delta 皆為 0）。

- [ ] **Step 1: 寫失敗測試** `functions/test/home_decor_service.test.js`（沿用 purchase 測試的 MemoryFirestore 寫法）：
  - `owned and free variants can be arranged`：擁有 `homeDecor:101`，擺放 `{rug:0, curtain:1, lamp:0}` 成功，user 的 `homeDecor` 等於輸入。
  - `unowned variant is rejected`：擺放 `curtain:2` 但沒有 `homeDecor:102`，丟 `failed-precondition`。
  - `arrangement must name every slot with a known variant`：缺 `lamp` 或 `rug: 7`，丟 `invalid-argument`。
  - `replaying the same request returns the stored result`：第二次回傳 `replayed: true`。
  - `paused ledger blocks arrangement`：`system_state/reward_ledger_cutover.writesPaused` 為 true 時丟 `unavailable`。
- [ ] **Step 2: 寫失敗測試** `test/firestore_home_decor_rules_test.js`：沒有 emulator 時印出 skip 並 `process.exit(0)`（比照 `test/firestore_activity_feedback_rules_test.js`）。有 emulator 時，本人以 REST PATCH `users/{uid}?updateMask.fieldPaths=homeDecor` 預期 403；PATCH `nickname` 預期 200。
- [ ] **Step 3: 執行** 單元測試，預期 FAIL。
- [ ] **Step 4: 實作** handler、`index.js` 匯出、Rules 兩處加 `'homeDecor'`。
- [ ] **Step 5: 執行** `npm --prefix functions test` 與 `JAVA_HOME=D:/DevTools/jdk-21 firebase emulators:exec --only auth,firestore --project nudge-discipline-app "node test/firestore_home_decor_rules_test.js"`，預期 PASS。
- [ ] **Step 6: Commit** `feat(cloud): arrange owned home decor through a protected callable`。

### Task 5: App 讀取與擺放家具

**Files:**
- Create: `lib/services/cloud_home_decor_gateway.dart`
- Modify: `lib/state/app_state.dart`：
  - 兩處讀取 user 文件的地方（目前讀 `unlockedAvatarItems` 的區塊，約第 534 行、第 2101 行）加讀 `homeDecor`；
  - `avatarItemPrice` 加 `homeDecor` 分支；
  - 登出清空處（約第 7043 行）重設 `_homeDecor`。
- Test: `test/home_decor_state_test.dart`

**Interfaces:**
- Consumes: Task 2 `HomeDecorCatalog`；Task 4 callable 名稱 `arrangeHomeDecor`。
- Produces:
  - `CloudHomeDecorGateway.withCallable(Future<Object?> Function(Map<String, dynamic>) call)`、`.firebase()`；`Future<Map<String, int>> arrange(Map<String, int> arrangement, {required String clientRequestId})`，失敗丟 `HomeDecorException(code, message)`。
  - AppState：`Map<String, int> get homeDecor`（缺少或不合法的位置回傳 0）；`Future<bool> arrangeHomeDecor(Map<String, int> arrangement)`；`bool isHomeDecorOwned(String slot, int index)`；建構子新增可選參數 `CloudHomeDecorGateway? homeDecorGateway`。
  - `static Map<String, int> parseHomeDecor(Object? raw)`：放在 `lib/models/home_decor_catalog.dart`，作為純函式。

- [ ] **Step 1: 寫失敗測試**：
  - `parseHomeDecor falls back to the free variant`：`{'rug': 2, 'curtain': 'x', 'lamp': 9, 'sofa': 1}` → `{'rug': 2, 'curtain': 0, 'lamp': 0}`。
  - `guest arrangement stays local and owned-only`：未登入時擺放免費款成功、擺放未擁有款回傳 false，且不呼叫 gateway。
  - `signed-in arrangement applies the Cloud result`：fake gateway 回傳 `{'rug':1,'curtain':0,'lamp':0}`，`homeDecor` 等於該值。
  - `sign-out clears the arrangement`：登出後 `homeDecor` 回到全 0。
- [ ] **Step 2: 執行** `flutter test test/home_decor_state_test.dart`，預期 FAIL。
- [ ] **Step 3: 實作** gateway 與 AppState 新增項目。clientRequestId 用 `newClientId('app_decor')`。
- [ ] **Step 4: 執行** 預期 PASS；`flutter analyze` 無 issue。
- [ ] **Step 5: Commit** `feat(app): read and arrange home decor from Cloud`。

### Task 6: 小屋呈現模型

**Files:**
- Create: `lib/models/cabin_presentation.dart`
- Test: `test/cabin_presentation_test.dart`

**Interfaces:**
- Produces: `class CabinPresentation { final int bookStage; final int plantStage; final int badgeCount; final bool showGlobe; final bool globeGlowing; final Map<String,int> decor; final String bubbleText; final int questCount; }`；`static CabinPresentation resolve({required List<DailySummary> summaries, required List<BadgeRecord> badges, required Map<String,int> decor, required DailyNextAction action, required int openTaskCount, required bool hasDevice, required bool deviceFocusing, DateTime? today})`。
- 規則：
  - `bookStage`：近 30 天中 focusMinutes ≥ 25 的天數；0–2 天→0，3–7→1，8–15→2，16 以上→3。
  - `plantStage`：取 badges 中 `focus_streak` 與 `task_streak` progress 的較大值；0→0，1–2→1，3–6→2，7 以上→3。
  - `badgeCount`：已解鎖徽章數，上限 3。
  - `bubbleText`：沿用 `DailyNextAction` 的標題。

- [ ] **Step 1: 寫失敗測試**：`book stage thresholds`（2/3/8/16 天 → 0/1/2/3）、`plant stage uses the longer streak`、`badges cap at three`、`globe only with a device and glows only while focusing`。
- [ ] **Step 2: 執行**，預期 FAIL。
- [ ] **Step 3: 實作** `resolve`。
- [ ] **Step 4: 執行**，預期 PASS。
- [ ] **Step 5: Commit** `feat(home): resolve cabin growth from confirmed progress`。

### Task 7: 小屋畫面與家具商城面板

**Files:**
- Create: `lib/widgets/companion_cabin_view.dart`、`lib/widgets/home_decor_sheet.dart`
- Modify: `lib/screens/home_page.dart`（以 `CompanionCabinView` 取代 `heroCard` 與 `DailyCompanionCard` 兩個區塊；其餘區塊保留）
- Test: `test/companion_cabin_view_test.dart`、`test/home_decor_sheet_test.dart`

**Interfaces:**
- Consumes: Task 1 layout、Task 2 catalog、Task 5 AppState API、Task 6 `CabinPresentation`。
- Produces: `CompanionCabinView({required CabinPresentation presentation, required AvatarProfile profile, required int level, required double levelProgress, required int coins, required VoidCallback onOpenQuests, required VoidCallback onOpenDecor, required VoidCallback onOpenFamily, required VoidCallback onOpenGroup, String? confirmedActivityLabel})`；`showHomeDecorSheet(BuildContext context)`。

- [ ] **Step 1: 寫失敗 widget 測試**：
  - `cabin shows the next action and opens quests`：找到 bubbleText；點委託板（`Key('cabin-quest-board')`）呼叫 `onOpenQuests`。
  - `cabin layers follow the presentation`：`bookStage: 2` 時顯示 `assets/home/books_2.png`；`decor.rug == 1` 時顯示 `rug_1.png`。
  - `reduced motion keeps the character still`：`MediaQuery(disableAnimations: true)` 下沒有進行中的動畫（`tester.hasRunningAnimations == false`）。
  - `decor sheet buys then arranges`：fake AppState 餘額 100，點「星點紗簾」購買後呼叫 purchase 一次，再呼叫 arrange 一次。
  - `guest decor purchase asks to sign in`：未登入時點付費款式，顯示「登入後才能購買」，不呼叫 purchase。
  - `celebration plays only for a newly confirmed activity`：第一次建構時帶 `confirmedActivityLabel: 'A'`，不顯示 `Key('cabin-celebration')`；更新成 `'B'` 後才出現；再以 `'B'` 重建不重播。
- [ ] **Step 2: 執行**，預期 FAIL。
- [ ] **Step 3: 實作**：
  - 畫面：以 `AspectRatio(9/16)` 加 Stack 疊層，位置來自 layout。像素圖一律 `filterQuality: FilterQuality.none`。
  - 角色：用現有角色圖，idle 上下浮動 2px、週期 2.4 秒；減少動態時不動。
  - HUD：等級、經驗條、金幣、連續天數。
  - 「家具」按鈕開啟 `showHomeDecorSheet`；面板內預覽即時套用在小屋上，未購買款式顯示價格。
- [ ] **Step 4: 執行** 全部 `flutter test`，預期 PASS；`flutter analyze` 無 issue。
- [ ] **Step 5: 截圖**：`flutter run -d chrome` 開啟首頁，用瀏覽器分別截 360×780 與 412×915 兩張圖，存到 `docs/acceptance/screenshots/companion-cabin/`。
- [ ] **Step 6: Commit** `feat(home): companion cabin home with decor shop`。

### Task 8: 整體驗證與 PR

- [ ] **Step 1:** `flutter analyze`、`flutter test`、`node --test test/*.js`、`npm --prefix functions test`，全部 0 fail、0 skipped（rules 測試除外，見下一步）。
- [ ] **Step 2:** `JAVA_HOME=D:/DevTools/jdk-21 firebase emulators:exec --only auth,firestore --project nudge-discipline-app "bash D:/nudge/rules-test.sh"`，加上 `node test/firestore_home_decor_rules_test.js`，全部通過。
- [ ] **Step 3:** 推送 `feature/claude-sky-island`，開 PR 到 main。PR 說明附截圖，並明列：
  - Cloud 與 Rules 需要部署才會生效；
  - 概念圖不等於實作畫面；
  - 尚未在實機驗證。

## 不在本計畫內（另立計畫）

- 底部導覽改成小屋、委託、圖鑑、同伴，以及「背包」選單。
- Web／PWA 版小屋、休息券、三款小遊戲。
- 家庭庭院與團體交誼廳的內頁（本計畫的門只導向現有頁面）。
