import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/procrastination_boss.dart';
import 'package:nudge/widgets/procrastination_boss_card.dart';

void main() {
  final monday = DateTime(2026, 11, 23);

  test('a different monster each week, same one all week', () {
    final a = ProcrastinationBoss.of(monday, goalSeconds: 3600, doneSeconds: 0);
    final b = ProcrastinationBoss.of(
      monday.add(const Duration(days: 6)),
      goalSeconds: 3600,
      doneSeconds: 0,
    );
    final c = ProcrastinationBoss.of(
      monday.add(const Duration(days: 7)),
      goalSeconds: 3600,
      doneSeconds: 0,
    );
    expect(a.species.name, b.species.name);
    expect(a.species.name, isNot(c.species.name));
  });

  test('room focus time is damage; HP never goes below zero', () {
    final b = ProcrastinationBoss.of(
      monday,
      goalSeconds: 3 * 3600,
      doneSeconds: 3600,
    );
    expect(b.hpFraction, closeTo(2 / 3, 1e-9));
    expect(b.defeated, isFalse);
    final done = ProcrastinationBoss.of(
      monday,
      goalSeconds: 3600,
      doneSeconds: 9000,
    );
    expect(done.hpFraction, 0);
    expect(done.defeated, isTrue);
  });

  test('no goal means no fight', () {
    final b = ProcrastinationBoss.of(monday, goalSeconds: 0, doneSeconds: 10);
    expect(b.active, isFalse);
  });

  test('taunts change as it weakens', () {
    String line(int done) => ProcrastinationBoss.of(
      monday,
      goalSeconds: 100,
      doneSeconds: done,
    ).line;
    expect(line(0), isNot(line(60)));
    expect(line(100), contains('打倒'));
  });

  testWidgets('card shows name, HP and the defeated state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProcrastinationBossCard(
              boss: ProcrastinationBoss.of(
                monday,
                goalSeconds: 3 * 3600,
                doneSeconds: 3600,
              ),
            ),
          ),
        ),
      ),
    );
    final boss = ProcrastinationBoss.of(
      monday,
      goalSeconds: 3 * 3600,
      doneSeconds: 3600,
    );
    expect(find.text(boss.species.name), findsOneWidget);
    expect(find.text('HP 2:00 / 3:00'), findsOneWidget);
    expect(find.byKey(const Key('boss-defeated')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ProcrastinationBossCard(
              boss: ProcrastinationBoss.of(
                monday,
                goalSeconds: 3600,
                doneSeconds: 3600,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('boss-defeated')), findsOneWidget);
  });
}
