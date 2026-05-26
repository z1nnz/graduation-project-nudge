import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

class TodayDataPage extends StatelessWidget {
  const TodayDataPage({super.key});

  double _progress(num value) {
    return value.clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final completedTasks = appState.todayActionableTaskCompleted;
    final totalTasks = appState.todayActionableTaskTotal;
    final taskProgress = totalTasks == 0
        ? 0.0
        : _progress(completedTasks / totalTasks);
    final focusProgress = _progress(
      appState.focusMinutes / AppState.avatarAutoFocusFullMinutes,
    );
    final sleepProgress = appState.isHealthConnected
        ? _progress(appState.sleepHours / AppState.avatarAutoSleepFullHours)
        : 0.0;
    final stepProgress = appState.isHealthConnected
        ? _progress(appState.steps / AppState.avatarAutoStepsFull)
        : 0.0;

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      appBar: AppBar(title: const Text('今日數據')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          8,
          AppUI.pagePadding,
          28,
        ),
        children: [
          _TodayDataHeroCard(
            completedTasks: completedTasks,
            totalTasks: totalTasks,
            focusMinutes: appState.focusMinutes,
            sleepHours: appState.sleepHours,
            steps: appState.steps,
            isHealthConnected: appState.isHealthConnected,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _SectionHeader(title: '核心數據', color: primaryText),
          const SizedBox(height: AppUI.cardGap),
          _MetricDetailCard(
            icon: Icons.task_alt_outlined,
            title: '今日任務',
            value: '$completedTasks / $totalTasks',
            target: totalTasks == 0 ? '尚未建立今日任務' : '完成全部今日任務',
            progress: taskProgress,
            color: AppUI.green,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          const SizedBox(height: AppUI.cardGap),
          _MetricDetailCard(
            icon: Icons.timer_outlined,
            title: '專注時間',
            value: '${appState.focusMinutes} 分',
            target: '目標 ${AppState.avatarAutoFocusFullMinutes} 分鐘',
            progress: focusProgress,
            color: AppUI.blue,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          const SizedBox(height: AppUI.cardGap),
          _MetricDetailCard(
            icon: Icons.bedtime_outlined,
            title: '睡眠',
            value: appState.isHealthConnected
                ? '${appState.sleepHours.toStringAsFixed(1)} 小時'
                : '未同步',
            target:
                '目標 ${AppState.avatarAutoSleepFullHours.toStringAsFixed(0)} 小時',
            progress: sleepProgress,
            color: AppUI.purple,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          const SizedBox(height: AppUI.cardGap),
          _MetricDetailCard(
            icon: Icons.directions_walk,
            title: '步數',
            value: appState.isHealthConnected ? '${appState.steps}' : '未同步',
            target: '目標 ${AppState.avatarAutoStepsFull} 步',
            progress: stepProgress,
            color: AppUI.green,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ],
      ),
    );
  }
}

class _TodayDataHeroCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;
  final int focusMinutes;
  final double sleepHours;
  final int steps;
  final bool isHealthConnected;
  final Color accentColor;

  const _TodayDataHeroCard({
    required this.completedTasks,
    required this.totalTasks,
    required this.focusMinutes,
    required this.sleepHours,
    required this.steps,
    required this.isHealthConnected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppUI.heroGradient(accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '今日核心數據',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
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
            childAspectRatio: 2.25,
            children: [
              _HeroMetricTile(
                icon: Icons.task_alt_outlined,
                label: '任務',
                value: '$completedTasks/$totalTasks',
                color: const Color(0xFF34D399),
              ),
              _HeroMetricTile(
                icon: Icons.timer_outlined,
                label: '專注',
                value: '$focusMinutes 分',
                color: const Color(0xFF93C5FD),
              ),
              _HeroMetricTile(
                icon: Icons.bedtime_outlined,
                label: '睡眠',
                value: isHealthConnected
                    ? '${sleepHours.toStringAsFixed(1)} 小時'
                    : '未同步',
                color: const Color(0xFFC4B5FD),
              ),
              _HeroMetricTile(
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

class _HeroMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeroMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class _MetricDetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String target;
  final double progress;
  final Color color;
  final Color primaryText;
  final Color secondaryText;

  const _MetricDetailCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.target,
    required this.progress,
    required this.color,
    required this.primaryText,
    required this.secondaryText,
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
                Container(
                  width: 42,
                  height: 42,
                  decoration: AppUI.softCardOf(context, color),
                  child: Icon(icon, color: color, size: 22),
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
                      const SizedBox(height: 3),
                      Text(
                        target,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppUI.isDark(context)
                    ? const Color(0xFF2A2F3A)
                    : color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
