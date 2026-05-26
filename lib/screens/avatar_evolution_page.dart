import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'avatar_codex_page.dart';

class AvatarEvolutionPage extends StatelessWidget {
  const AvatarEvolutionPage({super.key});

  double _levelProgress(AppState appState) {
    if (appState.avatarLevel >= AppState.avatarMaxLevel) return 1;
    final currentLevelExp = AppState.avatarExperienceRequiredForLevel(
      appState.avatarLevel,
    );
    final nextLevelExp = appState.avatarNextLevelExperience;
    final span = nextLevelExp - currentLevelExp;
    if (span <= 0) return 1;
    return ((appState.avatarExperience - currentLevelExp) / span).clamp(0, 1);
  }

  double _stageProgress(AppState appState, AvatarEvolutionStage stage) {
    if (stage.requiredExperience <= 0) return 1;
    return (appState.avatarExperienceForStage(stage.index) /
            stage.requiredExperience)
        .clamp(0, 1);
  }

  AvatarEvolutionStage? _nextLockedStage(
    AppState appState,
    List<AvatarEvolutionStage> stages,
  ) {
    for (final stage in stages) {
      if (!appState.isAvatarEvolutionStageUnlocked(stage.index)) {
        return stage;
      }
    }
    return null;
  }

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
    final currentStage = AvatarCatalog.stageForIndex(
      appState.avatarProfile.faceShapeIndex,
    );
    final currentSeries = AvatarCatalog.series.firstWhere(
      (series) => series.name == currentStage.series,
      orElse: () => AvatarCatalog.series.first,
    );
    final currentSeriesStages = currentSeries.stages;
    final nextStage = _nextLockedStage(appState, currentSeriesStages);
    final unlockedSeriesCount = currentSeriesStages
        .where((stage) => appState.isAvatarEvolutionStageUnlocked(stage.index))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色進化路線'),
        actions: [
          IconButton(
            tooltip: '角色圖鑑',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvatarCodexPage()),
              );
            },
            icon: const Icon(Icons.grid_view_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          _EvolutionHeroCard(
            appState: appState,
            accentColor: accentColor,
            levelProgress: _levelProgress(appState),
            nextStage: nextStage,
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${currentSeries.name}進化路線',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$unlockedSeriesCount/${currentSeriesStages.length}',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...currentSeriesStages.map(
            (stage) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EvolutionStageCard(
                stage: stage,
                isCurrent: appState.avatarProfile.faceShapeIndex == stage.index,
                isUnlocked: appState.isAvatarEvolutionStageUnlocked(
                  stage.index,
                ),
                progress: _stageProgress(appState, stage),
                requirementText: appState.avatarEvolutionRequirementText(
                  stage.index,
                ),
                profile: appState.avatarProfile.copyWith(
                  faceShapeIndex: stage.index,
                ),
                onApply: () => _applyStage(context, appState, stage),
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _EvolutionRuleCard(appState: appState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EvolutionHeroCard extends StatelessWidget {
  final AppState appState;
  final Color accentColor;
  final double levelProgress;
  final AvatarEvolutionStage? nextStage;

  const _EvolutionHeroCard({
    required this.appState,
    required this.accentColor,
    required this.levelProgress,
    required this.nextStage,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final currentStage = AvatarCatalog.stageForIndex(
      appState.avatarProfile.faceShapeIndex,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUI.heroGradient(accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStage.series,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentStage.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lv.${appState.avatarLevel} · ${appState.avatarExperience} EXP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                ),
                child: AvatarPreview(
                  profile: appState.avatarProfile,
                  size: 108,
                  showBackgroundRing: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            appState.avatarLevel >= AppState.avatarMaxLevel
                ? '已達最高等級，所有階段都可以自由切換。'
                : '距離下一等還差 ${appState.avatarExperienceToNextLevel} EXP。',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppUI.radiusCard),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Text(
              nextStage == null
                  ? '進化完成：你已經解鎖所有階段。'
                  : '下一階段：${nextStage!.name}，需要 Lv.${nextStage!.requiredLevel} / ${nextStage!.requiredExperience} EXP。',
              style: TextStyle(
                color: AppUI.isDark(context) ? Colors.white : primaryText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvolutionStageCard extends StatelessWidget {
  final AvatarEvolutionStage stage;
  final bool isCurrent;
  final bool isUnlocked;
  final double progress;
  final String requirementText;
  final AvatarProfile profile;
  final VoidCallback onApply;

  const _EvolutionStageCard({
    required this.stage,
    required this.isCurrent,
    required this.isUnlocked,
    required this.progress,
    required this.requirementText,
    required this.profile,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accent = isUnlocked ? AppUI.green : AppUI.purple;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        side: BorderSide(
          color: isCurrent
              ? accent.withValues(alpha: 0.65)
              : Theme.of(context).dividerColor,
          width: isCurrent ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 96,
                  height: 116,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: AppUI.isDark(context) ? 0.16 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Opacity(
                    opacity: isUnlocked ? 1 : 0.42,
                    child: AvatarPreview(
                      profile: profile,
                      size: 104,
                      showBackgroundRing: false,
                    ),
                  ),
                ),
                if (!isUnlocked)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.name,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StageChip(
                        label: isCurrent
                            ? '使用中'
                            : isUnlocked
                            ? '已解鎖'
                            : '未解鎖',
                        color: isCurrent
                            ? AppUI.blue
                            : isUnlocked
                            ? AppUI.green
                            : AppUI.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${stage.stageLabel} · Lv.${stage.requiredLevel} · ${stage.requiredExperience} EXP',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: AppUI.isDark(context)
                          ? const Color(0xFF2A2F3A)
                          : const Color(0xFFE5E7EB),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          requirementText,
                          style: TextStyle(
                            color: isUnlocked ? AppUI.green : secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isUnlocked)
                        TextButton(
                          onPressed: isCurrent ? null : onApply,
                          child: Text(isCurrent ? '已套用' : '套用'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionRuleCard extends StatelessWidget {
  final AppState appState;

  const _EvolutionRuleCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: AppUI.purple),
                const SizedBox(width: 8),
                Text(
                  '今日 EXP 規則',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RuleRow(
              label: '任務完成度',
              value:
                  '+${appState.todayAvatarScoreExperience}/${AppState.avatarDailyScoreExperienceCap}',
              color: AppUI.blue,
            ),
            const SizedBox(height: 8),
            _RuleRow(
              label: '自動偵測加成',
              value:
                  '+${appState.todayAvatarAutoExperience}/${AppState.avatarDailyAutoExperienceCap}',
              color: AppUI.green,
            ),
            const SizedBox(height: 12),
            Text(
              '每日最多 500 EXP。任務分數最多 400 EXP；自動偵測加成最多 100 EXP，會從專注 60 分鐘、睡眠 7 小時、步數 8000 步、運動 30 分鐘、完成自律房目標中取最高達成率，不會重複疊加。',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RuleRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppUI.textSecondaryOf(context),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StageChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppUI.isDark(context) ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
