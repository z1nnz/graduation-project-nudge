import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_summary.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class WeeklyReportPage extends StatelessWidget {
  const WeeklyReportPage({super.key});

  List<DailySummary> _sortedSummaries(List<DailySummary> summaries) {
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  List<DailySummary> _recent7Days(List<DailySummary> summaries) {
    final sorted = _sortedSummaries(summaries);
    if (sorted.length <= 7) return sorted;
    return sorted.sublist(sorted.length - 7);
  }

  int _avgScore(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(
      0,
      (sum, item) => sum + item.disciplineScore,
    );
    return (total / summaries.length).round();
  }

  int _totalCompletedTasks(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.completedTasks);
  }

  int _totalCoins(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.coinsEarned);
  }

  int _totalAutoCompleted(List<DailySummary> summaries) {
    return summaries.fold<int>(
      0,
      (sum, item) => sum + item.autoTrackedCompleted,
    );
  }

  int _totalAutoTasks(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.autoTrackedTotal);
  }

  int _avgCompletionRate(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;

    final ratioSum = summaries.fold<double>(0, (sum, item) {
      if (item.totalTasks == 0) return sum;
      return sum + (item.completedTasks / item.totalTasks);
    });

    return ((ratioSum / summaries.length) * 100).round();
  }

  int _totalFocus(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.focusMinutes);
  }

  double _avgSleep(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<double>(
      0,
      (sum, item) => sum + item.sleepHours,
    );
    return total / summaries.length;
  }

  int _avgSteps(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(0, (sum, item) => sum + item.steps);
    return (total / summaries.length).round();
  }

  int _avgExercise(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    final total = summaries.fold<int>(
      0,
      (sum, item) => sum + item.exerciseMinutes,
    );
    return (total / summaries.length).round();
  }

  DailySummary? _bestDay(List<DailySummary> summaries) {
    if (summaries.isEmpty) return null;
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.disciplineScore.compareTo(a.disciplineScore));
    return sorted.first;
  }

  DailySummary? _lowestDay(List<DailySummary> summaries) {
    if (summaries.isEmpty) return null;
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => a.disciplineScore.compareTo(b.disciplineScore));
    return sorted.first;
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${parts[1]}/${parts[2]}';
  }

  String _weakestArea(List<DailySummary> summaries) {
    if (summaries.isEmpty) return '暫無資料';

    final avgTaskRatio =
        summaries.fold<double>(0, (sum, item) {
          if (item.totalTasks == 0) return sum;
          return sum + (item.completedTasks / item.totalTasks);
        }) /
        summaries.length;

    final avgFocusMinutes =
        summaries.fold<double>(0, (sum, item) => sum + item.focusMinutes) /
        summaries.length;

    final avgExerciseMinutes =
        summaries.fold<double>(0, (sum, item) => sum + item.exerciseMinutes) /
        summaries.length;

    final avgSleepHours =
        summaries.fold<double>(0, (sum, item) => sum + item.sleepHours) /
        summaries.length;

    final values = <String, double>{
      '任務完成率': avgTaskRatio,
      '專注任務偏低': (avgFocusMinutes / 120).clamp(0, 1),
      '健康任務偏低': ((avgExerciseMinutes / 30) + (avgSleepHours / 8)) / 2,
      '自律幣門檻偏低': (_avgScore(summaries) / 80).clamp(0, 1),
    };

    final sorted = values.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return sorted.first.key;
  }

  String _weeklySummary(List<DailySummary> summaries) {
    if (summaries.isEmpty) {
      return '目前還沒有足夠的歷史資料，先持續使用幾天後再來看每週報告。';
    }

    final avgScore = _avgScore(summaries);
    final avgCompletion = _avgCompletionRate(summaries);
    final totalCompletedTasks = _totalCompletedTasks(summaries);

    if (avgScore >= 85 && avgCompletion >= 80) {
      return '這週加權自律分數很穩定，任務、健康與自律房節奏維持得很好。';
    }

    if (avgCompletion >= 65 && totalCompletedTasks >= 8) {
      return '這週完成了不少任務，已經有進入穩定累積自律分數的節奏。';
    }

    if (avgCompletion < 40) {
      return '這週任務完成率偏低，建議下週先減少每日任務數量，讓完成率拉起來。';
    }

    if (avgScore >= 60) {
      return '這週有慢慢往前，雖然還有進步空間，但方向是對的。';
    }

    return '這週先求穩定，不一定要一次做很多，重點是每天都完成幾個明確任務。';
  }

  String _nextWeekGoal(List<DailySummary> summaries) {
    if (summaries.isEmpty) {
      return '下週先建立 3 個明確任務，讓自己重新進入節奏。';
    }

    final weakest = _weakestArea(summaries);

    if (weakest == '任務完成率') {
      return '下週目標：先把每日任務量縮小，優先提升完成率。';
    }

    if (weakest == '專注任務偏低') {
      return '下週目標：新增「專注 30 分鐘」任務，讓系統自動幫你追蹤。';
    }

    if (weakest == '健康任務偏低') {
      return '下週目標：新增睡眠、步數或運動自動追蹤任務，讓健康資料直接推動加權分數。';
    }

    if (weakest == '自律幣門檻偏低') {
      return '下週目標：每天至少跨過 40 分門檻，先穩定拿到 6 枚自律幣。';
    }

    return '下週目標：維持目前節奏，並把完成率再往上提升一點。';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final summaries = _recent7Days(appState.dailySummaries);

    final avgScore = _avgScore(summaries);
    final avgCompletion = _avgCompletionRate(summaries);
    final totalCompletedTasks = _totalCompletedTasks(summaries);
    final totalCoins = _totalCoins(summaries);
    final totalAutoCompleted = _totalAutoCompleted(summaries);
    final totalAutoTasks = _totalAutoTasks(summaries);
    final bestDay = _bestDay(summaries);
    final lowestDay = _lowestDay(summaries);
    final weakestArea = _weakestArea(summaries);
    final weeklySummary = _weeklySummary(summaries);
    final nextGoal = _nextWeekGoal(summaries);

    return Scaffold(
      appBar: AppBar(title: const Text('每週報告')),
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
                    Icons.calendar_month_outlined,
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
                        '本週總覽',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summaries.isEmpty
                            ? '目前資料不足'
                            : '平均 $avgScore 分 / 完成率 $avgCompletion%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (avgScore / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _WeeklyScoreDigestCard(
            summaryText: weeklySummary,
            summary: lowestDay,
            onOpenDetail: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _WeeklyScoreDetailPage(
                    summaryText: weeklySummary,
                    summary: lowestDay,
                    averageScore: avgScore,
                    averageCompletion: avgCompletion,
                    weakestArea: weakestArea,
                    nextGoal: nextGoal,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppUI.cardGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 380;

              if (isCompact) {
                return Column(
                  children: [
                    _ReportStatCard(
                      title: '本週完成任務',
                      value: '$totalCompletedTasks',
                      icon: Icons.task_alt_outlined,
                      color: AppUI.green,
                    ),
                    const SizedBox(height: 12),
                    _ReportStatCard(
                      title: '本週自律幣',
                      value: '+$totalCoins 枚',
                      icon: Icons.monetization_on_outlined,
                      color: AppUI.orange,
                    ),
                    const SizedBox(height: 12),
                    _ReportStatCard(
                      title: '平均自律分數',
                      value: '$avgScore 分',
                      icon: Icons.insights_outlined,
                      color: AppUI.primary,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _ReportStatCard(
                      title: '本週完成任務',
                      value: '$totalCompletedTasks',
                      icon: Icons.task_alt_outlined,
                      color: AppUI.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReportStatCard(
                      title: '本週自律幣',
                      value: '+$totalCoins 枚',
                      icon: Icons.monetization_on_outlined,
                      color: AppUI.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReportStatCard(
                      title: '平均自律分數',
                      value: '$avgScore 分',
                      icon: Icons.insights_outlined,
                      color: AppUI.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppUI.sectionGap),
          _WeeklySignalsCard(
            bestDay: bestDay,
            lowestDay: lowestDay,
            weakestArea: weakestArea,
            shortDate: _shortDate,
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '這週怎麼判讀',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReportGuideRow(
                    icon: Icons.auto_graph_outlined,
                    title: '平均分數',
                    subtitle: '看整週自律是否穩定，不被單日表現綁架。',
                    color: accentColor,
                  ),
                  const SizedBox(height: 10),
                  _ReportGuideRow(
                    icon: Icons.warning_amber_outlined,
                    title: '需補強項目',
                    subtitle: '找出這週最拖累分數的來源。',
                    color: AppUI.orange,
                  ),
                  const SizedBox(height: 10),
                  _ReportGuideRow(
                    icon: Icons.flag_outlined,
                    title: '下一個目標',
                    subtitle: '把報告轉成下週可以直接做的行動。',
                    color: AppUI.green,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自動追蹤與原始資料',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: '專注',
                        value: '${_totalFocus(summaries)} 分',
                      ),
                      _InfoChip(
                        label: '自動追蹤',
                        value: '$totalAutoCompleted/$totalAutoTasks',
                      ),
                      _InfoChip(
                        label: '睡眠',
                        value: '${_avgSleep(summaries).toStringAsFixed(1)} 小時',
                      ),
                      _InfoChip(
                        label: '步數',
                        value: '${_avgSteps(summaries)} 步',
                      ),
                      _InfoChip(
                        label: '運動',
                        value: '${_avgExercise(summaries)} 分',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '健康、專注與自律房會先同步成任務，再依權重計入加權自律分數與自律幣門檻。',
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
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下週建議',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: AppUI.softCardOf(context, accentColor),
                    child: Text(
                      nextGoal,
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryText,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyScoreDigestCard extends StatelessWidget {
  final String summaryText;
  final DailySummary? summary;
  final VoidCallback onOpenDetail;

  const _WeeklyScoreDigestCard({
    required this.summaryText,
    required this.summary,
    required this.onOpenDetail,
  });

  int get _completionRate {
    final item = summary;
    if (item == null || item.totalTasks == 0) return 0;
    return ((item.completedTasks / item.totalTasks) * 100).round();
  }

  String get _headline {
    final item = summary;
    if (item == null) return '資料還在累積中';
    if (_completionRate < 50) return '分數主要卡在任務完成率';
    if (item.autoTrackedTotal > 0 &&
        item.autoTrackedCompleted < item.autoTrackedTotal) {
      return '自動追蹤來源還有補強空間';
    }
    if (item.healthTotal > 0 && item.healthCompleted < item.healthTotal) {
      return '健康任務是這天的主要缺口';
    }
    return '本週分數結構相對穩定';
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_search, color: AppUI.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '分數重點',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (summary != null)
                  Text(
                    '${summary!.disciplineScore} 分',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _headline,
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
              summaryText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (summary != null) ...[
                  Expanded(
                    child: _DigestMiniMetric(
                      label: '完成率',
                      value: '$_completionRate%',
                      color: _completionRate >= 70 ? AppUI.green : AppUI.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DigestMiniMetric(
                      label: '自動追蹤',
                      value:
                          '${summary!.autoTrackedCompleted}/${summary!.autoTrackedTotal}',
                      color: AppUI.blue,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      '完成任務後會產生分數重點。',
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('查看分數詳情'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DigestMiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.softCardOf(context, color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyScoreDetailPage extends StatelessWidget {
  final String summaryText;
  final DailySummary? summary;
  final int averageScore;
  final int averageCompletion;
  final String weakestArea;
  final String nextGoal;
  final Color accentColor;

  const _WeeklyScoreDetailPage({
    required this.summaryText,
    required this.summary,
    required this.averageScore,
    required this.averageCompletion,
    required this.weakestArea,
    required this.nextGoal,
    required this.accentColor,
  });

  int get _completionRate {
    final item = summary;
    if (item == null || item.totalTasks == 0) return 0;
    return ((item.completedTasks / item.totalTasks) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('分數詳情')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.manage_search,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本週分數重點',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '平均 $averageScore 分 / 完成率 $averageCompletion%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '系統判讀',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summaryText,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _NextGoalBox(
                    text: nextGoal,
                    color: accentColor,
                    primaryText: primaryText,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '拆解指標',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DigestChip(
                        label: '需補強',
                        value: weakestArea,
                        color: AppUI.orange,
                      ),
                      _DigestChip(
                        label: '本週平均',
                        value: '$averageScore 分',
                        color: AppUI.primary,
                      ),
                      if (summary != null) ...[
                        _DigestChip(
                          label: '最低日完成率',
                          value:
                              '${summary!.completedTasks}/${summary!.totalTasks} ($_completionRate%)',
                          color: _completionRate >= 70
                              ? AppUI.green
                              : AppUI.orange,
                        ),
                        _DigestChip(
                          label: '自動追蹤',
                          value:
                              '${summary!.autoTrackedCompleted}/${summary!.autoTrackedTotal}',
                          color: AppUI.blue,
                        ),
                        _DigestChip(
                          label: '健康',
                          value:
                              '${summary!.healthCompleted}/${summary!.healthTotal}',
                          color: AppUI.purple,
                        ),
                        _DigestChip(
                          label: '自律房',
                          value:
                              '${summary!.roomCompleted}/${summary!.roomTotal}',
                          color: const Color(0xFF14B8A6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigestChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DigestChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: AppUI.softCardOf(context, color),
      child: Text(
        '$label $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReportGuideRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ReportGuideRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: AppUI.softCardOf(context, color),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NextGoalBox extends StatelessWidget {
  final String text;
  final Color color;
  final Color primaryText;

  const _NextGoalBox({
    required this.text,
    required this.color,
    required this.primaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: primaryText,
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

class _ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportStatCard({
    required this.title,
    required this.value,
    required this.icon,
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
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
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

class _WeeklySignalsCard extends StatelessWidget {
  final DailySummary? bestDay;
  final DailySummary? lowestDay;
  final String weakestArea;
  final String Function(String) shortDate;

  const _WeeklySignalsCard({
    required this.bestDay,
    required this.lowestDay,
    required this.weakestArea,
    required this.shortDate,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本週訊號',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: '最佳日',
                  value: bestDay == null
                      ? '--'
                      : '${shortDate(bestDay!.date)} / ${bestDay!.disciplineScore} 分',
                ),
                _InfoChip(
                  label: '最低日',
                  value: lowestDay == null
                      ? '--'
                      : '${shortDate(lowestDay!.date)} / ${lowestDay!.disciplineScore} 分',
                ),
                _InfoChip(label: '最弱項', value: weakestArea),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
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
