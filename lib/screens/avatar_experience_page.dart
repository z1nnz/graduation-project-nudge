import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'avatar_evolution_page.dart';
import 'tasks_page.dart';

class AvatarExperiencePage extends StatelessWidget {
  const AvatarExperiencePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = appState.currentIconColor;
    final todayProgress =
        (appState.todayAvatarExperience /
                (AppState.avatarDailyScoreExperienceCap +
                    AppState.avatarDailyAutoExperienceCap))
            .clamp(0, 1)
            .toDouble();

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      appBar: AppBar(title: const Text('角色經驗')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          28,
        ),
        children: [
          _ExperienceHeroCard(
            level: appState.avatarLevel,
            totalExperience: appState.avatarExperience,
            nextLevelExperience: appState.avatarNextLevelExperience,
            remainingExperience: appState.avatarExperienceToNextLevel,
            todayExperience: appState.todayAvatarExperience,
            todayProgress: todayProgress,
            levelProgress: _levelProgress(appState),
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Expanded(
                child: _ExperienceActionButton(
                  icon: Icons.checklist_rounded,
                  title: '補今日任務',
                  subtitle: '提高任務 EXP',
                  color: const Color(0xFF7C6AE6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksPage()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ExperienceActionButton(
                  icon: Icons.auto_graph_rounded,
                  title: '看進化線',
                  subtitle: '確認解鎖階段',
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AvatarEvolutionPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(
            title: '今日 EXP 組成',
            subtitle: '每天最多 500 EXP：任務分數最多 400，自動偵測加成最多 100。',
          ),
          const SizedBox(height: AppUI.cardGap),
          _ExperienceBreakdownCard(
            scoreExperience: appState.todayAvatarScoreExperience,
            autoExperience: appState.todayAvatarAutoExperience,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(
            title: '自動加成來源',
            subtitle: '專注、睡眠、步數、運動、自律房會取最高達成率，不會重複疊加。',
          ),
          const SizedBox(height: AppUI.cardGap),
          _AutoSourceCard(appState: appState),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(
            title: '今天可以怎麼升',
            subtitle: appState.avatarExperienceToNextLevel == 0
                ? '已達最高等級，接下來可以收集與切換不同角色。'
                : '優先補任務分數，再用一個自動來源拿滿 100 EXP。',
          ),
          const SizedBox(height: AppUI.cardGap),
          _ExperienceSuggestionCard(
            appState: appState,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }
}

class _ExperienceHeroCard extends StatelessWidget {
  final int level;
  final int totalExperience;
  final int nextLevelExperience;
  final int remainingExperience;
  final int todayExperience;
  final double todayProgress;
  final double levelProgress;
  final Color accentColor;

  const _ExperienceHeroCard({
    required this.level,
    required this.totalExperience,
    required this.nextLevelExperience,
    required this.remainingExperience,
    required this.todayExperience,
    required this.todayProgress,
    required this.levelProgress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxed = level >= AppState.avatarMaxLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUI.heroGradient(accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '目前等級',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroChip(text: '$totalExperience EXP'),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            maxed
                ? '已達最高等級，所有角色階段都可以自由切換。'
                : '$totalExperience / $nextLevelExperience EXP，距離下一等還差 $remainingExperience EXP。',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
            child: LinearProgressIndicator(
              value: todayProgress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(text: '今日 +$todayExperience / 500'),
              const _HeroChip(text: '任務上限 400'),
              const _HeroChip(text: '自動加成 100'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String text;

  const _HeroChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ExperienceActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExperienceActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: AppUI.softCardOf(context, color),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExperienceBreakdownCard extends StatelessWidget {
  final int scoreExperience;
  final int autoExperience;
  final Color primaryText;
  final Color secondaryText;

  const _ExperienceBreakdownCard({
    required this.scoreExperience,
    required this.autoExperience,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _ProgressRuleRow(
            icon: Icons.checklist_rounded,
            title: '任務分數',
            subtitle: '自律分數 x 4，再依今日任務量修正。',
            value: scoreExperience,
            max: AppState.avatarDailyScoreExperienceCap,
            color: AppUI.green,
          ),
          const SizedBox(height: 12),
          _ProgressRuleRow(
            icon: Icons.auto_awesome_rounded,
            title: '自動偵測加成',
            subtitle: '從專注、睡眠、步數、運動、自律房取最高達成率。',
            value: autoExperience,
            max: AppState.avatarDailyAutoExperienceCap,
            color: AppUI.blue,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _AutoSourceCard extends StatelessWidget {
  final AppState appState;

  const _AutoSourceCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final summary = appState.todaySummary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _ProgressRuleRow(
            icon: Icons.timer_outlined,
            title: '專注',
            subtitle:
                '${summary.focusMinutes} / ${AppState.avatarAutoFocusFullMinutes} 分鐘',
            value: summary.focusMinutes,
            max: AppState.avatarAutoFocusFullMinutes,
            color: AppUI.blue,
          ),
          const SizedBox(height: 12),
          _ProgressRuleRow(
            icon: Icons.bedtime_outlined,
            title: '睡眠',
            subtitle:
                '${summary.sleepHours.toStringAsFixed(1)} / ${AppState.avatarAutoSleepFullHours.toStringAsFixed(0)} 小時',
            value: (summary.sleepHours * 10).round(),
            max: (AppState.avatarAutoSleepFullHours * 10).round(),
            color: AppUI.purple,
          ),
          const SizedBox(height: 12),
          _ProgressRuleRow(
            icon: Icons.directions_walk,
            title: '步數',
            subtitle: '${summary.steps} / ${AppState.avatarAutoStepsFull} 步',
            value: summary.steps,
            max: AppState.avatarAutoStepsFull,
            color: AppUI.green,
          ),
          const SizedBox(height: 12),
          _ProgressRuleRow(
            icon: Icons.fitness_center_outlined,
            title: '運動',
            subtitle:
                '${summary.exerciseMinutes} / ${AppState.avatarAutoExerciseFullMinutes} 分鐘',
            value: summary.exerciseMinutes,
            max: AppState.avatarAutoExerciseFullMinutes,
            color: AppUI.orange,
          ),
          const SizedBox(height: 12),
          _ProgressRuleRow(
            icon: Icons.meeting_room_outlined,
            title: '自律房',
            subtitle: summary.roomCompleted > 0
                ? '今日已完成房間目標'
                : '完成任一房間目標可拿滿自動加成',
            value: summary.roomCompleted > 0 ? 1 : 0,
            max: 1,
            color: const Color(0xFF14B8A6),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ProgressRuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
  final int max;
  final Color color;
  final bool isLast;

  const _ProgressRuleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.max,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0, 1).toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: AppUI.softCardOf(context, color),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      max <= 100
                          ? '$value / $max'
                          : '${(ratio * 100).round()}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppUI.radiusPill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppUI.isDark(context)
                        ? const Color(0xFF2A2F3A)
                        : const Color(0xFFE5E7EB),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperienceSuggestionCard extends StatelessWidget {
  final AppState appState;
  final Color primaryText;
  final Color secondaryText;

  const _ExperienceSuggestionCard({
    required this.appState,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final suggestion = appState.avatarExperienceToNextLevel == 0
        ? '角色已達最高等級。接下來可以把重點放在收集第二角色、切換穿搭與展示公開頁。'
        : appState.todayAvatarScoreExperience <
              AppState.avatarDailyScoreExperienceCap
        ? '今天任務 EXP 還沒滿，先完成高權重任務最有效；任務越穩，角色升級越快。'
        : appState.todayAvatarAutoExperience <
              AppState.avatarDailyAutoExperienceCap
        ? '任務 EXP 已經很穩，接著補一個自動來源：專注 60 分鐘、睡滿 7 小時、走到 8000 步、運動 30 分鐘或完成自律房目標。'
        : '今天 EXP 來源都很完整，可以回角色中心看看進化路線或去商城試穿新角色。';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: AppUI.softCardOf(context, const Color(0xFF7C6AE6)),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: Color(0xFF7C6AE6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '經驗建議',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppUI.textPrimaryOf(context),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppUI.textSecondaryOf(context),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
