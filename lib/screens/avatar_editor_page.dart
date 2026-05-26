import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'avatar_evolution_page.dart';
import 'avatar_shop_page.dart';

class AvatarEditorPage extends StatefulWidget {
  const AvatarEditorPage({super.key});

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  late AvatarProfile draft;
  late AvatarProfile original;
  bool _initialized = false;
  int selectedCategoryIndex = 0;

  late final List<AvatarPartCategory> categories =
      AvatarCatalog.editorCategories;

  @override
  void initState() {
    super.initState();
    original = AvatarProfile.initial();
    draft = AvatarProfile.initial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    original = context.read<AppState>().avatarProfile;
    draft = original;
    _initialized = true;
  }

  int _currentIndexFor(String category) {
    switch (category) {
      case 'faceShape':
        return draft.faceShapeIndex;
      case 'skinTone':
        return draft.skinToneIndex;
      case 'hairStyle':
        return draft.hairStyleIndex;
      case 'hairColor':
        return draft.hairColorIndex;
      case 'eyeStyle':
        return draft.eyeStyleIndex;
      case 'eyebrowStyle':
        return draft.eyebrowStyleIndex;
      case 'mouthStyle':
        return draft.mouthStyleIndex;
      case 'outfitStyle':
        return draft.outfitStyleIndex;
      case 'outfitColor':
        return draft.outfitColorIndex;
      case 'accessory':
        return draft.accessoryIndex;
      case 'backgroundColor':
        return draft.backgroundColorIndex;
      default:
        return 0;
    }
  }

  AvatarProfile _applyItem(AvatarProfile base, String category, int index) {
    switch (category) {
      case 'faceShape':
        return base.copyWith(faceShapeIndex: index);
      case 'skinTone':
        return base.copyWith(skinToneIndex: index);
      case 'hairStyle':
        return base.copyWith(hairStyleIndex: index);
      case 'hairColor':
        return base.copyWith(hairColorIndex: index);
      case 'eyeStyle':
        return base.copyWith(eyeStyleIndex: index);
      case 'eyebrowStyle':
        return base.copyWith(eyebrowStyleIndex: index);
      case 'mouthStyle':
        return base.copyWith(mouthStyleIndex: index);
      case 'outfitStyle':
        return base.copyWith(outfitStyleIndex: index);
      case 'outfitColor':
        return base.copyWith(outfitColorIndex: index);
      case 'accessory':
        return base.copyWith(accessoryIndex: index);
      case 'backgroundColor':
        return base.copyWith(backgroundColorIndex: index);
      default:
        return base;
    }
  }

  bool _isUnlocked(AppState appState, AvatarPartCategory category, int index) {
    if (!category.requiresUnlock) return true;
    return appState.isAvatarItemUnlocked(category.key, index);
  }

  Future<void> _openShop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AvatarShopPage()),
    );
    if (mounted) {
      setState(() {
        original = context.read<AppState>().avatarProfile;
        draft = original;
      });
    }
  }

  Future<void> _openEvolutionGuide() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AvatarEvolutionPage()),
    );
    if (!mounted) return;
    setState(() {
      original = context.read<AppState>().avatarProfile;
      draft = original;
    });
  }

  Future<void> _saveLook() async {
    await context.read<AppState>().updateAvatarProfile(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已套用角色')));
    Navigator.pop(context);
  }

  void _showLockedHint(AvatarPartCategory category, int index) {
    final appState = context.read<AppState>();
    final requirement = appState.avatarEvolutionRequirementText(index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${category.labelFor(index)} 尚未進化解鎖，$requirement。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final selectedCategory = categories[selectedCategoryIndex];
    final height = MediaQuery.sizeOf(context).height;
    final drawerHeight = (height * 0.58).clamp(430.0, 550.0);
    final avatarSize = (height * 0.24).clamp(160.0, 202.0);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111827)
          : const Color(0xFFE7F6F2),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? const [Color(0xFF0F172A), Color(0xFF12312D)]
                        : const [Color(0xFF55C7EE), Color(0xFFA8E6A2)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
            ),
            Positioned(
              top: 13,
              left: 52,
              child: Text(
                '我的角色',
                style: TextStyle(
                  color: AppUI.textPrimaryOf(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '進化路線',
                    onPressed: _openEvolutionGuide,
                    icon: const Icon(Icons.auto_graph_rounded),
                  ),
                  IconButton(
                    tooltip: '造型商城',
                    onPressed: _openShop,
                    icon: const Icon(Icons.storefront_outlined),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 58,
              right: 18,
              child: _EditorCoinBadge(coins: appState.disciplineCoins),
            ),
            Positioned(
              top: 74,
              left: 0,
              right: 0,
              bottom: drawerHeight - 20,
              child: Center(
                child: AvatarPreview(
                  profile: draft,
                  size: avatarSize,
                  showBackgroundRing: false,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _DressDrawer(
                height: drawerHeight,
                categories: categories,
                selectedCategoryIndex: selectedCategoryIndex,
                selectedCategory: selectedCategory,
                currentIndex: _currentIndexFor(selectedCategory.key),
                accentColor: accentColor,
                draft: draft,
                original: original,
                isUnlocked: (index) =>
                    _isUnlocked(appState, selectedCategory, index),
                onCategoryChanged: (index) {
                  setState(() => selectedCategoryIndex = index);
                },
                onItemTap: (index) {
                  if (!_isUnlocked(appState, selectedCategory, index)) {
                    _showLockedHint(selectedCategory, index);
                    return;
                  }
                  setState(() {
                    draft = _applyItem(draft, selectedCategory.key, index);
                  });
                },
                previewBuilder: (index) =>
                    _applyItem(draft, selectedCategory.key, index),
                onReset: () => setState(() => draft = original),
                onSave: _saveLook,
                onOpenShop: _openShop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCoinBadge extends StatelessWidget {
  final int coins;

  const _EditorCoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    final isDark = AppUI.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Color(0xFFD6A21B), size: 20),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: TextStyle(
              color: AppUI.textPrimaryOf(context),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DressDrawer extends StatelessWidget {
  final double height;
  final List<AvatarPartCategory> categories;
  final int selectedCategoryIndex;
  final AvatarPartCategory selectedCategory;
  final int currentIndex;
  final Color accentColor;
  final AvatarProfile draft;
  final AvatarProfile original;
  final bool Function(int) isUnlocked;
  final ValueChanged<int> onCategoryChanged;
  final ValueChanged<int> onItemTap;
  final AvatarProfile Function(int) previewBuilder;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final VoidCallback onOpenShop;

  const _DressDrawer({
    required this.height,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.selectedCategory,
    required this.currentIndex,
    required this.accentColor,
    required this.draft,
    required this.original,
    required this.isUnlocked,
    required this.onCategoryChanged,
    required this.onItemTap,
    required this.previewBuilder,
    required this.onReset,
    required this.onSave,
    required this.onOpenShop,
  });

  bool get hasChanges =>
      draft.toJson().toString() != original.toJson().toString();

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);
    final tileColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final mutedColor = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.74);
    final ownedCount = List<int>.generate(
      selectedCategory.itemCount,
      (index) => index,
    ).where(isUnlocked).length;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: secondaryText.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '選擇角色',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = index == selectedCategoryIndex;
                return GestureDetector(
                  onTap: () => onCategoryChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 66,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withValues(alpha: isDark ? 0.18 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? accentColor.withValues(alpha: 0.42)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: selected ? accentColor : secondaryText,
                          size: 24,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? accentColor : secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: _CategoryDetailHeader(
              category: selectedCategory,
              currentLabel: selectedCategory.labelFor(currentIndex),
              ownedText: selectedCategory.requiresUnlock
                  ? '已擁有 $ownedCount / ${selectedCategory.itemCount}'
                  : '可自由調整',
              accentColor: accentColor,
              onOpenShop: onOpenShop,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
              itemCount: selectedCategory.itemCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final unlocked = isUnlocked(index);
                final selected = index == currentIndex;
                final color = selectedCategory.colors?[index];
                return GestureDetector(
                  onTap: () => onItemTap(index),
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: selected ? tileColor : mutedColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? accentColor
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.42),
                              width: selected ? 2 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.30 : 0.15,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 7),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: color == null
                                    ? AvatarPreview(
                                        profile: previewBuilder(index),
                                        size: 58,
                                        showBackgroundRing: false,
                                      )
                                    : _ColorPreview(color: color),
                              ),
                              if (!unlocked)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).cardColor.withValues(alpha: 0.62),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.lock_outline,
                                      color: secondaryText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (selected)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: accentColor,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedCategory.labelFor(index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? accentColor
                              : unlocked
                              ? primaryText
                              : secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.96),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: hasChanges ? onReset : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('取消預覽'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: hasChanges ? onSave : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('套用角色'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPreview extends StatelessWidget {
  final Color color;

  const _ColorPreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppUI.isDark(context)
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _CategoryDetailHeader extends StatelessWidget {
  final AvatarPartCategory category;
  final String currentLabel;
  final String ownedText;
  final Color accentColor;
  final VoidCallback onOpenShop;

  const _CategoryDetailHeader({
    required this.category,
    required this.currentLabel,
    required this.ownedText,
    required this.accentColor,
    required this.onOpenShop,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final appState = context.watch<AppState>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: accentColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.hint,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onOpenShop, child: const Text('造型商城')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EditorInfoPill(
                label: '目前',
                value: currentLabel,
                color: accentColor,
              ),
              _EditorInfoPill(
                label: category.requiresUnlock ? '收藏' : '狀態',
                value: ownedText,
                color: category.requiresUnlock ? AppUI.orange : AppUI.green,
              ),
              _EditorInfoPill(
                label: '角色等級',
                value:
                    'Lv.${appState.avatarLevel} / ${appState.avatarExperience} EXP',
                color: AppUI.green,
              ),
              _EditorInfoPill(
                label: appState.avatarLevel >= AppState.avatarMaxLevel
                    ? '已滿等'
                    : '下一等',
                value: appState.avatarLevel >= AppState.avatarMaxLevel
                    ? 'Lv.${AppState.avatarMaxLevel}'
                    : '還差 ${appState.avatarExperienceToNextLevel} EXP',
                color: AppUI.purple,
              ),
              _EditorInfoPill(
                label: '任務 EXP',
                value:
                    '+${appState.todayAvatarScoreExperience}/${AppState.avatarDailyScoreExperienceCap}',
                color: AppUI.blue,
              ),
              _EditorInfoPill(
                label: '偵測 EXP',
                value:
                    '+${appState.todayAvatarAutoExperience}/${AppState.avatarDailyAutoExperienceCap}',
                color: AppUI.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EditorInfoPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppUI.isDark(context) ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
