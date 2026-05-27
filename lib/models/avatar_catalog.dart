import 'package:flutter/material.dart';

class AvatarPartCategory {
  final String key;
  final String title;
  final String hint;
  final IconData icon;
  final List<String> labels;
  final List<Color>? colors;
  final bool requiresUnlock;
  final bool appearsInShop;

  const AvatarPartCategory({
    required this.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.labels,
    this.colors,
    this.requiresUnlock = true,
    this.appearsInShop = true,
  });

  int get itemCount => labels.length;

  String labelFor(int index) {
    return labels[index.clamp(0, labels.length - 1)];
  }
}

class AvatarEvolutionStage {
  final int index;
  final String series;
  final String name;
  final int stage;
  final int requiredLevel;
  final int requiredExperience;
  final String description;
  final String characterAsset;
  final String iconAsset;
  final int coinPrice;

  const AvatarEvolutionStage({
    required this.index,
    required this.series,
    required this.name,
    required this.stage,
    required this.requiredLevel,
    required this.requiredExperience,
    required this.description,
    required this.characterAsset,
    required this.iconAsset,
    this.coinPrice = 0,
  });

  String get stageLabel => '第 $stage 階';
}

class AvatarSeries {
  final String key;
  final String name;
  final String theme;
  final String description;
  final List<AvatarEvolutionStage> stages;

  const AvatarSeries({
    required this.key,
    required this.name,
    required this.theme,
    required this.description,
    required this.stages,
  });
}

class AvatarCatalog {
  static List<AvatarEvolutionStage> evolutionStages = [
    AvatarEvolutionStage(
      index: 0,
      series: '星辰旅人',
      name: '星辰學徒',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '剛開始陪你建立自律節奏的基礎型態。',
      characterAsset: 'assets/avatar/characters/character_0.png',
      iconAsset: 'assets/avatar/icons/icon_0.png',
    ),
    AvatarEvolutionStage(
      index: 1,
      series: '星辰旅人',
      name: '星光魔導士',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '連續累積約 20 天滿額經驗後解鎖的進階造型。',
      characterAsset: 'assets/avatar/characters/character_1.png',
      iconAsset: 'assets/avatar/icons/icon_1.png',
    ),
    AvatarEvolutionStage(
      index: 2,
      series: '星辰旅人',
      name: '星耀守護者',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '長期穩定累積約 60 天滿額經驗後解鎖的最終造型。',
      characterAsset: 'assets/avatar/characters/character_2.png',
      iconAsset: 'assets/avatar/icons/icon_2.png',
    ),
    AvatarEvolutionStage(
      index: 3,
      series: '星詠魔導',
      name: '星詠見習生',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '戴著圓框眼鏡、背著星光書包的第二條角色起點。',
      characterAsset: 'assets/avatar/characters/character_3.png',
      iconAsset: 'assets/avatar/icons/icon_3.png',
    ),
    AvatarEvolutionStage(
      index: 4,
      series: '星詠魔導',
      name: '星杖魔導士',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '拿起星杖與披風，陪你把自律習慣推進到穩定節奏。',
      characterAsset: 'assets/avatar/characters/character_4.png',
      iconAsset: 'assets/avatar/icons/icon_4.png',
    ),
    AvatarEvolutionStage(
      index: 5,
      series: '星詠魔導',
      name: '星穹大魔導',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '以金色星盤、紫色寶石與長袍完成的第二角色最終型態。',
      characterAsset: 'assets/avatar/characters/character_5.png',
      iconAsset: 'assets/avatar/icons/icon_5.png',
    ),
    AvatarEvolutionStage(
      index: 6,
      series: '焰心鬥士',
      name: '焰心新星',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '帶著火焰般行動力的第三位角色起點。',
      characterAsset: 'assets/avatar/characters/character_6.png',
      iconAsset: 'assets/avatar/icons/icon_6.png',
    ),
    AvatarEvolutionStage(
      index: 7,
      series: '焰心鬥士',
      name: '烈焰拳士',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '燃起火焰護甲，把每日任務推進成穩定戰力。',
      characterAsset: 'assets/avatar/characters/character_7.png',
      iconAsset: 'assets/avatar/icons/icon_7.png',
    ),
    AvatarEvolutionStage(
      index: 8,
      series: '焰心鬥士',
      name: '赤龍焰姬',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '與赤龍同行的第三角色最終型態，象徵長期自律的爆發力。',
      characterAsset: 'assets/avatar/characters/character_8.png',
      iconAsset: 'assets/avatar/icons/icon_8.png',
    ),
    AvatarEvolutionStage(
      index: 9,
      series: '玫瑰學院',
      name: '玫瑰書生',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '帶著書包與紅玫瑰徽章的第四位角色起點。',
      characterAsset: 'assets/avatar/characters/character_9.png',
      iconAsset: 'assets/avatar/icons/icon_9.png',
    ),
    AvatarEvolutionStage(
      index: 10,
      series: '玫瑰學院',
      name: '薔薇遊俠',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '披上薔薇斗篷與弓箭，把日常累積轉成穩定行動力。',
      characterAsset: 'assets/avatar/characters/character_10.png',
      iconAsset: 'assets/avatar/icons/icon_10.png',
    ),
    AvatarEvolutionStage(
      index: 11,
      series: '玫瑰學院',
      name: '緋玫守護者',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '以金紅披風、玫瑰長弓與華麗徽章完成的第四角色最終型態。',
      characterAsset: 'assets/avatar/characters/character_11.png',
      iconAsset: 'assets/avatar/icons/icon_11.png',
    ),
    AvatarEvolutionStage(
      index: 12,
      series: '月影忍者',
      name: '月影見習忍',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '需要用自律幣購買的夜行系角色起點，象徵安靜專注與深度任務。',
      characterAsset: 'assets/avatar/characters/character_12.png',
      iconAsset: 'assets/avatar/icons/icon_12.png',
      coinPrice: 120,
    ),
    AvatarEvolutionStage(
      index: 13,
      series: '月影忍者',
      name: '月輪影步者',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '披上月光披風與銀色護甲，把日常專注累積成更穩定的行動力。',
      characterAsset: 'assets/avatar/characters/character_13.png',
      iconAsset: 'assets/avatar/icons/icon_13.png',
    ),
    AvatarEvolutionStage(
      index: 14,
      series: '月影忍者',
      name: '蒼月隱曜忍',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '以蒼月兜帽、月牙法器與流光完成的自律幣角色最終型態。',
      characterAsset: 'assets/avatar/characters/character_14.png',
      iconAsset: 'assets/avatar/icons/icon_14.png',
    ),
    AvatarEvolutionStage(
      index: 15,
      series: '森語女神',
      name: '森芽靈童',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '需要用自律幣購買的森林女神系列起點，象徵健康、恢復與生命力。',
      characterAsset: 'assets/avatar/characters/character_15.png',
      iconAsset: 'assets/avatar/icons/icon_15.png',
      coinPrice: 120,
    ),
    AvatarEvolutionStage(
      index: 16,
      series: '森語女神',
      name: '森語祝福者',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '戴上花冠與葉光披肩，把睡眠、健康與日常恢復累積成自然祝福。',
      characterAsset: 'assets/avatar/characters/character_16.png',
      iconAsset: 'assets/avatar/icons/icon_16.png',
    ),
    AvatarEvolutionStage(
      index: 17,
      series: '森語女神',
      name: '森律女神',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '以生命寶石、金色花冠與森林神性完成的自律幣角色最終型態。',
      characterAsset: 'assets/avatar/characters/character_17.png',
      iconAsset: 'assets/avatar/icons/icon_17.png',
    ),
  ];

  static List<AvatarSeries> get series {
    return [
      AvatarSeries(
        key: 'star-traveler',
        name: '星辰旅人',
        theme: '星光自律',
        description: '以日常任務與自動追蹤累積 EXP，從星辰學徒一路成長為星耀守護者。',
        stages: evolutionStages
            .where((stage) => stage.series == '星辰旅人')
            .toList(growable: false),
      ),
      AvatarSeries(
        key: 'star-sage',
        name: '星詠魔導',
        theme: '星盤魔法',
        description: '第二位可收集角色，從眼鏡學徒進化成掌握星盤與星杖的大魔導。',
        stages: evolutionStages
            .where((stage) => stage.series == '星詠魔導')
            .toList(growable: false),
      ),
      AvatarSeries(
        key: 'flame-fighter',
        name: '焰心鬥士',
        theme: '烈焰行動',
        description: '第三位可收集角色，從焰心新星一路成長為與赤龍同行的赤龍焰姬。',
        stages: evolutionStages
            .where((stage) => stage.series == '焰心鬥士')
            .toList(growable: false),
      ),
      AvatarSeries(
        key: 'rose-academy',
        name: '玫瑰學院',
        theme: '薔薇成長',
        description: '第四位可收集角色，從玫瑰書生一路成長為手持玫瑰長弓的緋玫守護者。',
        stages: evolutionStages
            .where((stage) => stage.series == '玫瑰學院')
            .toList(growable: false),
      ),
      AvatarSeries(
        key: 'moon-shadow',
        name: '月影忍者',
        theme: '月光專注',
        description: '自律幣購買角色，從月影見習忍進化為掌握深度專注節奏的蒼月隱曜忍。',
        stages: evolutionStages
            .where((stage) => stage.series == '月影忍者')
            .toList(growable: false),
      ),
      AvatarSeries(
        key: 'forest-goddess',
        name: '森語女神',
        theme: '森林恢復',
        description: '自律幣購買角色，從森芽靈童進化為象徵健康、恢復與生命成長的森律女神。',
        stages: evolutionStages
            .where((stage) => stage.series == '森語女神')
            .toList(growable: false),
      ),
    ];
  }

  static List<String> faceShapeLabels = [
    '星辰學徒',
    '星光魔導士',
    '星耀守護者',
    '星詠見習生',
    '星杖魔導士',
    '星穹大魔導',
    '焰心新星',
    '烈焰拳士',
    '赤龍焰姬',
    '玫瑰書生',
    '薔薇遊俠',
    '緋玫守護者',
    '月影見習忍',
    '月輪影步者',
    '蒼月隱曜忍',
    '森芽靈童',
    '森語祝福者',
    '森律女神',
  ];

  // Future layered-avatar expansion. These labels stay here so older saved
  // profiles can still be normalized, but the current shop/editor only exposes
  // complete character images.
  static const List<String> hairStyleLabels = ['夜色短髮'];

  static const List<String> eyeStyleLabels = ['閃亮圓眼'];

  static const List<String> eyebrowStyleLabels = ['自然眉'];

  static const List<String> mouthStyleLabels = ['溫柔微笑'];

  static const List<String> outfitStyleLabels = [
    '基礎內搭',
    '粉紫日常套裝',
    '夜讀連帽套裝',
    '薄荷晨讀套裝',
    '暖陽行動套裝',
    '粉莓專注套裝',
    '森林自律套裝',
  ];

  static const List<String> accessoryLabels = ['無配件', '金色星光', '藍色星光', '粉色星光'];

  static List<AvatarPartCategory> editorCategories = [
    AvatarPartCategory(
      key: 'faceShape',
      title: '角色',
      hint: '選擇已購買的完整角色造型。部件換裝會先放到未來發展。',
      icon: Icons.face_retouching_natural_outlined,
      labels: faceShapeLabels,
      requiresUnlock: true,
    ),
  ];

  static List<AvatarPartCategory> get shopCategories {
    return editorCategories
        .where((category) => category.appearsInShop)
        .toList(growable: false);
  }

  static AvatarPartCategory categoryFor(String key) {
    return editorCategories.firstWhere((category) => category.key == key);
  }

  static String labelFor(String key, int index) {
    return categoryFor(key).labelFor(index);
  }

  static AvatarEvolutionStage stageForIndex(int index) {
    return evolutionStages.firstWhere(
      (stage) => stage.index == index,
      orElse: () => evolutionStages.first,
    );
  }

  static String characterAssetForIndex(int index) {
    return stageForIndex(index).characterAsset;
  }

  static String iconAssetForIndex(int index) {
    return stageForIndex(index).iconAsset;
  }

  static void addDynamicStage(AvatarEvolutionStage stage) {
    // Convert to growable if it's currently fixed-length or unmodifiable
    try {
      evolutionStages.add(stage);
    } catch (_) {
      evolutionStages = List<AvatarEvolutionStage>.from(evolutionStages)..add(stage);
    }
    
    try {
      if (!faceShapeLabels.contains(stage.name)) {
        faceShapeLabels.add(stage.name);
      }
    } catch (_) {
      faceShapeLabels = List<String>.from(faceShapeLabels);
      if (!faceShapeLabels.contains(stage.name)) {
        faceShapeLabels.add(stage.name);
      }
    }
  }
}
