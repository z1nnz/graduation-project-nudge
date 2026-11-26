import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/reminder_center_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/widgets/npc_dialog.dart';
import 'package:nudge/widgets/sprite_animation.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the post office exposes its alarm rack and reminder switches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ReminderCenterPage(),
        ),
      ),
    );
    expect(find.bySemanticsLabel('查看郵局裡的鬧鐘架'), findsOneWidget);
    expect(find.bySemanticsLabel('打開郵局裡的信箱'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    final postman = find.byWidgetPredicate(
      (w) => w is CharacterSprite && w.character.id == 'letty',
    );
    expect(tester.widget<CharacterSprite>(postman).character.id, 'letty');
    await tester.tap(postman);
    await tester.pumpAndSettle();
    expect(find.byType(NpcDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打開信箱'));
    await tester.pumpAndSettle();
    expect(find.text('站內通知'), findsOneWidget);
    await tester.tap(find.text('查看鬧鐘架'));
    await tester.pumpAndSettle();
    expect(find.text('站內通知'), findsNothing);
    await tester.scrollUntilVisible(find.text('鬧鐘架'), 280);
    await tester.scrollUntilVisible(find.byType(Switch).first, 180);
    expect(find.byType(Switch), findsWidgets);
    semantics.dispose();
  });
}
