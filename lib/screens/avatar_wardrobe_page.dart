import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';

class AvatarWardrobePage extends StatefulWidget {
  const AvatarWardrobePage({super.key});

  @override
  State<AvatarWardrobePage> createState() => _AvatarWardrobePageState();
}

class _AvatarWardrobePageState extends State<AvatarWardrobePage> {
  String _selectedSeriesFilter = '全部';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    // 取得所有進化階段，但只顯示已解鎖的角色
    final allStages = AvatarCatalog.evolutionStages
        .where((stage) => appState.isAvatarEvolutionStageUnlocked(stage.index))
        .toList();

    // 依據系列過濾
    final filteredStages = _selectedSeriesFilter == '全部'
        ? allStages
        : allStages.where((s) => s.series == _selectedSeriesFilter).toList();

    // 取得所有系列名稱（只列出有已解鎖角色的系列）
    final unlockedSeriesNames = allStages.map((s) => s.series).toSet();
    final seriesNames = [
      '全部',
      ...AvatarCatalog.series
          .map((s) => s.name)
          .where((name) => unlockedSeriesNames.contains(name)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色倉庫'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── 頂部角色狀態看板 ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(AppUI.pagePadding),
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '目前的自律夥伴',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AvatarCatalog.stageForIndex(appState.avatarProfile.faceShapeIndex).name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '等級: Lv.${appState.avatarLevel} | 點擊下方角色卡片即可直接切換',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: AvatarPreview(
                    profile: appState.avatarProfile,
                    size: 48,
                    showBackgroundRing: false,
                  ),
                ),
              ],
            ),
          ),

          // ─── 橫向系列分類選單 ────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppUI.pagePadding),
              itemCount: seriesNames.length,
              itemBuilder: (context, index) {
                final name = seriesNames[index];
                final isSelected = _selectedSeriesFilter == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    selectedColor: accentColor.withValues(alpha: 0.15),
                    checkmarkColor: accentColor,
                    labelStyle: TextStyle(
                      color: isSelected ? accentColor : secondaryText,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSeriesFilter = name;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ─── 角色倉庫 Grid ──────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.82,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: filteredStages.length,
              itemBuilder: (context, index) {
                final stage = filteredStages[index];
                final isCurrent = appState.avatarProfile.faceShapeIndex == stage.index;

                return InkWell(
                  onTap: () async {
                    await appState.updateAvatarProfile(
                      appState.avatarProfile.copyWith(faceShapeIndex: stage.index),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已成功更換自律角色為 ${stage.name} 🎉'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? accentColor.withValues(alpha: 0.05)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? accentColor
                            : Theme.of(context).dividerColor,
                        width: isCurrent ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    // 用 Padding + Column(stretch) 確保內容撐滿卡片寬度並置中
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 角色圖片 — 用 Center 包裹確保水平置中
                          Expanded(
                            child: Center(
                              child: AvatarPreview(
                                profile: AvatarProfile.initial().copyWith(
                                  faceShapeIndex: stage.index,
                                ),
                                size: 100,
                                showBackgroundRing: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 角色名稱
                          Text(
                            stage.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 系列名稱
                          Text(
                            stage.series,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 使用按鈕 — Center 使膠囊不被 stretch 拉開
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? accentColor
                                    : accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isCurrent ? '目前使用' : '使用此角色',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
