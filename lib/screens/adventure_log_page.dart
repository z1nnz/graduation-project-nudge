import 'package:flutter/material.dart';

import '../models/adventure_log.dart';
import '../models/avatar_profile.dart';
import '../models/companion_pose.dart';
import '../widgets/companion_sprite.dart';

const _font = 'Cubic11';
const _ink = Color(0xFF3A1D0C);
const _soft = Color(0xFF8A5A34);
const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
const _bookColors = [
  Color(0xFF7B4FB8),
  Color(0xFFD8452E),
  Color(0xFF3F7FBF),
  Color(0xFF4C8A3A),
  Color(0xFFE0A84A),
];

/// The week as one page of an adventure journal: a stack of books per day
/// (taller for more focus), the week's totals, the best day and a line from
/// the companion. Laid out to be screenshot and shared.
class AdventureLogPage extends StatelessWidget {
  const AdventureLogPage({
    super.key,
    required this.log,
    required this.profile,
    required this.onOpenStatistics,
  });

  final AdventureLog log;
  final AvatarProfile profile;
  final VoidCallback onOpenStatistics;

  static String _minutes(int m) {
    if (m < 60) return '$m 分鐘';
    final h = m ~/ 60, rest = m % 60;
    return rest == 0 ? '$h 小時' : '$h 小時 $rest 分';
  }

  static String _short(String date) {
    final d = DateTime.parse(date);
    return '${d.month}/${d.day}';
  }

  static String _weekday(String date) =>
      _weekdays[DateTime.parse(date).weekday - 1];

  @override
  Widget build(BuildContext context) {
    final best = log.bestDay;
    final maxFocus = log.days.fold(
      1,
      (m, d) => d.focusMinutes > m ? d.focusMinutes : m,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF3B2418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B2418),
        foregroundColor: const Color(0xFFFFE6A3),
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6E7C8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _soft, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '冒險日誌',
                  style: TextStyle(
                    fontFamily: _font,
                    fontSize: 28,
                    color: _ink,
                  ),
                ),
                Text(
                  '${_short(log.days.first.date)} – ${_short(log.days.last.date)}',
                  style: const TextStyle(
                    fontFamily: _font,
                    fontSize: 14,
                    color: _soft,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < log.days.length; i++)
                        Expanded(
                          child: _DayColumn(
                            index: i,
                            day: log.days[i],
                            label: _weekday(log.days[i].date),
                            books: log.days[i].focusMinutes == 0
                                ? 0
                                : (1 + 7 * log.days[i].focusMinutes / maxFocus)
                                      .floor()
                                      .clamp(1, 8),
                            today: i == log.days.length - 1,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: _soft, thickness: 2, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _Total('專注', _minutes(log.totalFocusMinutes)),
                    ),
                    Expanded(child: _Total('完成委託', '${log.questsDone} 件')),
                    Expanded(child: _Total('出發', '${log.activeDays} 天')),
                  ],
                ),
                if (best != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD76A), Color(0xFFFF8F3A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF8A4A10),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '最棒的一天：週${_weekday(best.date)} ${best.focusMinutes} 分鐘',
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: CompanionSprite(
                        profile: profile,
                        pose: log.activeDays >= 5
                            ? CompanionPose.cheer
                            : CompanionPose.idle,
                        size: 86,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAF0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _soft, width: 2),
                        ),
                        child: Text(
                          log.companionLine,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 14,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '截圖就能分享你的冒險',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          color: _soft,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenStatistics,
                      child: const Text(
                        '詳細統計',
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 15,
                          color: _soft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.index,
    required this.day,
    required this.label,
    required this.books,
    required this.today,
  });

  final int index;
  final AdventureDay day;
  final String label;
  final int books;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (day.questsDone > 0)
          const Text(
            '★',
            style: TextStyle(color: Color(0xFFE0A84A), fontSize: 14),
          ),
        SizedBox(
          key: Key('log-books-$index'),
          width: 28,
          height: books * 12.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var b = 0; b < books; b++)
                Container(
                  height: 10,
                  margin: EdgeInsets.only(
                    top: 2,
                    left: (b + index) % 3 * 2.0,
                    right: (b + index + 1) % 3 * 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: _bookColors[(b + index) % _bookColors.length],
                    border: Border.all(color: _ink, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          key: today ? const Key('log-today') : null,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: today
              ? BoxDecoration(
                  color: const Color(0xFFE0A84A),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: _ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: _font, fontSize: 12, color: _soft),
        ),
        Text(
          value,
          style: const TextStyle(fontFamily: _font, fontSize: 18, color: _ink),
        ),
      ],
    );
  }
}
