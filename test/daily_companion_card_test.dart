import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/daily_next_action.dart';
import 'package:nudge/widgets/daily_companion_card.dart';

void main() {
  testWidgets('companion suggests a task without completing or starting it', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyCompanionCard(
            action: DailyNextAction.resolve([
              {'title': '讀一頁書'},
            ]),
            profile: AvatarProfile.initial(),
            onOpenTasks: () => opens++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('讀一頁書'), findsOneWidget);
    expect(find.textContaining('正式獎勵以雲端確認為準'), findsOneWidget);
    expect(opens, 0);
    await tester.tap(find.text('查看我的任務'));
    expect(opens, 1);
  });
}
