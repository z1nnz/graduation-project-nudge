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

class AvatarCatalog {
  static const List<String> faceShapeLabels = ['男生', '女生'];

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
      hint: '先選男生或女生角色，讓換裝系統保持簡單穩定。',
      icon: Icons.face_outlined,
      labels: faceShapeLabels,
      requiresUnlock: false,
      appearsInShop: false,
    ),
    AvatarPartCategory(
      key: 'outfitStyle',
      title: '服裝',
      hint: '選擇完整套裝，買完就能直接回來穿。',
      icon: Icons.checkroom_outlined,
      labels: outfitStyleLabels,
    ),
    AvatarPartCategory(
      key: 'accessory',
      title: '配件',
      hint: '加上星星、耳機、眼鏡等小配件，讓角色更有個性。',
      icon: Icons.auto_awesome_outlined,
      labels: accessoryLabels,
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
}
