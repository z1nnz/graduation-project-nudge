# Avatar Layered Assets

這個資料夾是新版簡化換裝素材管線。

每張圖建議使用：

- PNG
- 透明背景
- 512 x 768 px
- 所有部件使用同一個角色骨架座標

目前正式導入的 Nudge 素材改成穩定展示版：

- `characters/character_0.png`：男生角色底圖
- `characters/character_1.png`：女生角色底圖
- `characters/character_0_outfit_1.png`：男生穿著粉紫日常套裝的完整角色圖，可選
- `characters/character_1_outfit_1.png`：女生穿著粉紫日常套裝的完整角色圖，可選
- `simple_outfits/outfit_1.png`：粉紫日常套裝
- `simple_outfits/outfit_2.png`：夜讀連帽套裝
- `simple_outfits/outfit_3.png`：薄荷晨讀套裝
- `simple_outfits/outfit_4.png`：暖陽行動套裝
- `simple_outfits/outfit_5.png`：粉莓專注套裝
- `simple_outfits/outfit_6.png`：森林自律套裝
- `accessories/accessory_1.png`：金色星光
- `accessories/accessory_2.png`：藍色星光
- `accessories/accessory_3.png`：粉色星光

先不拆五官、眉毛、嘴巴、前髮與後髮，也不再把背景放進換裝系統，避免圖層對位不穩。後續新增第二套素材時，請沿用相同 512 x 768 畫布與骨架座標，並同步更新 `AvatarCatalog` 的標籤數量。

如果服裝和身體一直對不準，優先使用「完整套裝角色圖」：

- 命名格式：`characters/character_{角色編號}_outfit_{服裝編號}.png`
- 例如：`character_0_outfit_2.png` 代表男生穿著夜讀連帽套裝
- App 會先找完整套裝角色圖；找不到時才退回 `角色底圖 + simple_outfits` 疊圖
