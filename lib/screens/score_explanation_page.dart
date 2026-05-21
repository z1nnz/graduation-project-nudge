import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class ScoreExplanationPage extends StatelessWidget {
  const ScoreExplanationPage({super.key});

  int _completedTasks(AppState appState) {
    return appState.tasks.where((task) => task['done'] == true).length;
  }

  int _taskScore(AppState appState) {
    final totalTasks = appState.tasks.length;
    final completedTasks = _completedTasks(appState);
    if (totalTasks == 0) return 0;
    return ((completedTasks / totalTasks) * 30).round();
  }

  int _focusScore(AppState appState) {
    return ((appState.focusMinutes / 120).clamp(0, 1) * 30).round();
  }

  int _sleepScore(AppState appState) {
    if (!appState.isHealthConnected) return 0;
    return ((appState.sleepHours / 8).clamp(0, 1) * 15).round();
  }

  int _stepsScore(AppState appState) {
    if (!appState.isHealthConnected) return 0;
    return ((appState.steps / 8000).clamp(0, 1) * 15).round();
  }

  int _exerciseScore(AppState appState) {
    if (!appState.isHealthConnected) return 0;
    return ((appState.exerciseMinutes / 30).clamp(0, 1) * 10).round();
  }

  int _totalScore(AppState appState) {
    return _taskScore(appState) +
        _focusScore(appState) +
        _sleepScore(appState) +
        _stepsScore(appState) +
        _exerciseScore(appState);
  }

  String _scoreLevel(int score) {
    if (score >= 85) return '非常穩定';
    if (score >= 70) return '表現不錯';
    if (score >= 50) return '持續進步中';
    return '還有提升空間';
  }

  String _scoreAdvice(AppState appState) {
    final taskScore = _taskScore(appState);
    final focusScore = _focusScore(appState);
    final sleepScore = _sleepScore(appState);
    final stepsScore = _stepsScore(appState);
    final exerciseScore = _exerciseScore(appState);

    final scores = <String, int>{
      '任務完成': taskScore,
      '專注時間': focusScore,
      '睡眠狀態': sleepScore,
      '步數活動': stepsScore,
      '運動表現': exerciseScore,
    };

    final sorted = scores.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final weakest = sorted.first.key;

    switch (weakest) {
      case '任務完成':
        return '目前最值得先補強的是任務完成率，先把今天最重要的一件事完成，分數就會明顯提升。';
      case '專注時間':
        return '目前最值得先補強的是專注時間，先完成一輪專注會最有效。';
      case '睡眠狀態':
        return '目前睡眠分數偏弱，今晚提早休息會對整體分數幫助很大。';
      case '步數活動':
        return '目前步數偏低，可以安排一小段散步來補強。';
      case '運動表現':
        return '目前運動分數偏低，補一段短時間運動就能改善。';
      default:
        return '你目前的分數結構已經不錯，穩定維持就很好。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;

    final taskScore = _taskScore(appState);
    final focusScore = _focusScore(appState);
    final sleepScore = _sleepScore(appState);
    final stepsScore = _stepsScore(appState);
    final exerciseScore = _exerciseScore(appState);
    final totalScore = _totalScore(appState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自律分數說明'),
      ),
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
                    Icons.auto_graph_outlined,
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
                        '目前總分',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$totalScore 分',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _scoreLevel(totalScore),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
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
                  Row(
                    children: [
                      Icon(Icons.pie_chart_outline, color: accentColor),
                      const SizedBox(width: 8),
                      const Text('分數組成', style: AppUI.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ScoreRow(
                    title: '任務完成',
                    subtitle: '最高 30 分',
                    score: taskScore,
                    maxScore: 30,
                    color: AppUI.primary,
                  ),
                  const SizedBox(height: 12),
                  _ScoreRow(
                    title: '專注時間',
                    subtitle: '最高 30 分',
                    score: focusScore,
                    maxScore: 30,
                    color: AppUI.blue,
                  ),
                  const SizedBox(height: 12),
                  _ScoreRow(
                    title: '睡眠狀態',
                    subtitle: '最高 15 分',
                    score: sleepScore,
                    maxScore: 15,
                    color: AppUI.purple,
                  ),
                  const SizedBox(height: 12),
                  _ScoreRow(
                    title: '步數活動',
                    subtitle: '最高 15 分',
                    score: stepsScore,
                    maxScore: 15,
                    color: AppUI.green,
                  ),
                  const SizedBox(height: 12),
                  _ScoreRow(
                    title: '運動表現',
                    subtitle: '最高 10 分',
                    score: exerciseScore,
                    maxScore: 10,
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
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rule_folder_outlined, color: accentColor),
                      const SizedBox(width: 8),
                      const Text('計算規則', style: AppUI.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _RuleItem(text: '任務完成率會換算成最高 30 分。'),
                  const _RuleItem(text: '專注時間以 120 分鐘為滿分基準，最高 30 分。'),
                  const _RuleItem(text: '睡眠以 8 小時為滿分基準，最高 15 分。'),
                  const _RuleItem(text: '步數以 8000 步為滿分基準，最高 15 分。'),
                  const _RuleItem(text: '運動以 30 分鐘為滿分基準，最高 10 分。'),
                  const SizedBox(height: 8),
                  const Text(
                    '如果尚未同步健康資料，健康相關項目分數會暫時為 0。',
                    style: AppUI.body,
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
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: accentColor),
                      const SizedBox(width: 8),
                      const Text('目前最值得補強', style: AppUI.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _scoreAdvice(appState),
                    style: AppUI.body.copyWith(color: AppUI.textPrimaryOf(context)),
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
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: accentColor),
                      const SizedBox(width: 8),
                      const Text('快速提升分數的方法', style: AppUI.sectionTitle),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _RuleItem(text: '先完成今天最重要的一個任務。'),
                  const _RuleItem(text: '至少完成一輪專注。'),
                  const _RuleItem(text: '同步健康資料，補足睡眠、步數與運動資訊。'),
                  const _RuleItem(text: '先求穩定，不一定要一次做到滿分。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int score;
  final int maxScore;
  final Color color;

  const _ScoreRow({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.maxScore,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxScore == 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
            ),
            Text(
              '$score / $maxScore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppUI.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;

  const _RuleItem({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 8,
              color: AppUI.textSecondaryOf(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppUI.body,
            ),
          ),
        ],
      ),
    );
  }
}