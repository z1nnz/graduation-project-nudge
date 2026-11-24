import 'package:flutter/material.dart';

class BossSpecies {
  const BossSpecies(this.name, this.body, this.dark);
  final String name;
  final Color body;
  final Color dark;
}

/// The room's daily shared goal, told as a fight: every minute anyone in the
/// room focuses is damage to this week's procrastination monster. Nobody is
/// ranked; the whole room wins together.
class ProcrastinationBoss {
  const ProcrastinationBoss._({
    required this.species,
    required this.goalSeconds,
    required this.doneSeconds,
  });

  factory ProcrastinationBoss.of(
    DateTime now, {
    required int goalSeconds,
    required int doneSeconds,
  }) {
    // Weeks since a Monday epoch, so the monster changes every Monday.
    final epoch = DateTime(2024, 1, 1);
    final day = DateTime(now.year, now.month, now.day);
    final week = day.difference(epoch).inDays ~/ 7;
    return ProcrastinationBoss._(
      species: roster[week % roster.length],
      goalSeconds: goalSeconds,
      doneSeconds: doneSeconds,
    );
  }

  static const roster = [
    BossSpecies('拖延史萊姆', Color(0xFF7BD389), Color(0xFF2F7A47)),
    BossSpecies('滑手機幽靈', Color(0xFFB8A6F2), Color(0xFF5B4A9E)),
    BossSpecies('等一下怪', Color(0xFFFFB86B), Color(0xFFA35A12)),
    BossSpecies('明天再說龍', Color(0xFFFF8A8A), Color(0xFF9E2F3B)),
  ];

  final BossSpecies species;
  final int goalSeconds;
  final int doneSeconds;

  bool get active => goalSeconds > 0;
  int get hpSeconds => (goalSeconds - doneSeconds).clamp(0, goalSeconds);
  double get hpFraction => goalSeconds <= 0 ? 0 : hpSeconds / goalSeconds;
  bool get defeated => active && hpSeconds == 0;

  String get line {
    if (defeated) return '全房一起打倒了${species.name}！';
    if (hpFraction > 0.66) return '嘿嘿，今天也一起偷懶吧～';
    if (hpFraction > 0.33) return '唔……你們怎麼這麼專心！';
    return '快、快撐不住了……';
  }

  static String clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}
