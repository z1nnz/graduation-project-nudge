import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/community_scene_header.dart';

void main() {
  testWidgets('the courtyard guide describes the scene', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunitySceneHeader(family: true, greeting: '花圃在庭院中央。'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('家庭庭院的嚮導'), findsOneWidget);
    await tester.tap(find.text('問問嚮導'));
    await tester.pumpAndSettle();
    expect(find.text('花圃在庭院中央。'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    semantics.dispose();
  });
}
