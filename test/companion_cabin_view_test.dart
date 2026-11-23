import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/models/cabin_layout.dart';
import 'package:nudge/models/cabin_presentation.dart';
import 'package:nudge/widgets/companion_cabin_view.dart';

CabinPresentation _presentation({int books = 2, Map<String, int>? decor}) =>
    CabinPresentation(
      bookStage: books,
      plantStage: 1,
      badgeCount: 2,
      showGlobe: false,
      globeGlowing: false,
      decor: decor ?? const {'rug': 1, 'curtain': 0, 'lamp': 0},
      bubbleText: '今天先讀 25 分鐘，好嗎？',
      questCount: 3,
    );

Future<void> _pump(
  WidgetTester tester, {
  CabinPresentation? presentation,
  VoidCallback? onOpenQuests,
  String? confirmed,
  bool disableAnimations = false,
}) async {
  final layout = await CabinLayout.load(rootBundle);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 900),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: CompanionCabinView(
              layout: layout,
              presentation: presentation ?? _presentation(),
              profile: AvatarProfile.initial(),
              level: 7,
              levelProgress: 0.6,
              coins: 128,
              onOpenQuests: onOpenQuests ?? () {},
              onOpenDecor: () {},
              onOpenFamily: () {},
              onOpenGroup: () {},
              confirmedActivityLabel: confirmed,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Iterable<String> _assetNames(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .whereType<AssetImage>()
    .map((asset) => asset.assetName);

void main() {
  testWidgets('cabin shows the next action and opens quests', (tester) async {
    var opened = 0;
    await tester.runAsync(() => _pump(tester, onOpenQuests: () => opened++));
    expect(find.text('今天先讀 25 分鐘，好嗎？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cabin-quest-board')));
    expect(opened, 1);
  });

  testWidgets('cabin layers follow the presentation', (tester) async {
    await tester.runAsync(() => _pump(tester));
    final names = _assetNames(tester);
    expect(names, contains('assets/home/books_2.png'));
    expect(names, contains('assets/home/rug_1.png'));
    expect(names, contains('assets/home/curtain_0.png'));
    expect(names, isNot(contains('assets/home/globe.png')));
  });

  testWidgets('reduced motion keeps the character still', (tester) async {
    await tester.runAsync(() => _pump(tester, disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('celebration plays only for a newly confirmed activity', (
    tester,
  ) async {
    await tester.runAsync(() => _pump(tester, confirmed: 'A'));
    expect(find.byKey(const Key('cabin-celebration')), findsNothing);
    await tester.runAsync(() => _pump(tester, confirmed: 'B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('cabin-celebration')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => _pump(tester, confirmed: 'B'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('cabin-celebration')), findsNothing);
  });
}
