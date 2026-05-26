import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';

class AvatarCodexPage extends StatelessWidget {
  const AvatarCodexPage({super.key});

  Future<void> _applyStage(
    BuildContext context,
    AppState appState,
    AvatarEvolutionStage stage,
  ) async {
    if (!appState.isAvatarEvolutionStageUnlocked(stage.index)) return;
    await appState.updateAvatarProfile(
      appState.avatarProfile.copyWith(faceShapeIndex: stage.index),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切換為 ${stage.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final unlockedCount = AvatarCatalog.evolutionStages
        .where((stage) => appState.isAvatarEvolutionStageUnlocked(stage.index))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('角色圖鑑')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '角色收藏總覽',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '已解鎖 $unlockedCount / ${AvatarCatalog.evolutionStages.length} 個階段',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text(
            '所有角色',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '圖鑑整理每一條角色進化鏈與階段解鎖狀態。',
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...AvatarCatalog.series.map(
            (series) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _AvatarSeriesCard(
                series: series,
                currentIndex: appState.avatarProfile.faceShapeIndex,
                isUnlocked: appState.isAvatarEvolutionStageUnlocked,
                requirementText: appState.avatarEvolutionRequirementText,
                onApply: (stage) => _applyStage(context, appState, stage),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AvatarSeriesCard extends StatelessWidget {
  final AvatarSeries series;
  final int currentIndex;
  final bool Function(int index) isUnlocked;
  final String Function(int index) requirementText;
  final ValueChanged<AvatarEvolutionStage> onApply;

  const _AvatarSeriesCard({
    required this.series,
    required this.currentIndex,
    required this.isUnlocked,
    required this.requirementText,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final unlockedCount = series.stages
        .where((stage) => isUnlocked(stage.index))
        .length;

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.name,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        series.description,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _CodexProgressChip(
                  label: '$unlockedCount/${series.stages.length}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: series.stages.length,
                separatorBuilder: (_, _) => const _EvolutionArrow(),
                itemBuilder: (context, index) {
                  final stage = series.stages[index];
                  return _CodexStageTile(
                    stage: stage,
                    current: currentIndex == stage.index,
                    unlocked: isUnlocked(stage.index),
                    requirementText: requirementText(stage.index),
                    onApply: () => onApply(stage),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodexStageTile extends StatelessWidget {
  final AvatarEvolutionStage stage;
  final bool current;
  final bool unlocked;
  final String requirementText;
  final VoidCallback onApply;

  const _CodexStageTile({
    required this.stage,
    required this.current,
    required this.unlocked,
    required this.requirementText,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accent = current
        ? AppUI.green
        : unlocked
        ? AppUI.blue
        : AppUI.orange;
    final profile = AvatarProfile.initial().copyWith(
      faceShapeIndex: stage.index,
    );

    return SizedBox(
      width: 172,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unlocked ? onApply : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha: AppUI.isDark(context) ? 0.14 : 0.08,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: current
                  ? accent.withValues(alpha: 0.72)
                  : Theme.of(context).dividerColor,
              width: current ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: unlocked ? 1 : 0.38,
                      child: AvatarPreview(
                        profile: profile,
                        size: 148,
                        showBackgroundRing: false,
                      ),
                    ),
                    if (!unlocked)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                stage.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                current ? '使用中' : requirementText,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: current
                      ? AppUI.green
                      : unlocked
                      ? AppUI.blue
                      : secondaryText,
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvolutionArrow extends StatelessWidget {
  const _EvolutionArrow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Icon(
          Icons.arrow_forward_rounded,
          color: AppUI.textSecondaryOf(context).withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _CodexProgressChip extends StatelessWidget {
  final String label;

  const _CodexProgressChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppUI.purple.withValues(
          alpha: AppUI.isDark(context) ? 0.20 : 0.12,
        ),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppUI.purple,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
