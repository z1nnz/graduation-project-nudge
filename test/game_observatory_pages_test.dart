import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/badge_record.dart';
import 'package:nudge/screens/badges_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/theme/game_ui.dart';
import 'package:provider/provider.dart';

class _SkyState extends AppState {
  bool confirmed = true;
  @override
  bool get areBadgeRecordsConfirmed => confirmed;
  @override
  List<BadgeRecord> get badgeRecords =>
      throw StateError('The scene must use the read-only projection');
  @override
  List<BadgeRecord> get confirmedBadgeRecords => List.generate(
    16,
    (i) => BadgeRecord(
      id: 'b$i',
      userId: 'test',
      badgeKey: i == 0 ? 'focus_beginner' : 'test_$i',
      badgeName: i == 0 ? '專注新星' : '成就 $i',
      isUnlocked: confirmed && i == 0,
      unlockedAt: confirmed && i == 0 ? DateTime(2026, 11, 23) : null,
      progress: 25,
      target: 25,
      updatedAt: DateTime(2026, 11, 24),
    ),
  );
  void pending() {
    confirmed = false;
    notifyListeners();
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump(const Duration(milliseconds: 350));
  final output = Platform.environment['NUDGE_QA_SCREENSHOT_DIR'];
  if (output == null) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cubic11',
    )..addFont(rootBundle.load('assets/fonts/Cubic11.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Cloud-confirmed star chart, original detail and pending state at 360px / 1.15 / $dark',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final state = _SkyState(), boundary = GlobalKey();
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                  fontFamily: 'Cubic11',
                  appBarTheme: GameTheme.appBar(),
                  textButtonTheme: GameTheme.secondaryButton(dark: dark),
                  elevatedButtonTheme: GameTheme.primaryButton(),
                  chipTheme: GameTheme.chips(dark: dark),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(1.15),
                  ),
                  child: child!,
                ),
                home: const BadgesPage(),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump();
        expect(find.bySemanticsLabel('專注新星，已點亮'), findsOneWidget);
        expect(find.bySemanticsLabel('成就 1，尚未解鎖'), findsOneWidget);
        await capture(tester, boundary, 'r3-app-badges-$dark-scene');
        await tester.tap(find.byTooltip('專注新星'));
        await tester.pump();
        expect(find.textContaining('2026'), findsWidgets);
        expect(tester.takeException(), isNull);
        await capture(tester, boundary, 'r3-app-badges-$dark-detail');
        await tester.tap(find.text('關閉'));
        await tester.pump();
        await tester.tap(find.text('翻開成就紀錄簿'));
        await tester.pump();
        expect(find.text('闔上，回到場景'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, boundary, 'r3-app-badges-$dark-book');
        final unlockedFilter = find.widgetWithText(ChoiceChip, '已解鎖');
        await tester.ensureVisible(unlockedFilter);
        await tester.tap(unlockedFilter);
        await tester.pump();
        expect(find.text('1 個'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('闔上，回到場景'));
        await tester.pump();
        state.pending();
        await tester.pump();
        expect(find.bySemanticsLabel('專注新星，雲端確認中'), findsOneWidget);
        expect(find.bySemanticsLabel('專注新星，已點亮'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        state.dispose();
      },
    );
  }
}
