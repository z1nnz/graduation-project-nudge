import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/reminder_center_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the post office exposes its alarm rack and reminder switches', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: ReminderCenterPage()),
      ),
    );
    expect(find.bySemanticsLabel('郵局裡的鬧鐘架'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('鬧鐘架'), 280);
    await tester.scrollUntilVisible(find.byType(Switch).first, 180);
    expect(find.byType(Switch), findsWidgets);
    semantics.dispose();
  });
}
