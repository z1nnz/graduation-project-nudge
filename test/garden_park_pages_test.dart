import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/garden_park_pages.dart';

void main() {
  testWidgets('the park map lists its rides as labelled buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const ParkScenePage(),
      ),
    );
    await tester.pump();
    for (final label in [
      '摩天輪：接星星',
      '撈魚攤：星光釣魚',
      '舞台：鐘塔節奏',
      '旋轉木馬：記憶配對',
      '跳房子：跳一跳',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(ParkScenePage.arcade.toString(), endsWith('/arcade.html'));
    semantics.dispose();
  });
}
