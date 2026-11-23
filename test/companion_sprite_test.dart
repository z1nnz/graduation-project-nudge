import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/companion_pose.dart';
import 'package:nudge/widgets/companion_sprite.dart';

Future<void> _pump(
  WidgetTester tester,
  CompanionPose pose, {
  int face = 1,
  bool still = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Center(
          child: CompanionSprite(
            profile: AvatarProfile.initial().copyWith(faceShapeIndex: face),
            pose: pose,
            size: 160,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Iterable<String> _assets(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<AssetImage>()
    .map((a) => a.assetName);

void main() {
  testWidgets('first-stage characters show their generated pose art', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester, CompanionPose.read, face: 0));
    expect(_assets(tester), contains('assets/avatar/poses/pose_0_read.png'));
  });

  testWidgets('other stages fall back to the base sprite with an effect', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester, CompanionPose.sleep, face: 1));
    expect(
      _assets(tester),
      isNot(contains(startsWith('assets/avatar/poses/'))),
    );
    expect(find.byKey(const Key('pose-effect-sleep')), findsOneWidget);
  });

  testWidgets('idle has no effect overlay', (tester) async {
    await tester.runAsync(() => _pump(tester, CompanionPose.idle, face: 0));
    expect(find.byKey(const Key('pose-effect-sleep')), findsNothing);
    expect(find.byKey(const Key('pose-effect-read')), findsNothing);
  });

  testWidgets('reduced motion stops every pose animation', (tester) async {
    await tester.runAsync(
      () => _pump(tester, CompanionPose.cheer, face: 1, still: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
