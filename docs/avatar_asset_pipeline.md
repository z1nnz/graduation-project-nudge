# Avatar 分層素材管線

這份文件說明美術素材要怎麼放進 App。現在 App 的 `AvatarPreview` 會優先讀取透明 PNG 分層素材；如果目前選到的部件素材還沒放進來，會自動退回程式繪製角色，不會讓畫面空白或缺零件。

`assets/avatar_parts/` 是美術工作區，放素材規格、提示詞、manifest 與未來美術交付檔；App 實際執行時讀取 `assets/avatar/` 裡的透明 PNG。

## 畫布規格

- 檔案格式：PNG
- 背景：透明
- 建議尺寸：512 x 768 px
- 所有素材都要使用同一個畫布與同一個角色骨架座標
- 不要裁切成只剩部件大小，請保留完整畫布，讓 Flutter 疊圖時能自動對齊

## 資料夾結構

```text
assets/avatar/
  base/
  faces/
  hair_back/
  hair_front/
  eyes/
  eyebrows/
  mouths/
  outfits/
  accessories/
  backgrounds/

assets/avatar_parts/
  prompts/
  manifest/
  source_svg/
```

## 命名規則

### 基礎身體

```text
assets/avatar/base/body_skin_0.png
assets/avatar/base/body_skin_1.png
assets/avatar/base/body_skin_2.png
```

`skin_0` 對應 `AvatarProfile.skinTones[0]`，依此類推。

### 臉型

```text
assets/avatar/faces/face_0_skin_0.png
assets/avatar/faces/face_1_skin_0.png
assets/avatar/faces/face_2_skin_0.png
```

第一個數字是臉型 index，第二個數字是膚色 index。

### 後髮與前髮

```text
assets/avatar/hair_back/hair_0_color_0.png
assets/avatar/hair_front/hair_0_color_0.png
```

髮型建議拆成後髮與前髮兩層，方便正確遮住臉與衣服。

### 眼睛、眉毛、嘴巴

```text
assets/avatar/eyes/eyes_0.png
assets/avatar/eyebrows/eyebrows_0.png
assets/avatar/mouths/mouth_0.png
```

五官不需要依膚色輸出，除非美術風格需要不同陰影。

### 衣服

```text
assets/avatar/outfits/outfit_0_color_0.png
assets/avatar/outfits/outfit_1_color_0.png
```

第一個數字是衣服樣式 index，第二個數字是衣服顏色 index。

### 配件

```text
assets/avatar/accessories/accessory_1.png
assets/avatar/accessories/accessory_2.png
```

`accessory_0` 代表無配件，可以不用放圖。

### 展示背景

```text
assets/avatar/backgrounds/background_0.png
assets/avatar/backgrounds/background_1.png
```

背景可以不是透明圖，但建議不要太複雜，避免搶角色主體。

## 疊圖順序

App 會依照以下順序疊圖：

1. 背景
2. 後髮
3. 基礎身體
4. 臉型
5. 衣服
6. 眼睛
7. 眉毛
8. 嘴巴
9. 前髮
10. 配件

如果某一層找不到對應檔案，該層會略過。若連基礎身體都沒有，整個角色會退回目前的程式繪製版本。

## 第一批最小素材

建議先放這些就好：

```text
base/body_skin_0.png
faces/face_0_skin_0.png
hair_back/hair_0_color_0.png
hair_front/hair_0_color_0.png
eyes/eyes_0.png
eyebrows/eyebrows_0.png
mouths/mouth_0.png
outfits/outfit_0_color_0.png
```

確認可以正常顯示後，再擴充其他 index。
