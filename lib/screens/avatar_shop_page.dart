import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'avatar_evolution_page.dart';
import 'my_profile_page.dart';

class AvatarShopPage extends StatefulWidget {
  const AvatarShopPage({super.key});

  @override
  State<AvatarShopPage> createState() => _AvatarShopPageState();
}

enum _ShopRarity { all, basic, rare, epic }

enum _ShopShelf { characters, backgrounds }

class _ShopSet {
  final String title;
  final String description;
  final IconData icon;
  final List<MapEntry<String, int>> items;

  const _ShopSet({
    required this.title,
    required this.description,
    required this.icon,
    required this.items,
  });
}

class _CheckoutLine {
  final String category;
  final String name;
  final int price;

  const _CheckoutLine({
    required this.category,
    required this.name,
    required this.price,
  });
}

class _AvatarShopPageState extends State<AvatarShopPage> {
  static const double _drawerMinExtent = 0.46;
  static const double _drawerMaxExtent = 0.74;

  late AvatarProfile draft;
  late AvatarProfile original;
  String draftBackgroundThemeKey = 'softGlow';
  String originalBackgroundThemeKey = 'softGlow';
  bool _initialized = false;
  bool _isDraggingDrawer = false;
  double _drawerExtent = _drawerMinExtent;
  _ShopShelf selectedShelf = _ShopShelf.characters;
  int selectedCategoryIndex = 0;
  bool showOwnedOnly = false;
  bool showSetsOnly = false;
  String shopQuery = '';
  _ShopRarity selectedRarity = _ShopRarity.all;

  late final List<_ShopSet> shopSets = [
    const _ShopSet(
      title: '星辰學徒',
      description: '初始角色，可套用到名片、好友公開頁與自律房。',
      icon: Icons.wb_sunny_outlined,
      items: [MapEntry('faceShape', 0)],
    ),
    const _ShopSet(
      title: '星詠魔導',
      description: '第二位三階段角色，從見習生一路進化成星穹大魔導。',
      icon: Icons.auto_awesome_outlined,
      items: [MapEntry('faceShape', 3)],
    ),
    const _ShopSet(
      title: '焰心鬥士',
      description: '第三位火焰系三階段角色，從焰心新星進化成赤龍焰姬。',
      icon: Icons.local_fire_department_outlined,
      items: [MapEntry('faceShape', 6)],
    ),
    const _ShopSet(
      title: '玫瑰學院',
      description: '第四位薔薇系三階段角色，從玫瑰書生進化成緋玫守護者。',
      icon: Icons.local_florist_outlined,
      items: [MapEntry('faceShape', 9)],
    ),
    const _ShopSet(
      title: '月影忍者',
      description: '自律幣購買角色，從月影見習忍進化成蒼月隱曜忍。',
      icon: Icons.nightlight_round,
      items: [MapEntry('faceShape', 12)],
    ),
    const _ShopSet(
      title: '森語女神',
      description: '自律幣購買角色，從森芽靈童進化成森律女神。',
      icon: Icons.eco_outlined,
      items: [MapEntry('faceShape', 15)],
    ),
  ];

  late final List<AvatarPartCategory> categories = AvatarCatalog.shopCategories;

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
    final appState = context.read<AppState>();
    original = appState.avatarProfile;
    draft = original;
    originalBackgroundThemeKey = appState.backgroundThemeSetting;
    draftBackgroundThemeKey = originalBackgroundThemeKey;
    _initialized = true;
  }

  int _currentIndexFor(String category) {
    switch (category) {
      case 'faceShape':
        return draft.faceShapeIndex;
      default:
        return 0;
    }
  }

  double _lerp(double begin, double end, double progress) {
    return begin + ((end - begin) * progress);
  }

  double _drawerHeightFor(double height) {
    final rawHeight = height * _drawerExtent;
    final minHeight = (height * _drawerMinExtent)
        .clamp(320.0, 430.0)
        .toDouble();
    final maxAvailableHeight = (height - 86.0)
        .clamp(minHeight, height)
        .toDouble();
    final maxHeight = (height * _drawerMaxExtent)
        .clamp(minHeight, maxAvailableHeight)
        .toDouble();
    return rawHeight.clamp(minHeight, maxHeight).toDouble();
  }

  double _drawerProgress() {
    return ((_drawerExtent - _drawerMinExtent) /
            (_drawerMaxExtent - _drawerMinExtent))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _previewSizeFor(double height) {
    final progress = _drawerProgress();
    final expandedSize = (height * 0.36).clamp(220.0, 286.0).toDouble();
    final compactSize = (height * 0.22).clamp(132.0, 178.0).toDouble();
    return _lerp(expandedSize, compactSize, progress);
  }

  void _updateDrawerExtent(DragUpdateDetails details, double height) {
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _isDraggingDrawer = true;
      _drawerExtent = (_drawerExtent - (delta / height))
          .clamp(_drawerMinExtent, _drawerMaxExtent)
          .toDouble();
    });
  }

  void _settleDrawerExtent(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final nextExtent = velocity < -240
        ? _drawerMaxExtent
        : velocity > 240
        ? _drawerMinExtent
        : _drawerProgress() >= 0.48
        ? _drawerMaxExtent
        : _drawerMinExtent;
    setState(() {
      _isDraggingDrawer = false;
      _drawerExtent = nextExtent;
    });
  }

  AvatarProfile _applyItem(AvatarProfile base, String category, int index) {
    switch (category) {
      case 'faceShape':
        return base.copyWith(faceShapeIndex: index);
      default:
        return base;
    }
  }

  bool _isPurchasableLockedCharacter(AppState appState, int index) {
    final stage = AvatarCatalog.stageForIndex(index);
    return stage.stage == 1 &&
        stage.coinPrice > 0 &&
        !appState.isAvatarItemUnlocked('faceShape', index);
  }

  List<MapEntry<String, int>> _selectedItems() {
    return [MapEntry('faceShape', draft.faceShapeIndex)];
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

  Future<void> _openMyProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyProfilePage()),
    );
  }

  int _checkoutPrice(AppState appState) {
    var total = 0;
    for (final item in _selectedItems()) {
      if (!appState.isAvatarItemUnlocked(item.key, item.value)) {
        total += appState.avatarItemPrice(item.key, item.value);
      }
    }
    return total;
  }

  int _backgroundCheckoutPrice(AppState appState) {
    final index = AppUI.backgroundThemeKeys.indexOf(draftBackgroundThemeKey);
    if (index < 0 || appState.isAvatarItemUnlocked('appBackground', index)) {
      return 0;
    }
    return appState.avatarItemPrice('appBackground', index);
  }

  List<_CheckoutLine> _checkoutLines(AppState appState) {
    final lines = <_CheckoutLine>[];
    for (final item in _selectedItems()) {
      if (appState.isAvatarItemUnlocked(item.key, item.value)) continue;

      final category = categories.firstWhere(
        (category) => category.key == item.key,
      );
      lines.add(
        _CheckoutLine(
          category: category.title,
          name: category.labelFor(item.value),
          price: appState.avatarItemPrice(item.key, item.value),
        ),
      );
    }
    return lines;
  }

  void _applySet(_ShopSet set) {
    final appState = context.read<AppState>();
    MapEntry<String, int>? lockedItem;
    for (final item in set.items) {
      if (!appState.isAvatarItemUnlocked(item.key, item.value)) {
        lockedItem = item;
        break;
      }
    }
    if (lockedItem != null) {
      if (lockedItem.key == 'faceShape' &&
          _isPurchasableLockedCharacter(appState, lockedItem.value)) {
        setState(() {
          for (final item in set.items) {
            draft = _applyItem(draft, item.key, item.value);
          }
        });
        return;
      }
      final category = AvatarCatalog.categoryFor(lockedItem.key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${category.labelFor(lockedItem.value)} 需要 ${appState.avatarEvolutionRequirementText(lockedItem.value)}。',
          ),
        ),
      );
      return;
    }
    setState(() {
      for (final item in set.items) {
        draft = _applyItem(draft, item.key, item.value);
      }
    });
  }

  Future<void> _saveLook() async {
    final appState = context.read<AppState>();
    final totalPrice = _checkoutPrice(appState);
    final checkoutLines = _checkoutLines(appState);

    if (appState.disciplineCoins < totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('自律幣不足，還需要 ${totalPrice - appState.disciplineCoins} 枚'),
        ),
      );
      return;
    }

    if (totalPrice > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('確認購買角色'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('這次會購買 ${checkoutLines.length} 個尚未擁有的角色。'),
                const SizedBox(height: 12),
                ...checkoutLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.category}｜${line.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${line.price} 枚',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 18),
                Text(
                  '合計 $totalPrice 枚自律幣',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('購買並套用'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    for (final item in _selectedItems()) {
      if (!appState.isAvatarItemUnlocked(item.key, item.value)) {
        final purchased = await appState.purchaseAvatarItem(
          item.key,
          item.value,
        );
        if (!purchased) return;
      }
    }

    await appState.updateAvatarProfile(draft);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalPrice > 0
                ? '已購買並套用角色，社交頁、排行榜與自律房會同步展示'
                : '已套用角色，社交頁、排行榜與自律房會同步展示',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveBackgroundTheme() async {
    final appState = context.read<AppState>();
    final index = AppUI.backgroundThemeKeys.indexOf(draftBackgroundThemeKey);
    if (index < 0) return;

    final totalPrice = _backgroundCheckoutPrice(appState);
    final themeName = AppUI.backgroundThemeLabel(draftBackgroundThemeKey);

    if (appState.disciplineCoins < totalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('自律幣不足，還需要 ${totalPrice - appState.disciplineCoins} 枚'),
        ),
      );
      return;
    }

    if (totalPrice > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('確認購買背景主題'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('這次會購買並套用「$themeName」。'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppUI.backgroundThemeDescription(
                          draftBackgroundThemeKey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$totalPrice 枚',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('購買並套用'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    if (!appState.isAvatarItemUnlocked('appBackground', index)) {
      final purchased = await appState.purchaseAvatarItem(
        'appBackground',
        index,
      );
      if (!purchased) return;
    }

    await appState.setBackgroundThemeSetting(draftBackgroundThemeKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalPrice > 0 ? '已購買並套用 $themeName' : '已套用 $themeName',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedCategory = categories[selectedCategoryIndex];
    final accentColor = appState.currentIconColor;
    final totalPrice = _checkoutPrice(appState);

    return Scaffold(
      backgroundColor: AppUI.isDark(context)
          ? const Color(0xFF111827)
          : const Color(0xFFE7F6F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final drawerHeight = _drawerHeightFor(height);
            final avatarSize = _previewSizeFor(height);
            final drawerProgress = _drawerProgress();
            final previewTop = _lerp(50.0, 42.0, drawerProgress);
            final badgeTop = _lerp(88.0, 68.0, drawerProgress);
            final animationDuration = _isDraggingDrawer
                ? Duration.zero
                : const Duration(milliseconds: 220);
            final draftStage = AvatarCatalog.stageForIndex(
              draft.faceShapeIndex,
            );
            final draftOwned = appState.isAvatarItemUnlocked(
              'faceShape',
              draft.faceShapeIndex,
            );
            final previewThemeKey = selectedShelf == _ShopShelf.backgrounds
                ? draftBackgroundThemeKey
                : appState.backgroundThemeSetting;
            final backgroundColors = AppUI.backgroundThemeColors(
              previewThemeKey,
              AppUI.isDark(context),
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: backgroundColors,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 12,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '造型商城',
                        style: TextStyle(
                          color: AppUI.textPrimaryOf(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '進化路線',
                        onPressed: _openEvolutionGuide,
                        icon: const Icon(Icons.auto_graph_rounded),
                      ),
                      const SizedBox(width: 4),
                      _CoinBadge(coins: appState.disciplineCoins),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  top: previewTop,
                  left: 0,
                  right: 0,
                  bottom: drawerHeight - 6,
                  child: Center(
                    child: selectedShelf == _ShopShelf.backgrounds
                        ? _BackgroundHeroPreview(
                            themeKey: draftBackgroundThemeKey,
                            size: avatarSize,
                            profile: draft,
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openMyProfile,
                            child: AvatarPreview(
                              profile: draft,
                              size: avatarSize,
                              showBackgroundRing: false,
                            ),
                          ),
                  ),
                ),
                if (selectedShelf == _ShopShelf.characters)
                  AnimatedPositioned(
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    left: 18,
                    top: badgeTop,
                    child: _PreviewStageBadge(
                      stage: draftStage,
                      owned: draftOwned,
                      accentColor: accentColor,
                    ),
                  ),
                if (selectedShelf == _ShopShelf.backgrounds)
                  AnimatedPositioned(
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    left: 18,
                    top: badgeTop,
                    child: _PreviewBackgroundBadge(
                      themeKey: draftBackgroundThemeKey,
                      owned: appState.isAvatarItemUnlocked(
                        'appBackground',
                        AppUI.backgroundThemeKeys.indexOf(
                          draftBackgroundThemeKey,
                        ),
                      ),
                      accentColor: accentColor,
                    ),
                  ),
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: selectedShelf == _ShopShelf.backgrounds
                      ? _BackgroundThemeDrawer(
                          height: drawerHeight,
                          onDrawerDragUpdate: (details) =>
                              _updateDrawerExtent(details, height),
                          onDrawerDragEnd: _settleDrawerExtent,
                          selectedShelf: selectedShelf,
                          onShelfChanged: (shelf) {
                            setState(() {
                              selectedShelf = shelf;
                            });
                          },
                          currentThemeKey: appState.backgroundThemeSetting,
                          draftThemeKey: draftBackgroundThemeKey,
                          accentColor: accentColor,
                          onThemeTap: (themeKey) {
                            setState(() {
                              draftBackgroundThemeKey = themeKey;
                            });
                          },
                          totalPrice: _backgroundCheckoutPrice(appState),
                          onReset: () {
                            setState(() {
                              draftBackgroundThemeKey =
                                  originalBackgroundThemeKey;
                            });
                          },
                          onSave: _saveBackgroundTheme,
                        )
                      : _ShopDrawer(
                          height: drawerHeight,
                          onDrawerDragUpdate: (details) =>
                              _updateDrawerExtent(details, height),
                          onDrawerDragEnd: _settleDrawerExtent,
                          selectedShelf: selectedShelf,
                          onShelfChanged: (shelf) {
                            setState(() {
                              selectedShelf = shelf;
                            });
                          },
                          categories: categories,
                          selectedCategoryIndex: selectedCategoryIndex,
                          onCategoryChanged: (index) {
                            setState(() {
                              selectedCategoryIndex = index;
                            });
                          },
                          showOwnedOnly: showOwnedOnly,
                          onOwnedOnlyChanged: (value) {
                            setState(() {
                              showOwnedOnly = value;
                            });
                          },
                          showSetsOnly: showSetsOnly,
                          onSetsOnlyChanged: (value) {
                            setState(() {
                              showSetsOnly = value;
                            });
                          },
                          searchQuery: shopQuery,
                          onSearchChanged: (value) {
                            setState(() {
                              shopQuery = value;
                            });
                          },
                          selectedRarity: selectedRarity,
                          onRarityChanged: (value) {
                            setState(() {
                              selectedRarity = value;
                            });
                          },
                          shopSets: shopSets,
                          onSetTap: _applySet,
                          selectedCategory: selectedCategory,
                          currentIndex: _currentIndexFor(selectedCategory.key),
                          accentColor: accentColor,
                          onItemTap: (index) {
                            if (!appState.isAvatarItemUnlocked(
                              selectedCategory.key,
                              index,
                            )) {
                              if (selectedCategory.key == 'faceShape' &&
                                  _isPurchasableLockedCharacter(
                                    appState,
                                    index,
                                  )) {
                                setState(() {
                                  draft = _applyItem(
                                    draft,
                                    selectedCategory.key,
                                    index,
                                  );
                                });
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${selectedCategory.labelFor(index)} 需要 ${appState.avatarEvolutionRequirementText(index)}。',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              draft = _applyItem(
                                draft,
                                selectedCategory.key,
                                index,
                              );
                            });
                          },
                          previewBuilder: (index) =>
                              _applyItem(draft, selectedCategory.key, index),
                          totalPrice: totalPrice,
                          onReset: () {
                            setState(() {
                              draft = original;
                            });
                          },
                          onSave: _saveLook,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShopFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final isDark = AppUI.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.radiusPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: isDark ? 0.24 : 0.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppUI.radiusPill),
          border: Border.all(
            color: selected
                ? accentColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accentColor : primaryText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;

  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    final isDark = AppUI.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F2937).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.85),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewStageBadge extends StatelessWidget {
  final AvatarEvolutionStage stage;
  final bool owned;
  final Color accentColor;

  const _PreviewStageBadge({
    required this.stage,
    required this.owned,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final color = owned ? AppUI.green : AppUI.orange;

    return Container(
      constraints: const BoxConstraints(maxWidth: 178),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppUI.isDark(context) ? 0.28 : 0.10,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage.series,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stage.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                owned ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                owned ? '可套用' : '待解鎖',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBackgroundBadge extends StatelessWidget {
  final String themeKey;
  final bool owned;
  final Color accentColor;

  const _PreviewBackgroundBadge({
    required this.themeKey,
    required this.owned,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final color = owned ? AppUI.green : AppUI.orange;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppUI.isDark(context) ? 0.28 : 0.10,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '背景主題',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            AppUI.backgroundThemeLabel(themeKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                owned ? Icons.check_circle_rounded : Icons.lock_rounded,
                color: color,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                owned ? '可套用' : '商城解鎖',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackgroundHeroPreview extends StatelessWidget {
  final String themeKey;
  final double size;
  final AvatarProfile profile;

  const _BackgroundHeroPreview({
    required this.themeKey,
    required this.size,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppUI.backgroundThemeColors(themeKey, AppUI.isDark(context));
    final accent = colors.length > 1 ? colors[1] : AppUI.primary;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(
              alpha: AppUI.isDark(context) ? 0.30 : 0.22,
            ),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -size * 0.10,
            bottom: -size * 0.12,
            child: Icon(
              AppUI.backgroundThemeIcon(themeKey),
              size: size * 0.42,
              color: Colors.white.withValues(alpha: 0.26),
            ),
          ),
          Center(
            child: AvatarPreview(
              profile: profile,
              size: size * 0.76,
              showBackgroundRing: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopShelfSwitch extends StatelessWidget {
  final _ShopShelf selectedShelf;
  final ValueChanged<_ShopShelf> onChanged;
  final Color accentColor;

  const _ShopShelfSwitch({
    required this.selectedShelf,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? const Color(0xFF111827)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Row(
        children: [
          _ShopShelfButton(
            label: '角色',
            icon: Icons.face_retouching_natural_outlined,
            selected: selectedShelf == _ShopShelf.characters,
            accentColor: accentColor,
            onTap: () => onChanged(_ShopShelf.characters),
          ),
          _ShopShelfButton(
            label: '背景',
            icon: Icons.wallpaper_outlined,
            selected: selectedShelf == _ShopShelf.backgrounds,
            accentColor: accentColor,
            onTap: () => onChanged(_ShopShelf.backgrounds),
          ),
        ],
      ),
    );
  }
}

class _ShopShelfButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _ShopShelfButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppUI.textSecondaryOf(context),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppUI.textSecondaryOf(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerGrabber extends StatelessWidget {
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _DrawerGrabber({required this.onDragUpdate, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final secondaryText = AppUI.textSecondaryOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 7, 0, 6),
        child: Center(
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: secondaryText.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopDrawer extends StatelessWidget {
  final double height;
  final GestureDragUpdateCallback onDrawerDragUpdate;
  final GestureDragEndCallback onDrawerDragEnd;
  final _ShopShelf selectedShelf;
  final ValueChanged<_ShopShelf> onShelfChanged;
  final List<AvatarPartCategory> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategoryChanged;
  final bool showOwnedOnly;
  final ValueChanged<bool> onOwnedOnlyChanged;
  final bool showSetsOnly;
  final ValueChanged<bool> onSetsOnlyChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final _ShopRarity selectedRarity;
  final ValueChanged<_ShopRarity> onRarityChanged;
  final List<_ShopSet> shopSets;
  final ValueChanged<_ShopSet> onSetTap;
  final AvatarPartCategory selectedCategory;
  final int currentIndex;
  final Color accentColor;
  final ValueChanged<int> onItemTap;
  final AvatarProfile Function(int) previewBuilder;
  final int totalPrice;
  final VoidCallback onReset;
  final VoidCallback onSave;

  const _ShopDrawer({
    required this.height,
    required this.onDrawerDragUpdate,
    required this.onDrawerDragEnd,
    required this.selectedShelf,
    required this.onShelfChanged,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategoryChanged,
    required this.showOwnedOnly,
    required this.onOwnedOnlyChanged,
    required this.showSetsOnly,
    required this.onSetsOnlyChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedRarity,
    required this.onRarityChanged,
    required this.shopSets,
    required this.onSetTap,
    required this.selectedCategory,
    required this.currentIndex,
    required this.accentColor,
    required this.onItemTap,
    required this.previewBuilder,
    required this.totalPrice,
    required this.onReset,
    required this.onSave,
  });

  _ShopRarity _rarityForPrice(int price) {
    if (price <= 0) return _ShopRarity.basic;
    if (price <= 18) return _ShopRarity.basic;
    if (price <= 32) return _ShopRarity.rare;
    return _ShopRarity.epic;
  }

  String _rarityLabel(_ShopRarity rarity) {
    switch (rarity) {
      case _ShopRarity.all:
        return '全部稀有度';
      case _ShopRarity.basic:
        return '基本';
      case _ShopRarity.rare:
        return '稀有';
      case _ShopRarity.epic:
        return '史詩';
    }
  }

  Color _rarityColor(_ShopRarity rarity) {
    switch (rarity) {
      case _ShopRarity.all:
        return accentColor;
      case _ShopRarity.basic:
        return AppUI.green;
      case _ShopRarity.rare:
        return AppUI.blue;
      case _ShopRarity.epic:
        return AppUI.orange;
    }
  }

  List<int> _sellableIndexes(AvatarPartCategory category) {
    return List<int>.generate(category.itemCount, (index) => index)
        .where((index) => AvatarCatalog.stageForIndex(index).stage == 1)
        .toList(growable: false);
  }

  int _setPrice(AppState appState, _ShopSet set) {
    return set.items.fold<int>(0, (sum, item) {
      if (appState.isAvatarItemUnlocked(item.key, item.value)) return sum;
      return sum + appState.avatarItemPrice(item.key, item.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);
    final tileColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final tileMutedColor = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.72);
    final tileBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.transparent;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final sellableIndexes = _sellableIndexes(selectedCategory);
    final visibleIndexes = sellableIndexes
        .where((index) {
          if (!showOwnedOnly) return true;
          return appState.isAvatarItemUnlocked(selectedCategory.key, index);
        })
        .where((index) {
          final label = selectedCategory.labelFor(index).toLowerCase();
          if (normalizedQuery.isNotEmpty &&
              !label.contains(normalizedQuery) &&
              !selectedCategory.title.toLowerCase().contains(normalizedQuery)) {
            return false;
          }
          if (selectedRarity == _ShopRarity.all) return true;
          final price = appState.avatarItemPrice(selectedCategory.key, index);
          return _rarityForPrice(price) == selectedRarity;
        })
        .toList();
    final visibleSets = shopSets.where((set) {
      if (normalizedQuery.isEmpty) return true;
      return set.title.toLowerCase().contains(normalizedQuery) ||
          set.description.toLowerCase().contains(normalizedQuery);
    }).toList();
    final ownedCount = sellableIndexes.where((index) {
      return appState.isAvatarItemUnlocked(selectedCategory.key, index);
    }).length;

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
          _DrawerGrabber(
            onDragUpdate: onDrawerDragUpdate,
            onDragEnd: onDrawerDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
            child: _ShopShelfSwitch(
              selectedShelf: selectedShelf,
              onChanged: onShelfChanged,
              accentColor: accentColor,
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = index == selectedCategoryIndex;
                  return GestureDetector(
                    onTap: () => onCategoryChanged(index),
                    child: Column(
                      children: [
                        Icon(
                          category.icon,
                          color: selected ? accentColor : secondaryText,
                          size: 24,
                        ),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 30,
                          height: 3,
                          decoration: BoxDecoration(
                            color: selected ? accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else
            const SizedBox(height: 9),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: showSetsOnly ? '搜尋精選角色' : '搜尋角色',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCategory.title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '已擁有 $ownedCount / ${sellableIndexes.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _ShopFilterChip(
                  label: '全部',
                  selected: !showOwnedOnly && !showSetsOnly,
                  accentColor: accentColor,
                  onTap: () {
                    onSetsOnlyChanged(false);
                    onOwnedOnlyChanged(false);
                  },
                ),
                const SizedBox(width: 8),
                _ShopFilterChip(
                  label: '已擁有',
                  selected: showOwnedOnly && !showSetsOnly,
                  accentColor: accentColor,
                  onTap: () {
                    onSetsOnlyChanged(false);
                    onOwnedOnlyChanged(true);
                  },
                ),
                const SizedBox(width: 8),
                _ShopFilterChip(
                  label: '精選',
                  selected: showSetsOnly,
                  accentColor: accentColor,
                  onTap: () => onSetsOnlyChanged(true),
                ),
              ],
            ),
          ),
          if (!showSetsOnly)
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final rarity = _ShopRarity.values[index];
                  return _ShopFilterChip(
                    label: _rarityLabel(rarity),
                    selected: selectedRarity == rarity,
                    accentColor: _rarityColor(rarity),
                    onTap: () => onRarityChanged(rarity),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _ShopRarity.values.length,
              ),
            ),
          Expanded(
            child: showSetsOnly
                ? _ShopSetList(
                    sets: visibleSets,
                    accentColor: accentColor,
                    onSetTap: onSetTap,
                    priceForSet: (set) => _setPrice(appState, set),
                    rarityForPrice: _rarityForPrice,
                    rarityLabel: _rarityLabel,
                    rarityColor: _rarityColor,
                  )
                : visibleIndexes.isEmpty
                ? Center(
                    child: Text(
                      showOwnedOnly ? '這個分類還沒有已擁有項目' : '找不到符合條件的項目',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 3, 16, 64),
                    itemCount: visibleIndexes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.76,
                        ),
                    itemBuilder: (context, visibleIndex) {
                      final index = visibleIndexes[visibleIndex];
                      final unlocked = appState.isAvatarItemUnlocked(
                        selectedCategory.key,
                        index,
                      );
                      final selected = index == currentIndex;
                      final price = appState.avatarItemPrice(
                        selectedCategory.key,
                        index,
                      );
                      final rarity = _rarityForPrice(price);
                      final preview = previewBuilder(index);
                      return GestureDetector(
                        onTap: () => onItemTap(index),
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: selected ? tileColor : tileMutedColor,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.30 : 0.16,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 7),
                                          ),
                                        ]
                                      : null,
                                  border: Border.all(
                                    color: selected
                                        ? accentColor
                                        : tileBorderColor,
                                    width: 2,
                                  ),
                                ),
                                child: AvatarPreview(
                                  profile: preview,
                                  size: 62,
                                  showBackgroundRing: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (unlocked)
                              Text(
                                selected ? '預覽中' : '已擁有',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? accentColor : secondaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (selectedCategory.key == 'faceShape')
                              Text(
                                appState.avatarEvolutionRequirementText(index),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFB7791F),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.monetization_on,
                                    color: Color(0xFFD6A21B),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$price',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFB7791F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            Text(
                              _rarityLabel(rarity),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _rarityColor(rarity),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.94),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        foregroundColor: primaryText,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.transparent,
                        ),
                      ),
                      child: const Text('取消預覽'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        foregroundColor: accentColor,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: isDark
                              ? accentColor.withValues(alpha: 0.30)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(totalPrice > 0 ? '購買 $totalPrice' : '套用'),
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

class _BackgroundThemeDrawer extends StatelessWidget {
  final double height;
  final GestureDragUpdateCallback onDrawerDragUpdate;
  final GestureDragEndCallback onDrawerDragEnd;
  final _ShopShelf selectedShelf;
  final ValueChanged<_ShopShelf> onShelfChanged;
  final String currentThemeKey;
  final String draftThemeKey;
  final Color accentColor;
  final ValueChanged<String> onThemeTap;
  final int totalPrice;
  final VoidCallback onReset;
  final VoidCallback onSave;

  const _BackgroundThemeDrawer({
    required this.height,
    required this.onDrawerDragUpdate,
    required this.onDrawerDragEnd,
    required this.selectedShelf,
    required this.onShelfChanged,
    required this.currentThemeKey,
    required this.draftThemeKey,
    required this.accentColor,
    required this.onThemeTap,
    required this.totalPrice,
    required this.onReset,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

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
          _DrawerGrabber(
            onDragUpdate: onDrawerDragUpdate,
            onDragEnd: onDrawerDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
            child: _ShopShelfSwitch(
              selectedShelf: selectedShelf,
              onChanged: onShelfChanged,
              accentColor: accentColor,
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '背景主題',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '買完即可套用到首頁、設定與自律房背景',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.wallpaper_outlined, size: 22),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 72),
              itemCount: AppUI.backgroundThemeKeys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final themeKey = AppUI.backgroundThemeKeys[index];
                final colors = AppUI.backgroundThemeColors(themeKey, isDark);
                final tileAccent = colors.length > 1 ? colors[1] : accentColor;
                final selected = draftThemeKey == themeKey;
                final unlocked = appState.isAvatarItemUnlocked(
                  'appBackground',
                  index,
                );
                final using = currentThemeKey == themeKey;
                final price = appState.avatarItemPrice('appBackground', index);

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onThemeTap(themeKey),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? accentColor
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: tileAccent.withValues(alpha: 0.20),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: colors,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -8,
                                  bottom: -10,
                                  child: Icon(
                                    AppUI.backgroundThemeIcon(themeKey),
                                    color: Colors.white.withValues(alpha: 0.42),
                                    size: 58,
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Icon(
                                    unlocked
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppUI.backgroundThemeLabel(themeKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                using
                                    ? '使用中'
                                    : unlocked
                                    ? '已擁有'
                                    : '$price 自律幣',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unlocked ? accentColor : AppUI.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              price >= 50
                                  ? '史詩'
                                  : price >= 40
                                  ? '稀有'
                                  : '基本',
                              style: TextStyle(
                                color: tileAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.94),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        foregroundColor: primaryText,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.transparent,
                        ),
                      ),
                      child: const Text('取消預覽'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : Colors.white,
                        foregroundColor: accentColor,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: isDark
                              ? accentColor.withValues(alpha: 0.30)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(totalPrice > 0 ? '購買 $totalPrice' : '套用'),
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

class _ShopSetList extends StatelessWidget {
  final List<_ShopSet> sets;
  final Color accentColor;
  final ValueChanged<_ShopSet> onSetTap;
  final int Function(_ShopSet) priceForSet;
  final _ShopRarity Function(int) rarityForPrice;
  final String Function(_ShopRarity) rarityLabel;
  final Color Function(_ShopRarity) rarityColor;

  const _ShopSetList({
    required this.sets,
    required this.accentColor,
    required this.onSetTap,
    required this.priceForSet,
    required this.rarityForPrice,
    required this.rarityLabel,
    required this.rarityColor,
  });

  String _itemLabel(MapEntry<String, int> item) {
    final category = AvatarCatalog.categoryFor(item.key);
    return '${category.title} ${category.labelFor(item.value)}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    if (sets.isEmpty) {
      return Center(
        child: Text(
          '找不到符合條件的精選角色',
          style: TextStyle(
            color: secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 82),
      itemBuilder: (context, index) {
        final set = sets[index];
        final price = priceForSet(set);
        final rarity = rarityForPrice(price);
        final color = rarityColor(rarity);

        return InkWell(
          borderRadius: BorderRadius.circular(AppUI.radiusLarge),
          onTap: () => onSetTap(set),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppUI.softCardOf(context, color),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(set.icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              set.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            rarityLabel(rarity),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        set.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: set.items.take(4).map((item) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                AppUI.radiusPill,
                              ),
                            ),
                            child: Text(
                              _itemLabel(item),
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.checkroom_outlined,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price < 0
                          ? '需進化'
                          : price == 0
                          ? '已擁有'
                          : '$price',
                      style: TextStyle(
                        color: price == 0 ? accentColor : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: sets.length,
    );
  }
}
