import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/living_world/plaza_podium.dart';

void main() {
  test('the podium stands 2nd, 1st, 3rd from left to right', () {
    expect(podiumOrder(0), isEmpty);
    expect(podiumOrder(1), [0]);
    expect(podiumOrder(2), [1, 0]);
    expect(podiumOrder(5), [1, 0, 2]);
  });

  testWidgets('the podium shows at most three places and opens a cabin', (
    tester,
  ) async {
    var opened = '';
    final places = [
      for (final name in ['小安', '小明', '小華', '小美'])
        PodiumPlace(
          name: name,
          value: '1 小時',
          color: Colors.teal,
          onTap: () => opened = name,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlazaPodium(places: places)),
      ),
    );
    expect(find.text('小安'), findsOneWidget);
    expect(find.text('小華'), findsOneWidget);
    expect(find.text('小美'), findsNothing);
    await tester.tap(find.text('小明'));
    expect(opened, '小明');
  });

  test(
    'social pages are walkable scenes and the board never lists last place',
    () {
      for (final page in [
        'social_page',
        'friends_page',
        'add_friend_page',
        'encouragement_page',
        'reminder_center_page',
        'leaderboard_page',
      ]) {
        final source = File('lib/screens/$page.dart').readAsStringSync();
        expect(source, contains('LivingSceneBanner('), reason: page);
        expect(source, isNot(contains('SocialPlazaStage(')), reason: page);
      }
      final board = File(
        'lib/screens/leaderboard_page.dart',
      ).readAsStringSync();
      expect(board, contains('.take(sorted.isEmpty ? 0 : sorted.length - 1)'));
      expect(board, contains('for (final item in topThree)'));
    },
  );
}
