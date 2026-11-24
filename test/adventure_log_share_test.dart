import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/adventure_log.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/screens/adventure_log_page.dart';

void main() {
  testWidgets('the share button captures the journal page as a PNG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Uint8List? shared;
    const log = AdventureLog([
      AdventureDay('2026-11-17', 0, 0),
      AdventureDay('2026-11-18', 30, 1),
      AdventureDay('2026-11-19', 0, 0),
      AdventureDay('2026-11-20', 100, 4),
      AdventureDay('2026-11-21', 0, 0),
      AdventureDay('2026-11-22', 0, 0),
      AdventureDay('2026-11-23', 50, 2),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AdventureLogPage(
          log: log,
          profile: AvatarProfile.initial(),
          onOpenStatistics: () {},
          onShareImage: (png) async => shared = png,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.ensureVisible(find.byKey(const Key('log-share')));
    expect(find.text('分享這一頁'), findsOneWidget);
    // Image capture needs the real event loop, so call it directly here.
    final context = tester.element(find.byKey(const Key('log-share')));
    await tester.runAsync(() async {
      shared = await AdventureLogPage.capturePng(context);
    });

    expect(shared, isNotNull);
    // PNG signature.
    expect(shared!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    // The whole journal card at 3x, not just the button.
    final width = ByteData.sublistView(shared!, 16, 20).getUint32(0);
    expect(width, greaterThan(1000));
  });
}
