import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/confirmed_activity_feedback.dart';
import 'package:nudge/widgets/focus_result_sheet.dart';

void main() {
  Future<bool? Function()> open(
    WidgetTester tester,
    ValueNotifier<ConfirmedActivityFeedback?> feedback, {
    int? restMinutes = 5,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showFocusResult(
                context,
                profile: AvatarProfile.initial(),
                focusMinutes: 25,
                round: 2,
                restMinutes: restMinutes,
                feedback: feedback,
              );
              done = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    addTearDown(() => expect(done, isTrue, reason: 'sheet closed'));
    return () => result;
  }

  testWidgets('shows the finished focus like a quest reward', (tester) async {
    final feedback = ValueNotifier<ConfirmedActivityFeedback?>(null);
    await open(tester, feedback);
    expect(find.text('專注完成！'), findsOneWidget);
    expect(find.text('25 分鐘'), findsOneWidget);
    expect(find.text('第 2 輪'), findsOneWidget);
    // Rewards are never guessed: they wait for the Cloud.
    expect(find.text('金幣與經驗：雲端確認中…'), findsOneWidget);
    feedback.value = const ConfirmedActivityFeedback('r1', '專注');
    await tester.pump();
    expect(find.text('✓ 雲端已確認這次專注'), findsOneWidget);
    await tester.tap(find.text('回小屋'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a feedback that was already there does not count', (
    tester,
  ) async {
    final feedback = ValueNotifier<ConfirmedActivityFeedback?>(
      const ConfirmedActivityFeedback('old', '專注'),
    );
    await open(tester, feedback);
    expect(find.text('金幣與經驗：雲端確認中…'), findsOneWidget);
    await tester.tap(find.text('回小屋'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('starting the rest returns true; no rest hides the button', (
    tester,
  ) async {
    final feedback = ValueNotifier<ConfirmedActivityFeedback?>(null);
    final result = await open(tester, feedback);
    await tester.tap(find.text('開始休息 5 分鐘'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('專注完成！'), findsNothing);
    expect(result(), isTrue);

    await open(tester, feedback, restMinutes: null);
    expect(find.textContaining('開始休息'), findsNothing);
    await tester.tap(find.text('回小屋'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
