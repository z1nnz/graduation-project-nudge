import 'package:flutter/material.dart';

import 'avatar_profile.dart';

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
  static const List<String> faceShapeLabels = [
    '圓臉',
    '鵝蛋臉',
    '方臉',
    '小臉',
    '柔和臉',
    '俐落臉',
  ];

  static const List<String> hairStyleLabels = [
    '短髮',
    '微捲',
    '瀏海',
    '中分',
    '丸子頭',
    '蓬鬆短髮',
    '側分',
    '波浪長髮',
  ];

  static const List<String> eyeStyleLabels = [
    '圓眼',
    '笑眼',
    '細長眼',
    '大眼',
    '星星眼',
    '溫柔眼',
  ];

  static const List<String> eyebrowStyleLabels = [
    '自然眉',
    '粗眉',
    '上揚眉',
    '平眉',
    '柔眉',
    '俐落眉',
  ];

  static const List<String> mouthStyleLabels = [
    '微笑',
    '開心',
    '酷臉',
    '小嘴',
    '抿嘴笑',
    '驚喜',
  ];

  static const List<String> outfitStyleLabels = [
    'T-shirt',
    '帽T',
    '襯衫',
    '外套',
    '背心',
    '制服',
    '運動衫',
    '針織衫',
  ];

  static const List<String> accessoryLabels = [
    '無配件',
    '閃光',
    '耳機',
    '書本',
    '星星',
    '眼鏡',
    '蝴蝶結',
    '小背包',
  ];

  static const List<AvatarPartCategory> editorCategories = [
    AvatarPartCategory(
      key: 'faceShape',
      title: '臉型',
      hint: '調整角色的臉部輪廓，會影響整體可愛感。',
      icon: Icons.face_outlined,
      labels: faceShapeLabels,
    ),
    AvatarPartCategory(
      key: 'skinTone',
      title: '膚色',
      hint: '選擇角色的膚色，這一類不需要商城解鎖。',
      icon: Icons.palette_outlined,
      labels: ['膚色 1', '膚色 2', '膚色 3', '膚色 4', '膚色 5', '膚色 6'],
      colors: AvatarProfile.skinTones,
      requiresUnlock: false,
      appearsInShop: false,
    ),
    AvatarPartCategory(
      key: 'hairStyle',
      title: '髮型',
      hint: '切換前髮與後髮輪廓，是角色辨識度最高的部位。',
      icon: Icons.face_retouching_natural_outlined,
      labels: hairStyleLabels,
    ),
    AvatarPartCategory(
      key: 'hairColor',
      title: '髮色',
      hint: '調整頭髮顏色，讓角色風格更明顯。',
      icon: Icons.color_lens_outlined,
      labels: ['髮色 1', '髮色 2', '髮色 3', '髮色 4', '髮色 5', '髮色 6', '髮色 7', '髮色 8'],
      colors: AvatarProfile.hairColors,
      requiresUnlock: false,
      appearsInShop: false,
    ),
    AvatarPartCategory(
      key: 'eyeStyle',
      title: '眼睛',
      hint: '選擇眼睛形狀，會直接影響角色表情。',
      icon: Icons.visibility_outlined,
      labels: eyeStyleLabels,
    ),
    AvatarPartCategory(
      key: 'eyebrowStyle',
      title: '眉毛',
      hint: '調整眉毛角度與粗細，讓角色看起來更溫柔或更有精神。',
      icon: Icons.remove_red_eye_outlined,
      labels: eyebrowStyleLabels,
    ),
    AvatarPartCategory(
      key: 'mouthStyle',
      title: '嘴巴',
      hint: '切換笑臉、酷臉或小嘴，決定角色的情緒。',
      icon: Icons.tag_faces_outlined,
      labels: mouthStyleLabels,
    ),
    AvatarPartCategory(
      key: 'outfitStyle',
      title: '上身',
      hint: '選擇上衣版型，商城解鎖後可以在這裡直接試穿。',
      icon: Icons.checkroom_outlined,
      labels: outfitStyleLabels,
    ),
    AvatarPartCategory(
      key: 'outfitColor',
      title: '衣色',
      hint: '調整服裝主色，這一類不需要商城解鎖。',
      icon: Icons.format_color_fill_outlined,
      labels: ['衣色 1', '衣色 2', '衣色 3', '衣色 4', '衣色 5', '衣色 6', '衣色 7', '衣色 8'],
      colors: AvatarProfile.outfitColors,
      requiresUnlock: false,
      appearsInShop: false,
    ),
    AvatarPartCategory(
      key: 'accessory',
      title: '配件',
      hint: '加上星星、耳機、眼鏡等小配件，讓角色更有個性。',
      icon: Icons.auto_awesome_outlined,
      labels: accessoryLabels,
    ),
    AvatarPartCategory(
      key: 'backgroundColor',
      title: '背景',
      hint: '設定角色展示背景，會出現在好友頁與名片預覽中。',
      icon: Icons.wallpaper_outlined,
      labels: ['背景 1', '背景 2', '背景 3', '背景 4', '背景 5', '背景 6', '背景 7', '背景 8'],
      colors: AvatarProfile.backgroundColors,
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
