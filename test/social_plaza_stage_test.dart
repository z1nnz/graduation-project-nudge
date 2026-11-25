import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/theme/game_ui.dart';
import 'package:nudge/widgets/social_plaza_stage.dart';

void main() {
  testWidgets('the plaza sign opens the efforts board', (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialPlazaStage(
            title: '小鎮廣場',
            objects: [
              Semantics(
                label: '公告欄，查看本週努力榜',
                child: GameButton(label: '公告欄', onPressed: () => opened = true),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('公告欄，查看本週努力榜'), findsOneWidget);
    await tester.tap(find.text('公告欄'));
    expect(opened, isTrue);
    semantics.dispose();
  });
}
