import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_ui.dart';
import 'coin_wallet_page.dart';
import 'today_advice_page.dart';
import 'badges_page.dart';
import 'weekly_report_page.dart';
import 'tasks_page.dart';
import 'today_data_page.dart';

class HomePage extends StatelessWidget {
  final void Function(int) onNavigate;
  final VoidCallback onOpenStatistics;

  const HomePage({
    super.key,
    required this.onNavigate,
    required this.onOpenStatistics,
  });

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

    final completedCount = appState.todayActionableTaskCompleted;
    final totalTasks = appState.todayActionableTaskTotal;
    final disciplineScore = appState.todayWeightedDisciplineScore;

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);
    void openTasksPage() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TasksPage()),
      );
    }

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      drawer: AppDrawer(onOpenTasks: openTasksPage),
      appBar: AppBar(
        title: const Text('首頁'),
        actions: [
          Center(
            child: _PlanetPill(
              planetCount: appState.planetCount,
              accentColor: const Color(0xFFA855F7),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('您已在 Web 端解鎖了 ${appState.planetCount} 顆自律星球！'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
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
                          CoinWalletPage(onOpenTasks: openTasksPage),
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
            completedCount: completedCount,
            totalTasks: totalTasks,
            focusMinutes: appState.focusMinutes,
            sleepHours: appState.sleepHours,
            steps: appState.steps,
            isHealthConnected: appState.isHealthConnected,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _TodayActionCenter(
            completedCount: completedCount,
            totalTasks: totalTasks,
            accentColor: accentColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onOpenTasks: openTasksPage,
            onOpenData: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TodayDataPage()),
              );
            },
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
                            onOpenTasks: openTasksPage,
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
  final int completedCount;
  final int totalTasks;
  final int focusMinutes;
  final double sleepHours;
  final int steps;
  final bool isHealthConnected;
  final Color accentColor;

  const _HeroDashboardCard({
    required this.score,
    required this.completedCount,
    required this.totalTasks,
    required this.focusMinutes,
    required this.sleepHours,
    required this.steps,
    required this.isHealthConnected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = score >= 90
        ? '今日狀態很好'
        : score >= 60
        ? '今日穩定推進'
        : '今日正在起步';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.95),
            Color.lerp(accentColor, const Color(0xFF4F8CFF), 0.42) ??
                accentColor,
            const Color(0xFF0F766E).withValues(alpha: 0.96),
          ],
          stops: const [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(AppUI.radiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DashboardPill(
            icon: Icons.data_usage_rounded,
            label: '今日儀表板',
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        '分',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.55,
            children: [
              _DashboardMetricCard(
                icon: Icons.task_alt_outlined,
                label: '任務',
                value: '$completedCount/$totalTasks',
                color: const Color(0xFF34D399),
              ),
              _DashboardMetricCard(
                icon: Icons.timer_outlined,
                label: '專注',
                value: '$focusMinutes 分',
                color: const Color(0xFF93C5FD),
              ),
              _DashboardMetricCard(
                icon: Icons.bedtime_outlined,
                label: '睡眠',
                value: isHealthConnected
                    ? '${sleepHours.toStringAsFixed(1)} 小時'
                    : '未同步',
                color: const Color(0xFFC4B5FD),
              ),
              _DashboardMetricCard(
                icon: Icons.directions_walk,
                label: '步數',
                value: isHealthConnected ? '$steps' : '未同步',
                color: const Color(0xFF6EE7B7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DashboardPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DashboardMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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

class _TodayActionCenter extends StatelessWidget {
  final int completedCount;
  final int totalTasks;
  final Color accentColor;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenData;

  const _TodayActionCenter({
    required this.completedCount,
    required this.totalTasks,
    required this.accentColor,
    required this.primaryText,
    required this.secondaryText,
    required this.onOpenTasks,
    required this.onOpenData,
  });

  @override
  Widget build(BuildContext context) {
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
            _PrimaryTaskButton(
              completedCount: completedCount,
              totalTasks: totalTasks,
              color: accentColor,
              primaryText: primaryText,
              secondaryText: secondaryText,
              onPressed: onOpenTasks,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCenterCard(
                    icon: Icons.edit_note_rounded,
                    title: '任務',
                    subtitle: '整理今日行動',
                    color: accentColor,
                    onTap: onOpenTasks,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCenterCard(
                    icon: Icons.monitor_heart_outlined,
                    title: '數據',
                    subtitle: '查看今日核心',
                    color: const Color(0xFF4F8CFF),
                    onTap: onOpenData,
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

class _ActionCenterCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCenterCard({
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppUI.isDark(context) ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryTaskButton extends StatelessWidget {
  final int completedCount;
  final int totalTasks;
  final Color color;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onPressed;

  const _PrimaryTaskButton({
    required this.completedCount,
    required this.totalTasks,
    required this.color,
    required this.primaryText,
    required this.secondaryText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTasks == 0
        ? 0.0
        : (completedCount / totalTasks).clamp(0.0, 1.0);
    final title = totalTasks == 0 ? '建立今日任務' : '整理今日任務';
    final subtitle = totalTasks == 0
        ? '先放進一個明確目標，今天就有主線可以推進。'
        : '已完成 $completedCount / $totalTasks，點進去安排下一個行動。';

    return Material(
      color: color.withValues(alpha: AppUI.isDark(context) ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (totalTasks > 0) ...[
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppUI.radiusPill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppUI.isDark(context)
                              ? const Color(0xFF2A2F3A)
                              : Colors.white.withValues(alpha: 0.82),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: color, size: 22),
            ],
          ),
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

class _PlanetPill extends StatelessWidget {
  final int planetCount;
  final Color accentColor;
  final VoidCallback onTap;

  const _PlanetPill({
    required this.planetCount,
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
                Icons.language,
                color: accentColor,
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                '$planetCount',
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
