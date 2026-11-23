import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/focus_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the companion reads while the focus timer runs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await tester.runAsync(appState.loadAllLocalData);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: FocusPage()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('focus-companion')), findsOneWidget);
    expect(find.byKey(const Key('pose-effect-read')), findsNothing);

    await tester.scrollUntilVisible(
      find.text('開始專注'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('開始專注'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.byKey(const Key('pose-effect-read')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();
  });
}
