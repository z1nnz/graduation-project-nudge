import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/study_room_detail_page.dart';

void main() {
  testWidgets('the study hall objects expose and open seats and settings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var seats = 0;
    var settings = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyRoomNoticeBoard(
            seats: const SizedBox(key: ValueKey('seating-scene'), height: 110),
            onSeats: () => seats++,
            onSettings: () => settings++,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('seating-scene')), findsOneWidget);
    expect(find.bySemanticsLabel('座位上的房間成員'), findsOneWidget);
    expect(find.bySemanticsLabel('牆上的房務告示'), findsOneWidget);
    await tester.tap(find.text('查看座位'));
    await tester.tap(find.text('房間設定'));
    expect(seats, 1);
    expect(settings, 1);
    semantics.dispose();
  });
}
