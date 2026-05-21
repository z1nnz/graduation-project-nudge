import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_ui.dart';
import 'coin_wallet_page.dart';
import 'today_advice_page.dart';
import 'badges_page.dart';
import 'weekly_report_page.dart';

class HomePage extends StatelessWidget {
  final void Function(int) onNavigate;
  final VoidCallback onOpenStatistics;

  const HomePage({
    super.key,
    required this.onNavigate,
    required this.onOpenStatistics,
  });

  int calculateDisciplineScoreFromTasks(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return 0;
    final completedCount = tasks.where((task) => task['done'] == true).length;
    return ((completedCount / tasks.length) * 100).round().clamp(0, 100);
  }

  IconData getStatusIcon(int score) {
    if (score >= 90) return Icons.sentiment_very_satisfied;
    if (score >= 70) return Icons.sentiment_satisfied_alt;
    if (score >= 50) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  Color getStatusIconBackground(int score) {
    if (score >= 90) return Colors.white.withValues(alpha: 0.26);
    if (score >= 70) return Colors.white.withValues(alpha: 0.22);
    if (score >= 50) return Colors.white.withValues(alpha: 0.18);
    return Colors.white.withValues(alpha: 0.14);
  }

  String getStatusTitle(int score) {
    if (score >= 90) return '今天表現很穩定';
    if (score >= 70) return '今天進度不錯';
    if (score >= 50) return '今天還能再補強';
    return '今天先慢慢來';
  }

  String getStatusSubtitle(int score, int completedCount, int totalTasks) {
    if (totalTasks == 0) {
      return '今天還沒有任務，先新增一個明確目標吧。';
    }

    if (score >= 90) {
      return '你今天已完成 $completedCount / $totalTasks 個任務，繼續保持。';
    }
    if (score >= 70) {
      return '目前已完成 $completedCount / $totalTasks 個任務，進度很不錯。';
    }
    if (score >= 50) {
      return '目前已完成 $completedCount / $totalTasks 個任務，再努力一點就能更好。';
    }
    return '目前已完成 $completedCount / $totalTasks 個任務，先把最重要的一件事完成就好。';
  }

  int _quickActionCrossAxisCount(double width) {
    if (width < 520) return 2;
    return 4;
  }

  double _quickActionAspectRatio(double width) {
    if (width < 360) return 2.8;
    if (width < 520) return 2.9;
    return 2.6;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;

    final todayTasks = appState.todayActionableTaskModels;
    final completedCount = appState.todayActionableTaskCompleted;
    final totalTasks = appState.todayActionableTaskTotal;
    final disciplineScore = appState.todayWeightedDisciplineScore;
    final overallProgress = totalTasks == 0
        ? 0.0
        : (completedCount / totalTasks).clamp(0.0, 1.0);
    final recommendedTasks = todayTasks.where((task) => !task.isDone).toList()
      ..sort(
        (a, b) => appState
            .taskPotentialScoreForTask(b)
            .compareTo(appState.taskPotentialScoreForTask(a)),
      );
    final recommendedTask = recommendedTasks.isEmpty
        ? null
        : recommendedTasks.first;

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      drawer: AppDrawer(onOpenTasks: () => onNavigate(1)),
      appBar: AppBar(
        title: const Text('首頁'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _CoinPill(
                coins: appState.disciplineCoins,
                accentColor: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CoinWalletPage(onOpenTasks: () => onNavigate(1)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          24,
        ),
        children: [
          _HeroDashboardCard(
            score: disciplineScore,
            progress: overallProgress,
            statusTitle: getStatusTitle(disciplineScore),
            statusSubtitle: getStatusSubtitle(
              disciplineScore,
              completedCount,
              totalTasks,
            ),
            statusIcon: getStatusIcon(disciplineScore),
            statusIconBackground: getStatusIconBackground(disciplineScore),
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _TodayActionCenter(
            completedCount: completedCount,
            totalTasks: totalTasks,
            focusMinutes: appState.focusMinutes,
            sleepHours: appState.sleepHours,
            steps: appState.steps,
            isHealthConnected: appState.isHealthConnected,
            recommendedTask: recommendedTask,
            potentialScore: recommendedTask == null
                ? 0
                : appState.taskPotentialScoreForTask(recommendedTask),
            reason: recommendedTask == null
                ? ''
                : appState.taskRewardReasonForTask(recommendedTask),
            accentColor: accentColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onOpenTasks: () => onNavigate(1),
            onOpenAdvice: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TodayAdvicePage(
                    onOpenTasks: () => onNavigate(1),
                    onNavigate: onNavigate,
                  ),
                ),
              );
            },
            onOpenStatistics: onOpenStatistics,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionTitle(title: '工具入口', color: primaryText),
          const SizedBox(height: AppUI.cardGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GridView.count(
                crossAxisCount: _quickActionCrossAxisCount(width),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: _quickActionAspectRatio(width),
                children: [
                  _QuickActionCard(
                    icon: Icons.bar_chart_rounded,
                    title: '統計分析',
                    onTap: onOpenStatistics,
                    accentColor: accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  _QuickActionCard(
                    icon: Icons.tips_and_updates_outlined,
                    title: '今日建議',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TodayAdvicePage(
                            onOpenTasks: () => onNavigate(1),
                            onNavigate: onNavigate,
                          ),
                        ),
                      );
                    },
                    accentColor: accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  _QuickActionCard(
                    icon: Icons.emoji_events_outlined,
                    title: '成就徽章',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BadgesPage()),
                      );
                    },
                    accentColor: accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  _QuickActionCard(
                    icon: Icons.calendar_month_outlined,
                    title: '每週報告',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WeeklyReportPage(),
                        ),
                      );
                    },
                    accentColor: accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroDashboardCard extends StatelessWidget {
  final int score;
  final double progress;
  final String statusTitle;
  final String statusSubtitle;
  final IconData statusIcon;
  final Color statusIconBackground;
  final Color accentColor;

  const _HeroDashboardCard({
    required this.score,
    required this.progress,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.statusIcon,
    required this.statusIconBackground,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.95),
            accentColor.withValues(alpha: 0.76),
            const Color(0xFF0F766E),
          ],
        ),
        borderRadius: BorderRadius.circular(AppUI.radiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -14,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.data_usage_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '今日自律儀表板',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      '分',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _RecordSignalPill(progress: progress),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                statusTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordSignalPill extends StatelessWidget {
  final double progress;

  const _RecordSignalPill({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '已記錄 ${(progress * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayActionCenter extends StatelessWidget {
  final int completedCount;
  final int totalTasks;
  final int focusMinutes;
  final double sleepHours;
  final int steps;
  final bool isHealthConnected;
  final TaskModel? recommendedTask;
  final int potentialScore;
  final String reason;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenAdvice;
  final VoidCallback onOpenStatistics;

  const _TodayActionCenter({
    required this.completedCount,
    required this.totalTasks,
    required this.focusMinutes,
    required this.sleepHours,
    required this.steps,
    required this.isHealthConnected,
    required this.recommendedTask,
    required this.potentialScore,
    required this.reason,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    required this.onOpenTasks,
    required this.onOpenAdvice,
    required this.onOpenStatistics,
  });

  @override
  Widget build(BuildContext context) {
    final task = recommendedTask;

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '今日行動中心',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.6,
              children: [
                _ActionInfoPill(
                  icon: Icons.task_alt_outlined,
                  label: '任務',
                  value: '$completedCount/$totalTasks',
                  color: AppUI.green,
                ),
                _ActionInfoPill(
                  icon: Icons.timer_outlined,
                  label: '專注',
                  value: '$focusMinutes 分',
                  color: AppUI.blue,
                ),
                _ActionInfoPill(
                  icon: Icons.bedtime_outlined,
                  label: '睡眠',
                  value: isHealthConnected
                      ? '${sleepHours.toStringAsFixed(1)} 小時'
                      : '未同步',
                  color: AppUI.purple,
                ),
                _ActionInfoPill(
                  icon: Icons.directions_walk,
                  label: '步數',
                  value: isHealthConnected ? '$steps' : '未同步',
                  color: AppUI.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task == null)
              _EmptyRecommendationCard(
                onOpenTasks: onOpenTasks,
                onOpenAdvice: onOpenAdvice,
                primaryText: primaryText,
                secondaryText: secondaryText,
                accentColor: accentColor,
              )
            else
              _RecommendedTaskCard(
                task: task,
                potentialScore: potentialScore,
                reason: reason,
                accentColor: accentColor,
                primaryText: primaryText,
                secondaryText: secondaryText,
                onGradient: false,
                onTap: onOpenTasks,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroActionButton(
                    icon: Icons.checklist_outlined,
                    label: '任務',
                    color: accentColor,
                    onGradient: false,
                    onPressed: onOpenTasks,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionButton(
                    icon: Icons.tips_and_updates_outlined,
                    label: '建議',
                    color: accentColor,
                    onGradient: false,
                    onPressed: onOpenAdvice,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionButton(
                    icon: Icons.insights_outlined,
                    label: '分析',
                    color: accentColor,
                    onGradient: false,
                    onPressed: onOpenStatistics,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActionInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool onGradient;
  final VoidCallback onPressed;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onGradient = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: onGradient ? Colors.white : color,
        backgroundColor: onGradient
            ? Colors.white.withValues(alpha: 0.10)
            : color.withValues(alpha: 0.08),
        side: BorderSide(
          color: onGradient
              ? Colors.white.withValues(alpha: 0.52)
              : color.withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyRecommendationCard extends StatelessWidget {
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenAdvice;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;

  const _EmptyRecommendationCard({
    required this.onOpenTasks,
    required this.onOpenAdvice,
    this.primaryText = Colors.white,
    this.secondaryText = Colors.white70,
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '下一個最值得做',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '今天沒有待完成任務',
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '可以新增一個小目標，或先看看今日建議。',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallHeroTextButton(
                label: '新增任務',
                color: accentColor,
                onPressed: onOpenTasks,
              ),
              _SmallHeroTextButton(
                label: '查看建議',
                color: accentColor,
                onPressed: onOpenAdvice,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallHeroTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SmallHeroTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RecommendedTaskCard extends StatelessWidget {
  final TaskModel task;
  final int potentialScore;
  final String reason;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final bool onGradient;
  final VoidCallback onTap;

  const _RecommendedTaskCard({
    required this.task,
    required this.potentialScore,
    required this.reason,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    this.onGradient = false,
    required this.onTap,
  });

  IconData get _icon {
    switch (task.sourceType) {
      case TaskSourceType.sleepHours:
        return Icons.bedtime_outlined;
      case TaskSourceType.steps:
        return Icons.directions_walk;
      case TaskSourceType.exerciseMinutes:
        return Icons.fitness_center;
      case TaskSourceType.focusMinutes:
        return Icons.timer_outlined;
      case TaskSourceType.studyRoom:
      case TaskSourceType.system:
        return Icons.groups_2_outlined;
      case TaskSourceType.manual:
      case null:
        return task.taskType == TaskType.deadline
            ? Icons.event_available_outlined
            : Icons.task_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = onGradient
        ? Colors.white.withValues(alpha: 0.14)
        : Theme.of(context).cardColor;
    final borderColor = onGradient
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.transparent;
    final iconBackground = onGradient
        ? BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          )
        : AppUI.softCardOf(context, accentColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: onGradient
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: iconBackground,
                child: Icon(_icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下一個最值得做',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _MiniInfoPill(
                          text: reason,
                          color: const Color(0xFF2563EB),
                          onGradient: onGradient,
                        ),
                        _MiniInfoPill(
                          text: '約 $potentialScore 分',
                          color: const Color(0xFF10B981),
                          onGradient: onGradient,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool onGradient;

  const _MiniInfoPill({
    required this.text,
    required this.color,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: onGradient
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppUI.radiusPill),
            )
          : AppUI.softCardOf(context, color),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: onGradient ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final iconBgColor = isDark
        ? accentColor.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.032),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  final int coins;
  final Color accentColor;
  final VoidCallback onTap;

  const _CoinPill({
    required this.coins,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(
              alpha: AppUI.isDark(context) ? 0.18 : 0.12,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_outlined,
                color: accentColor,
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                '$coins',
                style: TextStyle(
                  color: AppUI.textPrimaryOf(context),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }
}
