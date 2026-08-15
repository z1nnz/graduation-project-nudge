import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/discipline_identity_snapshot.dart';
import 'package:nudge/screens/discipline_identity_page.dart';

DisciplineIdentitySnapshot snapshot({
  DisciplineRecoveryState recoveryState = DisciplineRecoveryState.gentleReturn,
}) {
  return DisciplineIdentitySnapshot(
    userId: 'user-1',
    personaKey: DisciplinePersonaKey.comebackBuilder,
    personaTitle: '復原建築師',
    personaDescription: '中斷後仍願意重新開始。',
    recoveryState: recoveryState,
    recommendedFocusMinutes: 10,
    recoveryMessage: '紀錄沒有消失；用 10 分鐘回來。',
    activeDays: 4,
    completedSessions: 7,
    focusMinutes: 120,
    exerciseMinutes: 30,
    activityKinds: const ['exercise', 'focus'],
    lastActiveDay: '2026-08-15',
    windowStartedAt: DateTime.utc(2026, 7, 18, 21),
    windowEndedAt: DateTime.utc(2026, 8, 15, 10),
    updatedAt: DateTime.utc(2026, 8, 15, 10),
  );
}

void main() {
  testWidgets('identity card explains evidence and private boundary', (
    tester,
  ) async {
    int? recoveryMinutes;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DisciplineIdentityCard(
            snapshot: snapshot(),
            onStartRecovery: (minutes) => recoveryMinutes = minutes,
          ),
        ),
      ),
    );

    expect(find.text('復原建築師'), findsOneWidget);
    expect(find.text('近 28 個自律日'), findsOneWidget);
    expect(find.text('目前僅自己可見'), findsOneWidget);
    expect(find.textContaining('不扣分，也不需要補做'), findsOneWidget);
    expect(find.text('開始 10 分鐘復原步驟'), findsOneWidget);

    await tester.tap(find.text('開始 10 分鐘復原步驟'));
    expect(recoveryMinutes, 10);
  });

  testWidgets('starting state is explicitly not a personality diagnosis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DisciplineIdentityCard(
            snapshot: snapshot(recoveryState: DisciplineRecoveryState.starting),
            onStartRecovery: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('不是性格診斷'), findsOneWidget);
    expect(find.textContaining('由 canonical Activity Ledger'), findsOneWidget);
  });
}
