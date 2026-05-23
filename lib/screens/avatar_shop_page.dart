import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';

class AvatarShopPage extends StatefulWidget {
  const AvatarShopPage({super.key});

  @override
  State<AvatarShopPage> createState() => _AvatarShopPageState();
}

enum _ShopRarity { all, basic, rare, epic }

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
  late AvatarProfile draft;
  late AvatarProfile original;
  bool _initialized = false;
  int selectedCategoryIndex = 0;
  bool showOwnedOnly = false;
  bool showSetsOnly = false;
  String shopQuery = '';
  _ShopRarity selectedRarity = _ShopRarity.all;

  late final List<_ShopSet> shopSets = [
    const _ShopSet(
      title: '晨光練習生',
      description: '乾淨俐落的基礎角色，適合剛開始建立自律習慣。',
      icon: Icons.wb_sunny_outlined,
      items: [MapEntry('faceShape', 0)],
    ),
    const _ShopSet(
      title: '星光少女',
      description: '帶有星光感的完整角色，買完即可直接套用。',
      icon: Icons.auto_awesome_outlined,
      items: [MapEntry('faceShape', 1)],
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
    original = context.read<AppState>().avatarProfile;
    draft = original;
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

  AvatarProfile _applyItem(AvatarProfile base, String category, int index) {
    switch (category) {
      case 'faceShape':
        return base.copyWith(faceShapeIndex: index);
      default:
        return base;
    }
  }

  List<MapEntry<String, int>> _selectedItems() {
    return [MapEntry('faceShape', draft.faceShapeIndex)];
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
        SnackBar(content: Text(totalPrice > 0 ? '已購買並套用角色' : '已套用角色')),
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
            final drawerHeight = (height * 0.60).clamp(440.0, 560.0);
            final avatarSize = (height * 0.26).clamp(168.0, 202.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppUI.isDark(context)
                            ? const [Color(0xFF0F172A), Color(0xFF12312D)]
                            : const [Color(0xFF55C7EE), Color(0xFFA8E6A2)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 18,
                  child: _CoinBadge(coins: appState.disciplineCoins),
                ),
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  bottom: drawerHeight - 18,
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
                  child: _ShopDrawer(
                    height: drawerHeight,
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
                      setState(() {
                        draft = _applyItem(draft, selectedCategory.key, index);
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
                Positioned(
                  left: 18,
                  bottom: 28,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: AppUI.textPrimaryOf(context),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            fontSize: 12,
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

class _ShopDrawer extends StatelessWidget {
  final double height;
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
    final visibleIndexes =
        List<int>.generate(selectedCategory.itemCount, (index) => index)
            .where((index) {
              if (!showOwnedOnly) return true;
              return appState.isAvatarItemUnlocked(selectedCategory.key, index);
            })
            .where((index) {
              final label = selectedCategory.labelFor(index).toLowerCase();
              if (normalizedQuery.isNotEmpty &&
                  !label.contains(normalizedQuery) &&
                  !selectedCategory.title.toLowerCase().contains(
                    normalizedQuery,
                  )) {
                return false;
              }
              if (selectedRarity == _ShopRarity.all) return true;
              final price = appState.avatarItemPrice(
                selectedCategory.key,
                index,
              );
              return _rarityForPrice(price) == selectedRarity;
            })
            .toList();
    final visibleSets = shopSets.where((set) {
      if (normalizedQuery.isEmpty) return true;
      return set.title.toLowerCase().contains(normalizedQuery) ||
          set.description.toLowerCase().contains(normalizedQuery);
    }).toList();
    final ownedCount =
        List<int>.generate(selectedCategory.itemCount, (index) => index).where((
          index,
        ) {
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
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
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
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 34,
                        height: 4,
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
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: showSetsOnly ? '搜尋精選角色' : '搜尋角色',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '已擁有 $ownedCount / ${selectedCategory.itemCount}',
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
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 82),
                    itemCount: visibleIndexes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
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
                                  size: 54,
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
              padding: const EdgeInsets.fromLTRB(84, 10, 18, 18),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      price == 0 ? '已擁有' : '$price',
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
