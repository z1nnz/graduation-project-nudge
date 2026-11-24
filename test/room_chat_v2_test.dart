import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/screens/study_room_chat_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 11, 24, 9);

StudyMemberData _member(String id, String nick) => StudyMemberData(
  memberId: id,
  name: nick,
  roomNickname: nick,
  status: StudyMemberStatus.studying,
  sessionSeconds: 0,
  todayFocusSeconds: 0,
  avatarColor: Colors.purple,
);

Future<AppState> _open(
  WidgetTester tester, {
  List<StudyRoomMessage> messages = const [],
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final room = StudyRoomData(
    id: 'room-1',
    name: '期末衝刺房',
    description: '',
    accentColor: const Color(0xFF7C6AE6),
    members: [_member('local_user', '我'), _member('amy', '小艾')],
    messages: messages,
  );
  SharedPreferences.setMockInitialValues({
    'study_rooms_setting': jsonEncode([room.toJson()]),
  });
  final appState = AppState();
  await tester.runAsync(appState.loadAllLocalData);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const MaterialApp(home: StudyRoomChatPage(roomId: 'room-1')),
    ),
  );
  await tester.pumpAndSettle();
  return appState;
}

StudyRoomMessage _latest(AppState s) =>
    s.studyRooms.firstWhere((r) => r.id == 'room-1').messages.first;

void main() {
  test('reply and mention survive JSON and are omitted when empty', () {
    final m = StudyRoomMessage(
      id: 'm2',
      senderId: 'amy',
      senderName: '小艾',
      text: '好',
      type: StudyRoomMessageType.text,
      createdAt: _t0,
      replyTo: 'm1',
      mentionUid: 'bob',
    );
    final back = StudyRoomMessage.fromJson(m.toJson());
    expect(back.replyTo, 'm1');
    expect(back.mentionUid, 'bob');
    final plain = StudyRoomMessage(
      id: 'm3',
      senderId: 'amy',
      senderName: '小艾',
      text: '嗨',
      type: StudyRoomMessageType.text,
      createdAt: _t0,
    ).toJson();
    expect(plain.containsKey('replyTo'), isFalse);
    expect(plain.containsKey('mentionUid'), isFalse);
  });

  testWidgets('long-press a message to reply; the reply quotes it', (
    tester,
  ) async {
    final appState = await _open(
      tester,
      messages: [
        StudyRoomMessage(
          id: 'm1',
          senderId: 'amy',
          senderName: '小艾',
          text: '今天讀到第三章',
          type: StudyRoomMessageType.text,
          createdAt: _t0,
        ),
      ],
    );
    await tester.longPress(find.text('今天讀到第三章'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-reply-bar')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '我也是！');
    await tester.tap(find.byKey(const Key('room-chat-send')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(_latest(appState).replyTo, 'm1');
    expect(find.byKey(const Key('chat-reply-bar')), findsNothing);
    expect(find.byKey(const Key('chat-quote-m1')), findsOneWidget);
  });

  testWidgets('@ picks a roommate and the message shows the mention', (
    tester,
  ) async {
    final appState = await _open(tester);
    await tester.tap(find.byKey(const Key('chat-mention')));
    await tester.pumpAndSettle();
    expect(find.text('@我'), findsNothing); // cannot mention yourself
    await tester.tap(find.text('@小艾'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-mention-chip')), findsOneWidget);

    await tester.enterText(find.byType(TextField), '一起衝');
    await tester.tap(find.byKey(const Key('room-chat-send')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(_latest(appState).mentionUid, 'amy');
    expect(find.text('@小艾'), findsOneWidget);
  });

  testWidgets('messages that mention me are highlighted', (tester) async {
    await _open(
      tester,
      messages: [
        StudyRoomMessage(
          id: 'm1',
          senderId: 'amy',
          senderName: '小艾',
          text: '你今天讀多久？',
          type: StudyRoomMessageType.text,
          createdAt: _t0,
          mentionUid: 'local_user',
        ),
      ],
    );
    expect(find.text('@你'), findsOneWidget);
    expect(find.byKey(const Key('chat-bubble-m1-mentioned')), findsOneWidget);
  });
}
