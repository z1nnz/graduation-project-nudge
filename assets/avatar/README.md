# Avatar Layered Assets

這個資料夾是新版分層換裝素材管線。

每張圖建議使用：

- PNG
- 透明背景
- 512 x 768 px
- 所有部件使用同一個角色骨架座標

目前正式導入的第一套 Nudge 素材只保留實際有圖檔的項目：

- `base/body_skin_0.png`
- `faces/face_0_skin_0.png`
- `hair_back/hair_0_color_0.png`
- `hair_front/hair_0_color_0.png`
- `eyes/eyes_0.png`
- `eyebrows/eyebrows_0.png`
- `mouths/mouth_0.png`
- `outfits/outfit_0_color_0.png`
- `accessories/accessory_1.png`
- `backgrounds/background_0.png`

後續新增第二套素材時，請沿用相同 512 x 768 畫布與骨架座標，並同步更新 `AvatarCatalog` 的標籤數量。
