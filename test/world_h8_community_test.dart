import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/community_scene_header.dart';
import 'package:nudge/widgets/living_world/living_community_header.dart';

void main() {
  test('each section gets a place in the art, extras stay as buttons', () {
    final spots = livingCommunitySpots(
      family: true,
      labels: List.generate(8, (i) => '區$i'),
      open: (_) {},
    );
    expect(spots.length, courtyardSlots.length);
    expect(spots.first.label, '區0');
    for (final rect in [...courtyardSlots, ...hallSlots]) {
      expect(rect.left >= 0 && rect.right <= 1, isTrue);
      expect(rect.top >= 0 && rect.bottom <= 1, isTrue);
    }
  });

  testWidgets('walking to a spot opens the same section as its button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 900),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: LivingCommunitySections(
              family: true,
              greeting: '歡迎回家',
              sections: const [
                CommunitySceneSection(
                  label: '家庭目標',
                  icon: Icons.flag,
                  children: [Text('目標內容')],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('目標內容'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('living-spot-section-0')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.text('目標內容'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  test('guardian and group pages only swap the scene widget', () {
    for (final page in [
      'guardian_center_page',
      'guardian_parent_page',
      'group_management_page',
      'group_manager_page',
    ]) {
      final source = File('lib/screens/$page.dart').readAsStringSync();
      expect(source, contains('LivingCommunitySections('), reason: page);
      expect(source, isNot(contains('body: CommunitySceneSections(')));
    }
  });
}
