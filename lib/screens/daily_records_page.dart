import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_summary.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/daily_score_breakdown.dart';

class DailyRecordsPage extends StatelessWidget {
  const DailyRecordsPage({super.key});

  List<DailySummary> _sortedSummaries(List<DailySummary> summaries) {
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  List<DailySummary> _thisMonthSummaries(List<DailySummary> summaries) {
    final now = DateTime.now();
    return summaries.where((item) {
      final date = DateTime.tryParse(item.date);
      if (date == null) return false;
      return date.year == now.year && date.month == now.month;
    }).toList();
  }

  int _averageScore(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(
      0,
      (sum, item) => sum + item.disciplineScore,
    );
    return (total / summaries.length).round();
  }

  int _totalCoins(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.coinsEarned);
  }

  DailySummary? _bestDay(List<DailySummary> summaries) {
    if (summaries.isEmpty) return null;
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.disciplineScore.compareTo(a.disciplineScore));
    return sorted.first;
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${parts[1]}/${parts[2]}';
  }

  void _showDetailSheet(BuildContext context, DailySummary summary) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              28 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.date,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: AppUI.softCardOf(context, AppUI.primary),
                      child: Text(
                        '${summary.disciplineScore} 分',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DailyScoreBreakdownCard(summary: summary),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _RecordInfoChip(
                      label: '加權分數',
                      value: '${summary.disciplineScore} 分',
                    ),
                    _RecordInfoChip(
                      label: '自律幣',
                      value: '+${summary.coinsEarned} 枚',
                    ),
                    _RecordInfoChip(
                      label: '任務完成',
                      value: '${summary.completedTasks}/${summary.totalTasks}',
                    ),
                    _RecordInfoChip(
                      label: '自動追蹤',
                      value:
                          '${summary.autoTrackedCompleted}/${summary.autoTrackedTotal}',
                    ),
                    _RecordInfoChip(
                      label: '健康任務',
                      value:
                          '${summary.healthCompleted}/${summary.healthTotal}',
                    ),
                    _RecordInfoChip(
                      label: '自律房',
                      value: '${summary.roomCompleted}/${summary.roomTotal}',
                    ),
                    _RecordInfoChip(
                      label: '專注',
                      value: '${summary.focusMinutes} 分鐘',
                    ),
                    _RecordInfoChip(
                      label: '睡眠',
                      value: '${summary.sleepHours.toStringAsFixed(1)} 小時',
                    ),
                    _RecordInfoChip(label: '步數', value: '${summary.steps} 步'),
                    _RecordInfoChip(
                      label: '運動',
                      value: '${summary.exerciseMinutes} 分鐘',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '本日自律分數採用任務權重換算。健康、專注與自律房會先同步成自動追蹤任務，再一起計入分數與自律幣門檻。',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _sortedSummaries(
      context.watch<AppState>().dailySummaries,
    );
    final accentColor = context.watch<AppState>().currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final monthSummaries = _thisMonthSummaries(summaries);
    final averageScore = _averageScore(monthSummaries);
    final totalCoins = _totalCoins(monthSummaries);
    final bestDay = _bestDay(monthSummaries);

    return Scaffold(
      appBar: AppBar(title: const Text('每日紀錄')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '每日紀錄總覽',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '已累積 ${summaries.length} 天紀錄',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              Expanded(
                child: _SummaryMiniCard(
                  icon: Icons.insights_outlined,
                  title: '本月平均',
                  value: '$averageScore 分',
                  color: AppUI.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMiniCard(
                  icon: Icons.monetization_on_outlined,
                  title: '本月自律幣',
                  value: '+$totalCoins 枚',
                  color: AppUI.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryMiniCard(
            icon: Icons.emoji_events_outlined,
            title: '本月最佳日',
            value: bestDay == null ? '--' : _shortDate(bestDay.date),
            color: AppUI.green,
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text(
            '紀錄列表',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          if (summaries.isEmpty)
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Text(
                  '目前還沒有每日紀錄。',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ),
            )
          else
            ...summaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                child: _DailyRecordTile(
                  summary: summary,
                  onTap: () => _showDetailSheet(context, summary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryMiniCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

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
            Container(
              width: 42,
              height: 42,
              decoration: AppUI.softCardOf(context, color),
              child: Icon(icon, color: color),
            ),
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
      ),
    );
  }
}

class _DailyRecordTile extends StatelessWidget {
  final DailySummary summary;
  final VoidCallback onTap;

  const _DailyRecordTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accentColor = context.watch<AppState>().currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: AppUI.softCardOf(context, accentColor),
                child: Icon(Icons.calendar_today_outlined, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.date,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '幣 +${summary.coinsEarned} ・ 自動 ${summary.autoTrackedCompleted}/${summary.autoTrackedTotal} ・ ${summary.sourceSummary}',
                      style: TextStyle(fontSize: 14, color: secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${summary.disciplineScore} 分',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _RecordInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? const Color(0xFF242A36)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        '$label：$value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
    );
  }
}
