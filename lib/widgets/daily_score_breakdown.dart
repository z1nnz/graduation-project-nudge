import 'package:flutter/material.dart';

import '../models/daily_summary.dart';
import '../theme/app_ui.dart';

class DailyScoreBreakdownCard extends StatelessWidget {
  final DailySummary summary;

  const DailyScoreBreakdownCard({super.key, required this.summary});

  int get _completionRate {
    if (summary.totalTasks == 0) return 0;
    return ((summary.completedTasks / summary.totalTasks) * 100).round();
  }

  List<_BreakdownReason> get _reasons {
    final reasons = <_BreakdownReason>[];
    final completionRate = _completionRate;

    reasons.add(
      _BreakdownReason(
        title: completionRate >= 70 ? '任務完成率穩定' : '任務完成率偏低',
        value: '${summary.completedTasks}/${summary.totalTasks}',
        detail: '完成率 $completionRate%，這是每日分數最主要的基礎。',
        icon: Icons.task_alt_outlined,
        color: completionRate >= 70 ? AppUI.green : AppUI.orange,
        progress: completionRate / 100,
      ),
    );

    reasons.add(
      _BreakdownReason(
        title: '自動追蹤來源',
        value: '${summary.autoTrackedCompleted}/${summary.autoTrackedTotal}',
        detail: '來源：${summary.sourceSummary}。',
        icon: Icons.sync_outlined,
        color: AppUI.blue,
        progress: summary.autoTrackedTotal == 0
            ? 0
            : summary.autoTrackedCompleted / summary.autoTrackedTotal,
      ),
    );

    reasons.add(
      _BreakdownReason(
        title: '健康任務',
        value: '${summary.healthCompleted}/${summary.healthTotal}',
        detail:
            '睡眠 ${summary.sleepHours.toStringAsFixed(1)} 小時、步數 ${summary.steps}、運動 ${summary.exerciseMinutes} 分。',
        icon: Icons.favorite_border,
        color: AppUI.purple,
        progress: summary.healthTotal == 0
            ? 0
            : summary.healthCompleted / summary.healthTotal,
      ),
    );

    reasons.add(
      _BreakdownReason(
        title: '自律房與專注',
        value: '${summary.roomCompleted}/${summary.roomTotal}',
        detail:
            '自律房完成 ${summary.roomCompleted}/${summary.roomTotal}，專注 ${summary.focusMinutes} 分鐘。',
        icon: Icons.groups_2_outlined,
        color: const Color(0xFF14B8A6),
        progress: summary.roomTotal == 0
            ? 0
            : summary.roomCompleted / summary.roomTotal,
      ),
    );

    if (summary.nextCoinMilestone > 0) {
      reasons.add(
        _BreakdownReason(
          title: '下一個自律幣門檻',
          value: '${summary.nextCoinMilestone} 分',
          detail:
              '目前 ${summary.disciplineScore} 分，還差 ${summary.nextCoinMilestone - summary.disciplineScore} 分到下一檔。',
          icon: Icons.monetization_on_outlined,
          color: AppUI.orange,
          progress: summary.disciplineScore / summary.nextCoinMilestone,
        ),
      );
    }

    return reasons;
  }

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
            Row(
              children: [
                const Icon(Icons.manage_search, color: AppUI.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '當日分數摘要',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '+${summary.coinsEarned} 枚',
                  style: TextStyle(
                    color: AppUI.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _SummaryMetric(
                  title: '自律分數',
                  value: '${summary.disciplineScore}',
                  unit: '分',
                  color: AppUI.primary,
                ),
                const SizedBox(width: 10),
                _SummaryMetric(
                  title: '任務',
                  value: '${summary.completedTasks}/${summary.totalTasks}',
                  unit: '',
                  color: AppUI.green,
                ),
                const SizedBox(width: 10),
                _SummaryMetric(
                  title: '自動追蹤',
                  value:
                      '${summary.autoTrackedCompleted}/${summary.autoTrackedTotal}',
                  unit: '',
                  color: AppUI.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '這一天主要由任務完成率、自動追蹤、健康資料與自律房表現共同構成。',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BreakdownReasonTile(reason: reason),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final Color color;

  const _SummaryMetric({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppUI.softCardOf(context, color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  color: primaryText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownReason {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final double progress;

  const _BreakdownReason({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.progress,
  });
}

class _BreakdownReasonTile extends StatelessWidget {
  final _BreakdownReason reason;

  const _BreakdownReasonTile({required this.reason});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: AppUI.softCardOf(context, reason.color),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(reason.icon, color: reason.color, size: 22),
          title: Text(
            reason.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          trailing: Text(
            reason.value,
            style: TextStyle(
              color: reason.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: reason.progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(reason.color),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reason.detail,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
