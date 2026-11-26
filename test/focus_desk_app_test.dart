import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/focus_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the hourglass empties with the timer and turns over for the break', () {
    final full = HourglassPainter(left: 1, flipped: false);
    final half = HourglassPainter(left: 0.5, flipped: false);
    expect(full.shouldRepaint(half), isTrue);
    expect(
      HourglassPainter(left: 0.5, flipped: true).shouldRepaint(half),
      isTrue,
    );
    expect(
      half.shouldRepaint(HourglassPainter(left: 0.5, flipped: false)),
      isFalse,
    );
  });

  testWidgets(
    'the desk shows the companion and the hourglass on phone and desktop',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      await tester.runAsync(appState.loadAllLocalData);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: FocusPage(immersive: true)),
        ),
      );
      for (final size in const [Size(390, 844), Size(1280, 800)]) {
        tester.view.physicalSize = size;
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump();
        }
        expect(
          find.byKey(const Key('desk-hourglass')),
          findsOneWidget,
          reason: '$size',
        );
        expect(
          find.byKey(const Key('desk-player')),
          findsOneWidget,
          reason: '$size',
        );
        expect(find.bySemanticsLabel(RegExp('沙漏：專注還剩 100%')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      appState.dispose();
    },
  );
}
