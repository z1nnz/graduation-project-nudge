import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_hall_layout.dart';
import 'package:nudge/models/study_hall_seating.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/widgets/study_hall_scene.dart';

StudyMemberData _m(String id, StudyMemberStatus status) => StudyMemberData(
  memberId: id,
  name: id,
  roomNickname: '暱稱$id',
  status: status,
  sessionSeconds: 0,
  todayFocusSeconds: 1500,
  avatarColor: Colors.purple,
);

Future<List<StudyMemberData>> _pump(
  WidgetTester tester, {
  required List<StudyMemberData> members,
  StudyRoomType type = StudyRoomType.study,
  int lantern = 1,
  bool still = false,
}) async {
  final tapped = <StudyMemberData>[];
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 900),
          disableAnimations: still,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: StudyHallScene(
              roomType: type,
              seating: StudyHallSeating.assign(members, myId: 'me'),
              myId: 'me',
              lanternStage: lantern,
              onMemberTap: tapped.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return tapped;
}

void main() {
  test('every hall and lantern image exists and seats fit the frame', () {
    for (final hall in StudyHallLayout.halls.values) {
      expect(File(hall.image).existsSync(), isTrue, reason: hall.image);
      expect(hall.seats, hasLength(StudyHallSeating.capacity));
      for (final s in hall.seats) {
        expect(s.centerX, inInclusiveRange(0, 1));
        expect(s.bottom - s.height, greaterThanOrEqualTo(0));
        expect(s.bottom, lessThanOrEqualTo(1));
      }
    }
    for (final l in StudyHallLayout.lanterns) {
      expect(File(l).existsSync(), isTrue, reason: l);
    }
  });

  testWidgets('studying reads, resting sleeps, offline seats stay empty', (
    tester,
  ) async {
    await tester.runAsync(
      () => _pump(
        tester,
        members: [
          _m('me', StudyMemberStatus.studying),
          _m('b', StudyMemberStatus.resting),
          _m('c', StudyMemberStatus.offline),
        ],
      ),
    );
    expect(find.byKey(const Key('hall-member-me')), findsOneWidget);
    expect(find.byKey(const Key('hall-member-b')), findsOneWidget);
    expect(find.byKey(const Key('hall-member-c')), findsNothing);
    expect(find.byKey(const Key('pose-effect-read')), findsOneWidget);
    expect(find.byKey(const Key('pose-effect-sleep')), findsOneWidget);
    expect(find.text('你'), findsOneWidget);
    expect(find.text('現在有 2 人在房間裡'), findsOneWidget);
  });

  testWidgets('exercise rooms show exercising members', (tester) async {
    await tester.runAsync(
      () => _pump(
        tester,
        type: StudyRoomType.exercise,
        members: [_m('me', StudyMemberStatus.studying)],
      ),
    );
    expect(find.byKey(const Key('pose-effect-exercise')), findsOneWidget);
  });

  testWidgets('tapping a member reports them; overflow shows +N', (
    tester,
  ) async {
    late List<StudyMemberData> tapped;
    await tester.runAsync(() async {
      tapped = await _pump(
        tester,
        members: [
          for (var i = 0; i < 10; i++) _m('m$i', StudyMemberStatus.studying),
        ],
      );
    });
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('hall-member-m0')));
    expect(tapped.single.memberId, 'm0');
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the hall still', (tester) async {
    await tester.runAsync(
      () => _pump(
        tester,
        still: true,
        members: [_m('me', StudyMemberStatus.studying)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
