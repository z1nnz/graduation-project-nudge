import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/daily_summary.dart';
import '../theme/app_ui.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String selectedRange = '最近 7 天';

  List<DailySummary> _filteredSummaries(List<DailySummary> summaries) {
    final sorted = List<DailySummary>.from(summaries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? startDate;

    switch (selectedRange) {
      case '最近 30 天':
        startDate = today.subtract(const Duration(days: 29));
        break;
      case '本月':
        startDate = DateTime(today.year, today.month, 1);
        break;
      case '最近 7 天':
      default:
        startDate = today.subtract(const Duration(days: 6));
        break;
    }

    return sorted.where((item) {
      final date = DateTime.tryParse(item.date);
      if (date == null) return false;
      final normalized = DateTime(date.year, date.month, date.day);
      return !normalized.isBefore(startDate!);
    }).toList();
  }

  String _rangeTitle() {
    switch (selectedRange) {
      case '最近 30 天':
        return '最近 30 天自律表現摘要';
      case '本月':
        return '本月自律表現摘要';
      case '最近 7 天':
      default:
        return '最近 7 天自律表現摘要';
    }
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

  int _totalRoomCompleted(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.roomCompleted);
  }

  int _totalHealthCompleted(List<DailySummary> summaries) {
    return summaries.fold<int>(0, (sum, item) => sum + item.healthCompleted);
  }

  int _avgCompletionRate(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;

    final ratioSum = summaries.fold<double>(0, (sum, item) {
      if (item.totalTasks == 0) return sum;
      return sum + (item.completedTasks / item.totalTasks);
    });

    return ((ratioSum / summaries.length) * 100).round();
  }

  int _bestCompletedTasks(List<DailySummary> summaries) {
    if (summaries.isEmpty) return 0;
    return summaries
        .map((e) => e.completedTasks)
        .reduce((a, b) => a > b ? a : b);
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

  String _trendText(List<DailySummary> summaries) {
    if (summaries.length < 2) return '目前還沒有足夠資料可判斷趨勢。';

    final firstHalf = summaries.take(summaries.length ~/ 2).toList();
    final secondHalf = summaries.skip(summaries.length ~/ 2).toList();

    final firstAvg = _avgScore(firstHalf);
    final secondAvg = _avgScore(secondHalf);

    if (secondAvg - firstAvg >= 8) return '最近加權自律分數呈上升趨勢。';
    if (firstAvg - secondAvg >= 8) return '最近加權自律分數有些下滑。';
    return '最近加權自律分數大致穩定。';
  }

  String _insightText(List<DailySummary> summaries) {
    if (summaries.isEmpty) {
      return '目前還沒有足夠的紀錄，先持續使用幾天後再來看統計分析。';
    }

    final weakest = _weakestArea(summaries);
    final avgScore = _avgScore(summaries);
    final avgCompletion = _avgCompletionRate(summaries);

    if (avgScore >= 80) {
      return '你這段期間的加權自律分數很穩定，健康、專注或自律房任務有成功撐起核心表現。';
    }

    if (weakest == '任務完成率') {
      return '最近最需要補強的是任務完成率，建議先減少每日任務量，讓完成率提升。';
    }

    if (weakest == '專注任務偏低') {
      return '目前專注資料偏低，建議把專注分鐘數納入每日任務，讓系統自動判定完成。';
    }

    if (weakest == '健康任務偏低') {
      return '健康自動追蹤較弱，建議把睡眠、步數或運動目標設成任務，讓健康資料直接影響加權分數。';
    }

    if (weakest == '自律幣門檻偏低') {
      return '這段期間比較少跨過自律幣門檻，可以優先完成高權重的健康、專注或自律房任務。';
    }

    if (avgCompletion >= 60) {
      return '你已經有一定的任務完成節奏，接下來可以持續優化任務設計。';
    }

    return '最近有在慢慢累積進度，接下來可以把重點放在每日任務的完成率提升。';
  }

  String _scoreLevelTitle(int score) {
    if (score >= 85) return '狀態很好';
    if (score >= 70) return '穩定累積';
    if (score >= 50) return '正在建立節奏';
    if (score >= 20) return '需要縮小目標';
    return '先重新開始';
  }

  String _scoreLevelDescription(int score, int completionRate) {
    if (score >= 85) return '核心任務有穩定完成，可以開始拉高挑戰或加入自律房目標。';
    if (score >= 70) return '整體節奏不錯，接下來看哪一個來源最容易斷掉。';
    if (completionRate < 40) return '任務量可能偏多，先把每日固定任務壓到更容易完成。';
    if (score >= 20) return '已經有紀錄，但高權重來源還不夠穩，可以先補專注或健康任務。';
    return '先完成一個最小任務，讓今天至少跨過 20 分門檻。';
  }

  Color _scoreLevelColor(int score, Color accentColor) {
    if (score >= 85) return AppUI.green;
    if (score >= 70) return accentColor;
    if (score >= 50) return AppUI.orange;
    return const Color(0xFFEF4444);
  }

  String _nextActionText(List<DailySummary> summaries) {
    if (summaries.isEmpty) return '先累積 3 天資料，再讓系統判斷你的主要弱點。';

    switch (_weakestArea(summaries)) {
      case '任務完成率':
        return '把明天的每日固定任務控制在 3 到 5 個，先提高完成率。';
      case '專注任務偏低':
        return '建立一個 25 分鐘專注任務，讓專注頁自動幫你累積分數。';
      case '健康任務偏低':
        return '先選睡眠、步數或運動其中一個健康任務，不要三個一起開。';
      case '自律幣門檻偏低':
        return '優先完成一個高權重自動追蹤任務，讓分數跨過下一個 20 分門檻。';
      default:
        return '維持目前節奏，下一週再觀察趨勢是否持續上升。';
    }
  }

  List<_ScoreReason> _scoreReasons(DailySummary? summary) {
    if (summary == null) {
      return const [
        _ScoreReason(
          title: '還沒有今日資料',
          detail: '完成任務或產生自動追蹤紀錄後，這裡會拆解分數來源。',
          icon: Icons.info_outline,
          color: AppUI.blue,
        ),
      ];
    }

    final reasons = <_ScoreReason>[];
    final taskRate = summary.totalTasks == 0
        ? 0
        : ((summary.completedTasks / summary.totalTasks) * 100).round();

    if (summary.totalTasks == 0) {
      reasons.add(
        const _ScoreReason(
          title: '今天還沒有任務',
          detail: '沒有任務就無法累積加權自律分數，建議先建立一個小任務。',
          icon: Icons.playlist_add_check_outlined,
          color: AppUI.orange,
        ),
      );
    } else if (taskRate < 50) {
      reasons.add(
        _ScoreReason(
          title: '任務完成率偏低',
          detail:
              '今天完成 ${summary.completedTasks}/${summary.totalTasks} 個任務，完成率 $taskRate%。',
          icon: Icons.task_alt_outlined,
          color: AppUI.orange,
        ),
      );
    } else {
      reasons.add(
        _ScoreReason(
          title: '任務完成率有撐住',
          detail:
              '今天完成 ${summary.completedTasks}/${summary.totalTasks} 個任務，完成率 $taskRate%。',
          icon: Icons.check_circle_outline,
          color: AppUI.green,
        ),
      );
    }

    if (summary.focusMinutes < 25) {
      reasons.add(
        _ScoreReason(
          title: '專注分鐘偏少',
          detail: '目前專注 ${summary.focusMinutes} 分鐘，還沒有形成明顯的專注貢獻。',
          icon: Icons.timer_outlined,
          color: AppUI.blue,
        ),
      );
    }

    if (summary.healthTotal > 0 &&
        summary.healthCompleted < summary.healthTotal) {
      reasons.add(
        _ScoreReason(
          title: '健康追蹤未完全達標',
          detail:
              '健康來源完成 ${summary.healthCompleted}/${summary.healthTotal}，睡眠、步數或運動可能還差一點。',
          icon: Icons.favorite_border,
          color: const Color(0xFFEF4444),
        ),
      );
    }

    if (summary.roomTotal > 0 && summary.roomCompleted < summary.roomTotal) {
      reasons.add(
        _ScoreReason(
          title: '自律房目標還沒滿',
          detail:
              '自律房完成 ${summary.roomCompleted}/${summary.roomTotal}，房內目標會影響高權重來源。',
          icon: Icons.groups_outlined,
          color: const Color(0xFF14B8A6),
        ),
      );
    }

    if (summary.nextCoinMilestone > 0) {
      reasons.add(
        _ScoreReason(
          title:
              '還差 ${summary.nextCoinMilestone - summary.disciplineScore} 分到下一檔',
          detail:
              '目前 ${summary.disciplineScore} 分，下一個自律幣門檻是 ${summary.nextCoinMilestone} 分。',
          icon: Icons.monetization_on_outlined,
          color: AppUI.orange,
        ),
      );
    } else {
      reasons.add(
        const _ScoreReason(
          title: '今日分數門檻已滿',
          detail: '已經達到 100 分門檻，今日自律幣主要上限已拿滿。',
          icon: Icons.emoji_events_outlined,
          color: AppUI.green,
        ),
      );
    }

    return reasons;
  }

  void _showScoreReasons(DailySummary? summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _ScoreReasonSheet(
          summary: summary,
          reasons: _scoreReasons(summary),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final summaries = _filteredSummaries(appState.dailySummaries);
    final latestSummary = summaries.isEmpty ? null : summaries.last;

    final bestDay = _bestDay(summaries);
    final weakestArea = _weakestArea(summaries);
    final avgScore = _avgScore(summaries);
    final totalCompletedTasks = _totalCompletedTasks(summaries);
    final totalCoins = _totalCoins(summaries);
    final totalAutoCompleted = _totalAutoCompleted(summaries);
    final totalAutoTasks = _totalAutoTasks(summaries);
    final totalRoomCompleted = _totalRoomCompleted(summaries);
    final totalHealthCompleted = _totalHealthCompleted(summaries);
    final bestCompletedTasks = _bestCompletedTasks(summaries);
    final avgCompletionRate = _avgCompletionRate(summaries);
    final insight = _insightText(summaries);
    final nextAction = _nextActionText(summaries);
    final trendText = _trendText(summaries);
    final levelColor = _scoreLevelColor(avgScore, accentColor);

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('統計分析')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rangeTitle(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$avgScore 分 / 完成率 $avgCompletionRate%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 14),
                Text(
                  trendText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['最近 7 天', '最近 30 天', '本月'].map((range) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _RangeChip(
                    label: range,
                    selected: selectedRange == range,
                    accentColor: accentColor,
                    onTap: () => setState(() => selectedRange = range),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_graph_outlined, color: levelColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '摘要判讀',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ScoreRing(
                        score: avgScore,
                        color: levelColor,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scoreLevelTitle(avgScore),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _scoreLevelDescription(
                                avgScore,
                                avgCompletionRate,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    _showScoreReasons(latestSummary),
                                icon: const Icon(Icons.manage_search, size: 18),
                                label: const Text('為什麼分數低'),
                                style: TextButton.styleFrom(
                                  foregroundColor: levelColor,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MetricStrip(
                    items: [
                      _MetricStripItem(
                        label: '完成率',
                        value: '$avgCompletionRate%',
                        color: AppUI.primary,
                      ),
                      _MetricStripItem(
                        label: '任務',
                        value: '$totalCompletedTasks 個',
                        color: AppUI.green,
                      ),
                      _MetricStripItem(
                        label: '自律幣',
                        value: '+$totalCoins',
                        color: AppUI.orange,
                      ),
                      _MetricStripItem(
                        label: '追蹤',
                        value: '$totalAutoCompleted/$totalAutoTasks',
                        color: AppUI.blue,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_alt_outlined, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '分析結果',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    insight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: primaryText,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniInsightMetric(
                          label: '需補強',
                          value: weakestArea,
                          icon: Icons.warning_amber_outlined,
                          color: AppUI.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniInsightMetric(
                          label: '最佳日',
                          value: bestDay == null
                              ? '--'
                              : '${_shortDate(bestDay.date)} / ${bestDay.disciplineScore}',
                          icon: Icons.emoji_events_outlined,
                          color: AppUI.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _StatisticsInsightDetailPage(
                              rangeLabel: selectedRange,
                              insight: insight,
                              trendText: trendText,
                              nextAction: nextAction,
                              bestDayLabel: bestDay == null
                                  ? '--'
                                  : '${_shortDate(bestDay.date)} / ${bestDay.disciplineScore} 分',
                              weakestArea: weakestArea,
                              sourceLabel:
                                  '健康 $totalHealthCompleted、自律房 $totalRoomCompleted',
                              bestCompletedTasks: bestCompletedTasks,
                              accentColor: accentColor,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('查看完整分析'),
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
                    '這頁看什麼',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InsightGuideRow(
                    icon: Icons.lightbulb_outline,
                    title: '先看系統判讀',
                    subtitle: '它會把目前最重要的問題翻成一句話。',
                    color: accentColor,
                  ),
                  const SizedBox(height: 10),
                  _InsightGuideRow(
                    icon: Icons.flag_outlined,
                    title: '再看下一步',
                    subtitle: '這是最適合拿去執行的具體行動。',
                    color: AppUI.green,
                  ),
                  const SizedBox(height: 10),
                  _InsightGuideRow(
                    icon: Icons.account_tree_outlined,
                    title: '最後看來源',
                    subtitle: '確認分數主要來自健康、自律房或一般任務。',
                    color: AppUI.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '加權分數趨勢',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (summaries.isEmpty)
                    Text(
                      '目前還沒有足夠資料可顯示趨勢。',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        height: 1.5,
                      ),
                    )
                  else
                    SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: summaries.map((summary) {
                          final progress = (summary.disciplineScore / 100)
                              .clamp(0.0, 1.0);
                          final height = 30 + progress * 120;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${summary.disciplineScore}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    width: 28,
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _shortDate(summary.date),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Text(
            '最近紀錄',
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
                  '目前還沒有歷史紀錄。',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ),
            )
          else
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: summaries.reversed.map((summary) {
                    return _DailySummaryRow(summary: summary);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final Color primaryText;
  final Color secondaryText;

  const _ScoreRing({
    required this.score,
    required this.color,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (score / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '分',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricStripItem {
  final String label;
  final String value;
  final Color color;

  const _MetricStripItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _MetricStrip extends StatelessWidget {
  final List<_MetricStripItem> items;

  const _MetricStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? const Color(0xFF242A36)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: items.map((item) {
          final index = items.indexOf(item);
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: index == 0
                    ? null
                    : Border(
                        left: BorderSide(color: Theme.of(context).dividerColor),
                      ),
              ),
              padding: EdgeInsets.only(left: index == 0 ? 0 : 8, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ScoreReason {
  final String title;
  final String detail;
  final IconData icon;
  final Color color;

  const _ScoreReason({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _ScoreReasonSheet extends StatelessWidget {
  final DailySummary? summary;
  final List<_ScoreReason> reasons;

  const _ScoreReasonSheet({required this.summary, required this.reasons});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          4,
          AppUI.pagePadding,
          AppUI.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary == null ? '分數拆解' : '${summary!.date} 分數拆解',
              style: TextStyle(
                color: primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary == null
                  ? '目前還沒有足夠資料。'
                  : '自律分數 ${summary!.disciplineScore} 分，自律幣 +${summary!.coinsEarned} 枚。',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final reason = reasons[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppUI.softCardOf(context, reason.color),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(reason.icon, color: reason.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason.title,
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reason.detail,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemCount: reasons.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCallout extends StatelessWidget {
  final String text;
  final Color color;
  final Color primaryText;
  final Color secondaryText;

  const _InsightCallout({
    required this.text,
    required this.color,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppUI.isDark(context) ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppUI.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系統判讀',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryText,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
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

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accentColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppUI.radiusPill),
          border: Border.all(
            color: selected ? accentColor : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primaryText,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InsightChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryText,
                      fontWeight: FontWeight.w900,
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

class _MiniInsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniInsightMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

class _StatisticsInsightDetailPage extends StatelessWidget {
  final String rangeLabel;
  final String insight;
  final String trendText;
  final String nextAction;
  final String bestDayLabel;
  final String weakestArea;
  final String sourceLabel;
  final int bestCompletedTasks;
  final Color accentColor;

  const _StatisticsInsightDetailPage({
    required this.rangeLabel,
    required this.insight,
    required this.trendText,
    required this.nextAction,
    required this.bestDayLabel,
    required this.weakestArea,
    required this.sourceLabel,
    required this.bestCompletedTasks,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('分析詳情')),
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
                    Icons.psychology_alt_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rangeLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '完整分析結果',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
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
                  _InsightCallout(
                    text: insight,
                    color: accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 14),
                  _NextActionBox(
                    text: nextAction,
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
                    '關鍵指標',
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
                      _InsightChip(
                        label: '最佳日',
                        value: bestDayLabel,
                        icon: Icons.emoji_events_outlined,
                        color: AppUI.orange,
                      ),
                      _InsightChip(
                        label: '需補強',
                        value: weakestArea,
                        icon: Icons.warning_amber_outlined,
                        color: const Color(0xFFB45309),
                      ),
                      _InsightChip(
                        label: '來源',
                        value: sourceLabel,
                        icon: Icons.account_tree_outlined,
                        color: const Color(0xFF14B8A6),
                      ),
                      _InsightChip(
                        label: '最多',
                        value: '$bestCompletedTasks 個任務',
                        icon: Icons.task_alt_outlined,
                        color: AppUI.green,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.trending_up_outlined, color: accentColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trendText,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
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

class _NextActionBox extends StatelessWidget {
  final String text;
  final Color color;
  final Color primaryText;

  const _NextActionBox({
    required this.text,
    required this.color,
    required this.primaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primaryText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightGuideRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InsightGuideRow({
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

class _DailySummaryRow extends StatelessWidget {
  final DailySummary summary;

  const _DailySummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = context.watch<AppState>().currentIconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              summary.date.length >= 10
                  ? summary.date.substring(5)
                  : summary.date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryText,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (summary.disciplineScore / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 54,
            child: Text(
              '${summary.disciplineScore}分',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '+${summary.coinsEarned}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppUI.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
