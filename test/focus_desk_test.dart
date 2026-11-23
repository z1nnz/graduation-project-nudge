import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/focus_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(rootBundle.clear);

  testWidgets('desk mode is the cabin with a wall clock; starting makes the companion read', (tester) async {
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
    for (var i = 0; i < 10 && find.byKey(const Key('desk-clock')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const Key('desk-clock')), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(const Key('pose-effect-read')), findsNothing);

    await tester.tap(find.text('開始專注'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.byKey(const Key('pose-effect-read')), findsOneWidget);
    expect(find.text('暫停'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();
  });
}
