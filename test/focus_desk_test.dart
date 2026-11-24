import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/focus_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(rootBundle.clear);

  testWidgets(
    'desk mode is the cabin with a wall clock; starting makes the companion read',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
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
      for (
        var i = 0;
        i < 10 && find.byKey(const Key('desk-clock')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.byKey(const Key('desk-clock')), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byKey(const Key('pose-effect-read')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('desk-sound')),
          matching: find.text('聲音'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('開始專注'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.byKey(const Key('pose-effect-read')), findsOneWidget);
      expect(find.text('暫停'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      appState.dispose();
    },
  );

  testWidgets('ending desk focus shows the game result screen', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await tester.runAsync(appState.loadAllLocalData);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const FocusPage(immersive: true),
                ),
              ),
              child: const Text('cabin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('cabin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (
      var i = 0;
      i < 10 && find.byKey(const Key('desk-clock')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.tap(find.text('開始專注'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('結束並記錄'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('結束並記錄'),
      ),
    );
    for (var i = 0; i < 10 && find.text('專注完成！').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('專注完成！'), findsOneWidget);
    expect(find.text('金幣與經驗：雲端確認中…'), findsOneWidget);
    await tester.tap(find.text('回小屋'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('專注完成！'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('desk-clock')), findsNothing);
    expect(find.text('cabin'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();
  });
}
