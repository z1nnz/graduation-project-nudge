import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/screens/study_room_chat_page.dart';
import 'package:nudge/screens/study_room_live_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/widgets/study_hall_scene.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudyMemberData _m(String id, String nick, StudyMemberStatus status) =>
    StudyMemberData(
      memberId: id,
      name: nick,
      roomNickname: nick,
      status: status,
      sessionSeconds: 0,
      todayFocusSeconds: 1800,
      avatarColor: Colors.purple,
    );

Future<AppState> _open(WidgetTester tester, {bool voice = false}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final room = StudyRoomData(
    id: 'room-1',
    name: '期末衝刺房',
    description: '',
    accentColor: const Color(0xFF7C6AE6),
    voiceEnabled: voice,
    members: [
      _m('local_user', '我', StudyMemberStatus.studying),
      _m('amy', '小艾', StudyMemberStatus.resting),
    ],
    messages: [
      StudyRoomMessage(
        id: 'm1',
        senderId: 'amy',
        senderName: '小艾',
        text: '一起撐過期末！',
        type: StudyRoomMessageType.text,
        createdAt: DateTime.utc(2026, 11, 23, 9),
      ),
    ],
  );
  SharedPreferences.setMockInitialValues({
    'study_rooms_setting': jsonEncode([room.toJson()]),
  });
  final appState = AppState();
  await tester.runAsync(appState.loadAllLocalData);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const MaterialApp(home: StudyRoomLivePage(roomId: 'room-1')),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return appState;
}

void main() {
  setUp(rootBundle.clear);

  testWidgets('the room fills the screen: hall, name plate and control bar', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(StudyHallScene), findsOneWidget);
    expect(find.text('現在有 2 人在房間裡'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('room-title')),
        matching: find.text('期末衝刺房'),
      ),
      findsOneWidget,
    );
    for (final key in [
      'room-back',
      'room-mic',
      'room-voice',
      'room-main-action',
      'room-chat',
      'room-more',
      'room-boss',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('the chat button shows unread messages and opens the chat', (
    tester,
  ) async {
    await _open(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('room-chat')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('room-chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StudyRoomChatPage), findsOneWidget);
  });

  testWidgets('voice waits until the owner turns it on', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('room-voice')));
    await tester.pump();
    expect(find.text('房主開啟語音後，就能一起開麥克風讀書'), findsOneWidget);
  });

  testWidgets('voice needs a signed-in member even when the room allows it', (
    tester,
  ) async {
    await _open(tester, voice: true);
    await tester.tap(find.byKey(const Key('room-mic')));
    await tester.pump();
    expect(find.text('登入並加入這間房後，才能使用語音'), findsOneWidget);
    expect(find.byKey(const Key('room-voice-status')), findsNothing);
  });

  testWidgets('the main button starts my session and shows the clock', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byKey(const Key('room-timer')), findsNothing);
    await tester.tap(find.byKey(const Key('room-main-action')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('room-timer')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('room-main-action')),
        matching: find.text('暫停'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('more opens the room tools', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('room-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('room-tools-sheet')), findsOneWidget);
    expect(find.text('房間動態'), findsOneWidget);
  });

  testWidgets(
    'tapping a member shows who they are, without replies when they have no signal',
    (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const Key('hall-member-amy')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('room-member-sheet')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('room-member-sheet')),
          matching: find.text('小艾'),
        ),
        findsOneWidget,
      );
      expect(find.text('休息中'), findsOneWidget);
      expect(find.text('我陪你'), findsNothing);
    },
  );
}
