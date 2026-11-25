import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/focus_tower_piece.dart';
import 'package:nudge/theme/game_ui.dart';

void main() {
  testWidgets('a room preview selects the existing template', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: FocusTowerRoomPreview(
              art: 'library',
              label: '考試衝刺',
              description: '一起讀書',
              selected: false,
              onTap: () => selected = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('考試衝刺，一起讀書'), findsOneWidget);
    await tester.tap(find.text('考試衝刺'));
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('the tower gate is accessible and opens search at 360px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.15),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: FocusTowerGate(onExplore: () => opened = true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('鐘鐘，專注塔守門人')), findsOneWidget);
    expect(find.byType(FocusTowerPiece), findsOneWidget);
    expect(
      tester.getSize(find.byType(GameButton)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('問問鐘鐘'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
