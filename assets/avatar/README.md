# Avatar Character Assets

目前 Nudge 的角色系統先改成「完整角色圖」模式。

也就是商城販售一張已經畫好髮型、五官、衣服與配件的角色圖片，使用者購買後直接套用，不再即時疊衣服、眼睛、配件或背景。這樣可以先避免圖層對位不穩，讓商城和好友展示都能穩定呈現漂亮角色。

## 正式使用的檔案

- `characters/character_0.png`：預設角色，免費
- `characters/character_1.png`：商城角色

新增角色時請照這個格式：

- 檔名：`characters/character_{index}.png`
- 尺寸：建議 `512 x 768 px`
- 背景：透明 PNG
- 內容：完整角色本體，包含髮型、臉、衣服、鞋子與配件

新增角色後，同步到 `lib/models/avatar_catalog.dart` 的 `faceShapeLabels` 加一個角色名稱。例：

```dart
static const List<String> faceShapeLabels = [
  '晨光練習生',
  '星光少女',
  '夜讀少年',
];
```

對應檔案就要新增：

```text
assets/avatar/characters/character_2.png
```

## 未來發展

以下資料夾目前視為未來的分層換裝管線，App 現階段不再主動使用：

- `simple_outfits/`
- `accessories/`
- 五官、眉毛、嘴巴、前髮、後髮等分層素材
- 換裝背景素材

如果之後要重新啟用部件換裝，必須先重新建立統一骨架座標與素材輸出規格，再回來接 `AvatarProfile` 裡保留的舊欄位。
