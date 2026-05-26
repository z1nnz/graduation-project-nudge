import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_summary.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'calendar_day_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _previousMonth() {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1);
    });
  }

  void _goToToday() {
    setState(() {
      final now = DateTime.now();
      displayedMonth = DateTime(now.year, now.month);
    });
  }

  String _monthTitle(DateTime month) {
    return '${month.year} 年 ${month.month} 月';
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  List<DateTime> _calendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final startOffset = firstDay.weekday % 7;
    final startDay = firstDay.subtract(Duration(days: startOffset));

    final endOffset = 6 - (lastDay.weekday % 7);
    final endDay = lastDay.add(Duration(days: endOffset));

    final days = <DateTime>[];
    var current = startDay;

    while (!current.isAfter(endDay)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  DailySummary? _summaryForDate(List<DailySummary> summaries, DateTime date) {
    final key = _dateKey(date);
    try {
      return summaries.firstWhere((item) => item.date == key);
    } catch (_) {
      return null;
    }
  }

  List<DailySummary> _monthSummaries(
    List<DailySummary> summaries,
    DateTime month,
  ) {
    return summaries.where((item) {
      final parsed = DateTime.tryParse(item.date);
      if (parsed == null) return false;
      return parsed.year == month.year && parsed.month == month.month;
    }).toList();
  }

  int _avgMonthScore(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(
      0,
      (sum, item) => sum + item.disciplineScore,
    );
    return (total / summaries.length).round();
  }

  int _avgMonthCompletionRate(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final ratioSum = summaries.fold<double>(0, (sum, item) {
      if (item.totalTasks == 0) return sum;
      return sum + (item.completedTasks / item.totalTasks);
    });
    return ((ratioSum / summaries.length) * 100).round();
  }

  int _totalMonthCompletedTasks(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.completedTasks);
  }

  int _totalMonthTasks(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.totalTasks);
  }

  DailySummary? _bestDay(List<DailySummary> summaries) {
    if (summaries.isEmpty) return null;
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.disciplineScore.compareTo(a.disciplineScore));
    return sorted.first;
  }

  int _totalMonthFocus(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.focusMinutes);
  }

  int _totalMonthCoins(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.coinsEarned);
  }

  int _totalMonthAutoCompleted(List<DailySummary> summaries) {
    return summaries.fold<int>(
      0,
      (sum, item) => sum + item.autoTrackedCompleted,
    );
  }

  int _totalMonthAutoTasks(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.autoTrackedTotal);
  }

  int _taskDueCountInMonth(List<Map<String, dynamic>> tasks, DateTime month) {
    return tasks.where((task) {
      final dueDate = task['dueDate'] as String?;
      if (dueDate == null || dueDate.isEmpty) return false;
      final parsed = DateTime.tryParse(dueDate);
      if (parsed == null) return false;
      return parsed.year == month.year && parsed.month == month.month;
    }).length;
  }

  bool _hasTaskDueOnDate(List<Map<String, dynamic>> tasks, DateTime date) {
    final key = _dateKey(date);
    return tasks.any((task) => (task['dueDate'] as String?) == key);
  }

  List<Map<String, dynamic>> _tasksDueOnDate(
    List<Map<String, dynamic>> tasks,
    DateTime date,
  ) {
    final key = _dateKey(date);
    return tasks.where((task) => (task['dueDate'] as String?) == key).toList();
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF4F8CFF);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _bestDayText(DailySummary? summary) {
    if (summary == null) return '--';
    final parsed = DateTime.tryParse(summary.date);
    if (parsed == null) return summary.date;
    return '${parsed.month}/${parsed.day}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final summaries = List<DailySummary>.from(appState.dailySummaries);
    final tasks = List<Map<String, dynamic>>.from(appState.tasks);
    final days = _calendarDays(displayedMonth);
    final weekdayLabels = const ['日', '一', '二', '三', '四', '五', '六'];

    final monthSummaries = _monthSummaries(summaries, displayedMonth);
    final monthAvgScore = _avgMonthScore(monthSummaries);
    final monthAvgCompletion = _avgMonthCompletionRate(monthSummaries);
    final monthBestDay = _bestDay(monthSummaries);
    final totalMonthFocus = _totalMonthFocus(monthSummaries);
    final totalMonthCoins = _totalMonthCoins(monthSummaries);
    final totalAutoCompleted = _totalMonthAutoCompleted(monthSummaries);
    final totalAutoTasks = _totalMonthAutoTasks(monthSummaries);
    final taskDueCount = _taskDueCountInMonth(tasks, displayedMonth);
    final totalCompletedTasks = _totalMonthCompletedTasks(monthSummaries);
    final totalTasks = _totalMonthTasks(monthSummaries);

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('行事曆')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppUI.innerPadding,
                vertical: 14,
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const _MiniLegend(
                    color: Color(0xFF10B981),
                    label: '高分',
                    isSquare: false,
                  ),
                  const _MiniLegend(
                    color: Color(0xFF4F8CFF),
                    label: '中高分',
                    isSquare: false,
                  ),
                  const _MiniLegend(
                    color: Color(0xFFF59E0B),
                    label: '普通',
                    isSquare: false,
                  ),
                  const _MiniLegend(
                    color: Color(0xFFEF4444),
                    label: '低分',
                    isSquare: false,
                  ),
                  const _MiniLegend(
                    color: Color(0xFF7C6AE6),
                    label: '任務截止',
                    isSquare: false,
                  ),
                  const _MiniLegend(
                    color: Color(0xFFF59E0B),
                    label: '有領自律幣',
                    isSquare: false,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          border: Border.all(color: accentColor, width: 1.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '今天',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: Icon(Icons.chevron_left, color: primaryText),
                      ),
                      Expanded(
                        child: Text(
                          _monthTitle(displayedMonth),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: Icon(Icons.chevron_right, color: primaryText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _goToToday,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentColor),
                        foregroundColor: accentColor,
                      ),
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('回到今天'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: weekdayLabels
                        .map(
                          (label) => Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: secondaryText,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    itemCount: days.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, index) {
                      final date = days[index];
                      final isCurrentMonth = date.month == displayedMonth.month;
                      final isToday = _isToday(date);
                      final summary = _summaryForDate(summaries, date);
                      final hasRecord = summary != null;
                      final hasTaskDue = _hasTaskDueOnDate(tasks, date);
                      final dueTasks = _tasksDueOnDate(tasks, date);
                      final scoreColor = hasRecord
                          ? _scoreColor(summary.disciplineScore)
                          : Colors.transparent;

                      final bgColor = isToday
                          ? accentColor.withValues(alpha: isDark ? 0.22 : 0.10)
                          : hasRecord
                          ? scoreColor.withValues(alpha: isDark ? 0.18 : 0.10)
                          : (isDark
                                ? const Color(0xFF1E2330)
                                : const Color(0xFFF8F8FB));

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CalendarDayDetailPage(
                                date: date,
                                summary: summary,
                                dueTasks: dueTasks,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isToday ? accentColor : Colors.transparent,
                              width: isToday || hasTaskDue ? 1.4 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentMonth
                                        ? primaryText
                                        : secondaryText.withValues(alpha: 0.6),
                                  ),
                                ),
                                const Spacer(),
                                if (hasRecord || hasTaskDue)
                                  SizedBox(
                                    height: 14,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (hasRecord) ...[
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: scoreColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              '${summary.disciplineScore}',
                                              maxLines: 1,
                                              overflow: TextOverflow.clip,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: primaryText,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (hasRecord &&
                                            summary.coinsEarned > 0) ...[
                                          const SizedBox(width: 3),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppUI.orange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                        if (hasTaskDue) ...[
                                          const SizedBox(width: 3),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppUI.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;

              if (compact) {
                return Column(
                  children: [
                    _MonthInfoCard(
                      title: '月平均分數',
                      value: '$monthAvgScore 分',
                      icon: Icons.insights_outlined,
                      color: AppUI.primary,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoCard(
                      title: '月平均完成率',
                      value: '$monthAvgCompletion%',
                      icon: Icons.pie_chart_outline,
                      color: AppUI.blue,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '本月完成任務',
                      value: '$totalCompletedTasks / $totalTasks',
                      icon: Icons.task_alt_outlined,
                      color: AppUI.green,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '本月最佳日',
                      value: _bestDayText(monthBestDay),
                      icon: Icons.emoji_events_outlined,
                      color: AppUI.orange,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '本月專注累積',
                      value: '$totalMonthFocus 分',
                      icon: Icons.timer_outlined,
                      color: AppUI.blue,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '本月自律幣',
                      value: '+$totalMonthCoins 枚',
                      icon: Icons.monetization_on_outlined,
                      color: AppUI.orange,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '自動追蹤完成',
                      value: '$totalAutoCompleted / $totalAutoTasks',
                      icon: Icons.sync_outlined,
                      color: AppUI.green,
                    ),
                    const SizedBox(height: 12),
                    _MonthInfoWideCard(
                      title: '本月截止任務',
                      value: '$taskDueCount 個',
                      icon: Icons.event_note_outlined,
                      color: AppUI.purple,
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MonthInfoCard(
                          title: '月平均分數',
                          value: '$monthAvgScore 分',
                          icon: Icons.insights_outlined,
                          color: AppUI.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MonthInfoCard(
                          title: '月平均完成率',
                          value: '$monthAvgCompletion%',
                          icon: Icons.pie_chart_outline,
                          color: AppUI.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '本月完成任務',
                    value: '$totalCompletedTasks / $totalTasks',
                    icon: Icons.task_alt_outlined,
                    color: AppUI.green,
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '本月最佳日',
                    value: _bestDayText(monthBestDay),
                    icon: Icons.emoji_events_outlined,
                    color: AppUI.orange,
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '本月專注累積',
                    value: '$totalMonthFocus 分',
                    icon: Icons.timer_outlined,
                    color: AppUI.blue,
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '本月自律幣',
                    value: '+$totalMonthCoins 枚',
                    icon: Icons.monetization_on_outlined,
                    color: AppUI.orange,
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '自動追蹤完成',
                    value: '$totalAutoCompleted / $totalAutoTasks',
                    icon: Icons.sync_outlined,
                    color: AppUI.green,
                  ),
                  const SizedBox(height: 12),
                  _MonthInfoWideCard(
                    title: '本月截止任務',
                    value: '$taskDueCount 個',
                    icon: Icons.event_note_outlined,
                    color: AppUI.purple,
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

class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSquare;

  const _MiniLegend({
    required this.color,
    required this.label,
    required this.isSquare,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryText = AppUI.textSecondaryOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: isSquare ? BorderRadius.circular(3) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MonthInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MonthInfoCard({
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
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, color),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthInfoWideCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MonthInfoWideCard({
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
