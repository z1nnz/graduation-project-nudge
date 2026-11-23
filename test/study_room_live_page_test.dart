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

Future<AppState> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final room = StudyRoomData(
    id: 'room-1',
    name: '期末衝刺房',
    description: '',
    accentColor: const Color(0xFF7C6AE6),
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

  testWidgets('the room opens on the study hall with a chat entry', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(StudyHallScene), findsOneWidget);
    expect(find.text('現在有 2 人在房間裡'), findsOneWidget);
    expect(
      find.text('房內聊天'),
      findsNothing,
      reason: 'chat moved to its own page',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('room-chat-entry')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('room-chat-entry')), findsOneWidget);
    expect(find.textContaining('一起撐過期末！'), findsOneWidget);
    expect(find.text('1'), findsWidgets, reason: 'unread badge');
  });

  testWidgets('the chat entry opens the chat page', (tester) async {
    await _open(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('room-chat-entry')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('room-chat-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StudyRoomChatPage), findsOneWidget);
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
