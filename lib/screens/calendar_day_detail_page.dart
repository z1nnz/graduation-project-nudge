import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../theme/app_ui.dart';
import '../widgets/daily_score_breakdown.dart';

class CalendarDayDetailPage extends StatelessWidget {
  final DateTime date;
  final DailySummary? summary;
  final List<Map<String, dynamic>> dueTasks;

  const CalendarDayDetailPage({
    super.key,
    required this.date,
    required this.summary,
    required this.dueTasks,
  });

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF4F8CFF);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '讀書':
        return const Color(0xFF4F8CFF);
      case '運動':
        return const Color(0xFF10B981);
      case '睡眠':
        return const Color(0xFF8B5CF6);
      case '健康':
        return const Color(0xFFEC4899);
      case '共讀':
      case '自律房':
        return const Color(0xFFF59E0B);
      case '自定義':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '讀書':
        return Icons.menu_book_outlined;
      case '運動':
        return Icons.fitness_center;
      case '睡眠':
        return Icons.bedtime_outlined;
      case '健康':
        return Icons.favorite_border;
      case '共讀':
      case '自律房':
        return Icons.groups_2_outlined;
      case '自定義':
        return Icons.edit_note_outlined;
      default:
        return Icons.label_outline;
    }
  }

  int _completionRate() {
    if (summary == null || summary!.totalTasks == 0) return 0;
    return ((summary!.completedTasks / summary!.totalTasks) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _dateKey(date);
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('單日詳情')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (summary == null)
                    Text(
                      '這一天目前沒有紀錄。',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        height: 1.5,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _scoreColor(
                          summary!.disciplineScore,
                        ).withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(AppUI.radiusPill),
                      ),
                      child: Text(
                        '當日自律分數：${summary!.disciplineScore} 分',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(summary!.disciplineScore),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          if (summary == null)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前沒有可顯示的任務或輔助資料。',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _DetailMetricCard(
                    title: '加權任務',
                    value: '${summary!.completedTasks}/${summary!.totalTasks}',
                    icon: Icons.check_circle_outline,
                    color: AppUI.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailMetricCard(
                    title: '完成率',
                    value: '${_completionRate()}%',
                    icon: Icons.pie_chart_outline,
                    color: AppUI.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailMetricWideCard(
              title: '自律分數',
              value: '${summary!.disciplineScore} 分',
              icon: Icons.insights_outlined,
              color: AppUI.green,
            ),
            const SizedBox(height: 12),
            _DetailMetricWideCard(
              title: '自律幣',
              value: '+${summary!.coinsEarned} 枚',
              icon: Icons.monetization_on_outlined,
              color: AppUI.orange,
            ),
            const SizedBox(height: 12),
            DailyScoreBreakdownCard(summary: summary!),
            const SizedBox(height: 12),
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自動追蹤來源',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            title: '自動任務',
                            value:
                                '${summary!.autoTrackedCompleted}/${summary!.autoTrackedTotal}',
                            icon: Icons.sync_outlined,
                            color: AppUI.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailMetricCard(
                            title: '健康任務',
                            value:
                                '${summary!.healthCompleted}/${summary!.healthTotal}',
                            icon: Icons.favorite_border,
                            color: AppUI.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            title: '自律房',
                            value:
                                '${summary!.roomCompleted}/${summary!.roomTotal}',
                            icon: Icons.groups_2_outlined,
                            color: AppUI.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailMetricCard(
                            title: '專注任務',
                            value:
                                '${summary!.focusCompleted}/${summary!.focusTotal}',
                            icon: Icons.timer_outlined,
                            color: AppUI.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '來源：${summary!.sourceSummary}。健康、專注與自律房資料會同步到任務，再依權重換算成自律分數與自律幣門檻。',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '原始同步資料',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            title: '專注',
                            value: '${summary!.focusMinutes} 分',
                            icon: Icons.timer_outlined,
                            color: AppUI.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailMetricCard(
                            title: '睡眠',
                            value:
                                '${summary!.sleepHours.toStringAsFixed(1)} 小時',
                            icon: Icons.bedtime_outlined,
                            color: AppUI.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailMetricCard(
                            title: '步數',
                            value: '${summary!.steps} 步',
                            icon: Icons.directions_walk,
                            color: AppUI.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DetailMetricCard(
                            title: '運動',
                            value: '${summary!.exerciseMinutes} 分',
                            icon: Icons.fitness_center,
                            color: AppUI.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_outlined,
                        color: AppUI.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '當日截止任務',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dueTasks.isEmpty)
                    Text(
                      '這一天沒有設定截止的任務。',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        height: 1.5,
                      ),
                    )
                  else
                    ...dueTasks.map((task) {
                      final title = (task['title'] ?? '') as String;
                      final category = (task['category'] ?? '自定義') as String;
                      final categoryLabel = category == '共讀' ? '自律房' : category;
                      final done = (task['done'] ?? false) as bool;
                      final categoryColor = _categoryColor(category);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _categoryIcon(category),
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: done
                                            ? secondaryText
                                            : primaryText,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _TaskTag(
                                          text: categoryLabel,
                                          bgColor: categoryColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          textColor: categoryColor,
                                        ),
                                        _TaskTag(
                                          text: done ? '已完成' : '未完成',
                                          bgColor: done
                                              ? const Color(0xFFE8F7EC)
                                              : (isDark
                                                    ? const Color(0xFF242A36)
                                                    : const Color(0xFFF3F4F6)),
                                          textColor: done
                                              ? const Color(0xFF16A34A)
                                              : secondaryText,
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
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      decoration: AppUI.softCardOf(context, color),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 13, color: secondaryText)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricWideCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailMetricWideCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      decoration: AppUI.softCardOf(context, color),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: secondaryText),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTag extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _TaskTag({
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
