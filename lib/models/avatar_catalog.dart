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

  const AvatarEvolutionStage({
    required this.index,
    required this.series,
    required this.name,
    required this.stage,
    required this.requiredLevel,
    required this.requiredExperience,
    required this.description,
  });

  String get stageLabel => '第 $stage 階';
}

class AvatarCatalog {
  static const List<AvatarEvolutionStage> evolutionStages = [
    AvatarEvolutionStage(
      index: 0,
      series: '晨光夥伴',
      name: '晨光練習生',
      stage: 1,
      requiredLevel: 1,
      requiredExperience: 0,
      description: '剛開始陪你建立自律節奏的基礎型態。',
    ),
    AvatarEvolutionStage(
      index: 1,
      series: '晨光夥伴',
      name: '星光少女',
      stage: 2,
      requiredLevel: 30,
      requiredExperience: 10000,
      description: '連續累積約 20 天滿額經驗後解鎖的進階造型。',
    ),
    AvatarEvolutionStage(
      index: 2,
      series: '晨光夥伴',
      name: '星耀守護者',
      stage: 3,
      requiredLevel: 60,
      requiredExperience: 30000,
      description: '長期穩定累積約 60 天滿額經驗後解鎖的最終造型。',
    ),
  ];

  static const List<String> faceShapeLabels = ['晨光練習生', '星光少女', '星耀守護者'];

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

  static const List<AvatarPartCategory> editorCategories = [
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
}
