import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_ui.dart';
import 'coin_wallet_page.dart';
import 'badges_page.dart';
import 'tasks_page.dart';
import 'today_data_page.dart';
import 'guardian_center_page.dart';
import 'guardian_parent_page.dart';
import 'group_management_page.dart';
import 'personal_analysis_page.dart';
import 'ai_assistant_page.dart';
import 'time_capsule_page.dart';
import 'future_letter_page.dart';
import 'leaderboard_page.dart';

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
    final capabilities = appState.experienceCapabilities;

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

    // Determine dashboard and gated card based on active role
    Widget? heroCard;
    bool isGated = false;
    Widget? gateCard;

    if (capabilities.isGuardian) {
      if (capabilities.requiresFamilyBinding) {
        isGated = true;
        gateCard = _BindingGatedCard(
          appState: appState,
          accentColor: accentColor,
          role: 'guardian',
        );
      } else {
        heroCard = _GuardianHeroDashboardCard(
          appState: appState,
          accentColor: accentColor,
        );
      }
    } else if (capabilities.isChild) {
      if (capabilities.requiresFamilyBinding) {
        isGated = true;
        gateCard = _BindingGatedCard(
          appState: appState,
          accentColor: accentColor,
          role: 'child',
        );
      } else {
        heroCard = _ChildHeroDashboardCard(
          appState: appState,
          accentColor: accentColor,
        );
      }
    } else if (capabilities.isGroupExperience) {
      if (capabilities.requiresGroupBinding) {
        isGated = true;
        gateCard = _GroupBindingGatedCard(
          appState: appState,
          accentColor: accentColor,
        );
      } else {
        heroCard = _GroupHeroDashboardCard(
          appState: appState,
          accentColor: accentColor,
        );
      }
    } else {
      // Default personal mode (no linkage required)
      heroCard = _HeroDashboardCard(
        score: disciplineScore,
        completedCount: completedCount,
        totalTasks: totalTasks,
        focusMinutes: appState.focusMinutes,
        sleepHours: appState.sleepHours,
        steps: appState.steps,
        isHealthConnected: appState.isHealthConnected,
        accentColor: accentColor,
      );
    }

    return Scaffold(
      backgroundColor: AppUI.scaffoldBackgroundOf(context),
      drawer: AppDrawer(onOpenTasks: openTasksPage),
      appBar: AppBar(
        title: Text(capabilities.homeTitle),
        actions: [
          Center(
            child: _PlanetPill(
              planetCount: appState.planetCount,
              accentColor: const Color(0xFFA855F7),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '您已在 Web 端解鎖了 ${appState.planetCount} 顆自律星球！',
                    ),
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
        children: isGated
            ? [const SizedBox(height: 16), gateCard!]
            : [
                if (appState.incomingGroupRequests.isNotEmpty) ...[
                  _GroupBindingGatedCard(
                    appState: appState,
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: AppUI.sectionGap),
                ],
                heroCard!,
                const SizedBox(height: AppUI.sectionGap),

                // Show action center only if not guardian mode (guardian has separate dashboard metrics)
                if (!capabilities.isGuardian) ...[
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
                        MaterialPageRoute(
                          builder: (_) => const TodayDataPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppUI.sectionGap),
                ],

                _SectionTitle(title: '工具入口', color: primaryText),
                const SizedBox(height: AppUI.cardGap),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    // Filter quick action cards based on active role
                    final List<Widget> actionCards = [];

                    if (capabilities.isGuardian) {
                      actionCards.addAll([
                        _QuickActionCard(
                          icon: Icons.favorite_outline,
                          title: '家庭陪伴與鼓勵',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GuardianParentPage(),
                              ),
                            );
                          },
                          accentColor: accentColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.bar_chart_rounded,
                          title: '孩子數據統計',
                          onTap: onOpenStatistics,
                          accentColor: accentColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                      ]);
                    } else if (capabilities.isGroupExperience) {
                      actionCards.addAll([
                        _QuickActionCard(
                          icon: capabilities.canManageGroup
                              ? Icons.admin_panel_settings_outlined
                              : Icons.groups_2_outlined,
                          title: capabilities.groupSurfaceTitle,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GroupManagementPage(),
                              ),
                            );
                          },
                          accentColor: accentColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.analytics_outlined,
                          title: '團隊分析統計',
                          onTap: onOpenStatistics,
                          accentColor: accentColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                      ]);
                    } else {
                      if (capabilities.canManageOwnFamilyLink) {
                        actionCards.add(
                          _QuickActionCard(
                            icon: Icons.family_restroom_rounded,
                            title: '家庭連結與隱私',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const GuardianCenterPage(),
                                ),
                              );
                            },
                            accentColor: accentColor,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            isDark: isDark,
                          ),
                        );
                      }

                      // Personal self-discipline tools remain available to children.
                      actionCards.addAll([
                        _QuickActionCard(
                          icon: Icons.analytics_outlined,
                          title: '個人進階分析',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PersonalAnalysisPage(),
                              ),
                            );
                          },
                          accentColor: accentColor,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.psychology_alt_outlined,
                          title: 'AI 自律助手',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AIAssistantPage(),
                              ),
                            );
                          },
                          accentColor: const Color(0xFFA855F7), // Purple accent
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.hourglass_empty_rounded,
                          title: '時間膠囊',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TimeCapsulePage(),
                              ),
                            );
                          },
                          accentColor: const Color(0xFFF59E0B), // Orange accent
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.mail_outline_rounded,
                          title: '未來的信',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FutureLetterPage(),
                              ),
                            );
                          },
                          accentColor: const Color(0xFFEC4899), // Pink accent
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
                              MaterialPageRoute(
                                builder: (_) => const BadgesPage(),
                              ),
                            );
                          },
                          accentColor: const Color(0xFF10B981), // Green accent
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                        _QuickActionCard(
                          icon: Icons.leaderboard_rounded,
                          title: '自律排行榜',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LeaderboardPage(),
                              ),
                            );
                          },
                          accentColor: const Color(0xFF3B82F6), // Blue accent
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isDark: isDark,
                        ),
                      ]);
                    }

                    return GridView.count(
                      crossAxisCount: _quickActionCrossAxisCount(width),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: _quickActionAspectRatio(width),
                      children: actionCards,
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
              Icon(Icons.language, color: accentColor, size: 17),
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

// ─── 角色模式與親屬/團體連結限制卡 ──────────────────────────────────────────

class _BindingGatedCard extends StatefulWidget {
  final AppState appState;
  final Color accentColor;
  final String role; // 'guardian' or 'personal'

  const _BindingGatedCard({
    required this.appState,
    required this.accentColor,
    required this.role,
  });

  @override
  State<_BindingGatedCard> createState() => _BindingGatedCardState();
}

class _BindingGatedCardState extends State<_BindingGatedCard> {
  final TextEditingController _idController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = widget.role == 'guardian';
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final incomingReqs = widget.appState.incomingGuardianRequests;
    final outgoingReqs = widget.appState.outgoingGuardianRequests;

    return Card(
      shape: AppUI.cardShape(),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGuardian ? Icons.shield_outlined : Icons.child_care_rounded,
                  color: widget.accentColor,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isGuardian ? '家長陪伴中心限制' : '開啟家長陪伴連結',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isGuardian
                  ? '為了使用孩子專注、睡眠與健康數據牆，請與孩子帳號進行親屬綁定。請在下方輸入您孩子的 Nudge ID 發送申請，或同意對方的申請：'
                  : '您可以與家長進行帳號連結，共同建立自律目標並接收溫暖的鼓勵卡！請在下方輸入您家長的 Nudge ID 發送申請，或同意對方的申請：',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (incomingReqs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '收到待處理的綁定申請：',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...incomingReqs.map((req) {
                final reqId = req['id'] as String;
                final nickname = req['senderNickname'] as String? ?? '使用者';
                final nudgeId = req['senderNudgeId'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$nickname ($nudgeId)',
                          style: TextStyle(color: primaryText, fontSize: 13),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.appState.approveGuardianRequest(reqId);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已成功同意並建立親屬綁定！ 🎉')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('同意失敗: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('同意', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.appState.declineGuardianRequest(reqId);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已拒絕該申請')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('拒絕失敗: $e')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('拒絕', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (outgoingReqs.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...outgoingReqs.map((req) {
                final reqId = req['id'] as String;
                final nudgeId = req['receiverNudgeId'] as String? ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '已向 $nudgeId 送出申請，等待同意中...',
                          style: TextStyle(color: secondaryText, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await widget.appState.declineGuardianRequest(reqId);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已撤回綁定申請')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('撤回失敗: $e')),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '撤回',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  hintText: isGuardian ? '輸入孩子的 Nudge ID' : '輸入家長的 Nudge ID',
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final id = _idController.text.trim();
                          if (id.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請輸入有效的 ID')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _submitting = true);
                          try {
                            await widget.appState.sendGuardianRequest(id);
                            _idController.clear();
                            messenger.showSnackBar(
                              SnackBar(content: Text('已成功發送綁定申請至 $id！ 🚀')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '申請失敗: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                              ),
                            );
                          } finally {
                            setState(() => _submitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isGuardian ? '送出綁定申請' : '送出綁定申請'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupBindingGatedCard extends StatefulWidget {
  final AppState appState;
  final Color accentColor;

  const _GroupBindingGatedCard({
    required this.appState,
    required this.accentColor,
  });

  @override
  State<_GroupBindingGatedCard> createState() => _GroupBindingGatedCardState();
}

class _GroupBindingGatedCardState extends State<_GroupBindingGatedCard> {
  final TextEditingController _idController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.group_add_outlined,
                  color: AppUI.blue,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '加入團體組織 (學員模式)',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '請輸入您班主任、企業管理者或老師提供的團體組織 ID，即可同步挑戰任務與共讀日程。',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            if (widget.appState.incomingGroupRequests.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '收到的團體邀請',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.appState.incomingGroupRequests.map((request) {
                final requestId = request['id'] as String? ?? '';
                final sender = request['senderNickname'] as String? ?? '團體管理者';
                final invitedGroupName =
                    request['groupName'] as String? ?? '自律小組';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$sender 邀請你加入「$invitedGroupName」',
                          style: TextStyle(color: primaryText, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: requestId.isEmpty
                            ? null
                            : () => widget.appState.declineGroupRequest(
                                requestId,
                              ),
                        child: const Text('拒絕'),
                      ),
                      FilledButton(
                        onPressed: requestId.isEmpty
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await widget.appState.approveGroupRequest(
                                    request,
                                  );
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('已加入「$invitedGroupName」'),
                                    ),
                                  );
                                } catch (error) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('加入失敗：$error')),
                                  );
                                }
                              },
                        child: const Text('加入'),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                hintText: '輸入團體組織 ID (格式如: GRP-88921)',
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isJoining
                    ? null
                    : () async {
                        final id = _idController.text.trim();
                        if (id.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('請輸入團體組織 ID')),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isJoining = true);
                        try {
                          await widget.appState.joinGroup(id);
                          messenger.showSnackBar(
                            SnackBar(content: Text('成功加入團體 ID：$id！ 🎯')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('加入失敗: $e')),
                          );
                        } finally {
                          setState(() => _isJoining = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.accentColor,
                  side: BorderSide(color: widget.accentColor),
                ),
                child: const Text('輸入 ID 連結並加入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 孩子模式專屬控制台 ───────────────────────────────────────────────────

class _ChildHeroDashboardCard extends StatelessWidget {
  final AppState appState;
  final Color accentColor;

  const _ChildHeroDashboardCard({
    required this.appState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeGoal = appState.activeFamilyGoal;
    final goal = activeGoal?['title']?.toString() ?? '目前沒有共同目標';
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final bondXp = appState.familyBondXp;
    final bondLevel = appState.familyBondLevel;
    final levelStart = bondLevel == 1
        ? 0
        : bondLevel == 2
        ? 10
        : 30;
    final levelTarget = bondLevel == 1 ? 10 : 30;
    final bondProgress = bondLevel >= 3
        ? 1.0
        : ((bondXp - levelStart) / (levelTarget - levelStart)).clamp(0.0, 1.0);

    final latestEncouragement = appState.guardianEncouragements.isNotEmpty
        ? appState.guardianEncouragements.first
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppUI.radiusLarge),
        border: Border.all(color: accentColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.family_restroom_rounded,
                      color: Color(0xFF10B981),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '家長陪伴模式已連結',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Colors.pink, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '與家長的共同目標：',
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            goal,
            style: TextStyle(
              color: primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '家庭羈絆 Lv.$bondLevel',
                    style: TextStyle(color: secondaryText, fontSize: 11),
                  ),
                  Text(
                    bondLevel >= 3
                        ? '$bondXp XP · 最高等級'
                        : '$bondXp / $levelTarget XP',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: bondProgress,
                  minHeight: 8,
                  backgroundColor: AppUI.isDark(context)
                      ? const Color(0xFF2A2F3A)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ),
          if (latestEncouragement != null) ...[
            const Divider(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  const Text('💌', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestEncouragement['title'] ?? '收到鼓勵',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latestEncouragement['message'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: secondaryText, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryText,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 家長模式專屬控制台 ───────────────────────────────────────────────────

class _GuardianHeroDashboardCard extends StatelessWidget {
  final AppState appState;
  final Color accentColor;

  const _GuardianHeroDashboardCard({
    required this.appState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final childSleep = appState.sleepHours > 0 ? appState.sleepHours : 6.8;
    final childFocus = appState.focusMinutes > 0 ? appState.focusMinutes : 45;
    final childSteps = appState.steps > 0 ? appState.steps : 6250;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.95),
            Color.lerp(accentColor, const Color(0xFFFB923C), 0.5) ??
                accentColor,
            const Color(0xFFC2410C).withValues(alpha: 0.96),
          ],
          stops: const [0, 0.6, 1],
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
            icon: Icons.shield_outlined,
            label: '家長陪伴看板 (監管孩子中)',
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            '孩子的今日自律狀況：',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
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
                label: '孩子任務',
                value: '4/6 已完成',
                color: const Color(0xFF34D399),
              ),
              _DashboardMetricCard(
                icon: Icons.timer_outlined,
                label: '孩子專注',
                value: '$childFocus 分鐘',
                color: const Color(0xFF93C5FD),
              ),
              _DashboardMetricCard(
                icon: Icons.bedtime_outlined,
                label: '孩子睡眠',
                value: '${childSleep.toStringAsFixed(1)} 小時',
                color: const Color(0xFFC4B5FD),
              ),
              _DashboardMetricCard(
                icon: Icons.directions_walk,
                label: '孩子步數',
                value: '$childSteps 步',
                color: const Color(0xFF6EE7B7),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 團體/班級模式專屬控制台 ──────────────────────────────────────────────

class _GroupHeroDashboardCard extends StatelessWidget {
  final AppState appState;
  final Color accentColor;

  const _GroupHeroDashboardCard({
    required this.appState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isOwner = appState.isGroupOwner;
    final groupName = appState.groupName ?? '自律小組';
    final groupId = appState.groupId ?? 'GRP-XXXX';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.12),
            const Color(0xFF14B8A6).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppUI.radiusLarge),
        border: Border.all(color: accentColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOwner
                          ? Icons.admin_panel_settings_outlined
                          : Icons.group_work_outlined,
                      color: accentColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOwner ? '團體建立者 (房主)' : '團體成員',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'ID: $groupId',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '當前關聯之團體：',
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                groupName,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(isOwner ? '解散團體' : '退出團體'),
                      content: Text(
                        '確定要${isOwner ? '解散' : '退出'}當前團體【$groupName】嗎？',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(context);
                            await appState.leaveGroup();
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已退出當前團體')),
                            );
                          },
                          child: const Text(
                            '確定',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                tooltip: '退出此團體',
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AppUI.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '進行中挑戰：7日早起挑戰 (已啟動)',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
