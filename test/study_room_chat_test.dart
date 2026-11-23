import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/screens/study_room_chat_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudyRoomMessage _msg(
  String id,
  String sender,
  DateTime at, {
  String text = 'hi',
}) => StudyRoomMessage(
  id: id,
  senderId: sender,
  senderName: sender,
  text: text,
  type: StudyRoomMessageType.text,
  createdAt: at,
);

void main() {
  final t0 = DateTime.utc(2026, 11, 23, 10);

  test('unread counts only newer messages from other people', () {
    final messages = [
      _msg('3', 'amy', t0.add(const Duration(minutes: 3))),
      _msg('2', 'local_user', t0.add(const Duration(minutes: 2))),
      _msg('1', 'amy', t0.add(const Duration(minutes: 1))),
    ];
    expect(
      RoomChatReadState.unreadCount(
        messages,
        lastRead: null,
        myId: 'local_user',
      ),
      2,
    );
    expect(
      RoomChatReadState.unreadCount(
        messages,
        lastRead: t0.add(const Duration(minutes: 1)),
        myId: 'local_user',
      ),
      1,
    );
  });

  testWidgets('chat page shows history oldest first and sends text', (
    tester,
  ) async {
    final room = StudyRoomData(
      id: 'room-1',
      name: '期末衝刺房',
      description: '',
      accentColor: const Color(0xFF7C6AE6),
      members: const [],
      messages: [
        _msg('2', 'amy', t0.add(const Duration(minutes: 2)), text: '第二句'),
        _msg('1', 'amy', t0.add(const Duration(minutes: 1)), text: '第一句'),
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
        child: const MaterialApp(home: StudyRoomChatPage(roomId: 'room-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('期末衝刺房'), findsOneWidget);
    final first = tester.getTopLeft(find.text('第一句')).dy;
    final second = tester.getTopLeft(find.text('第二句')).dy;
    expect(first, lessThan(second));

    await tester.enterText(find.byType(TextField), '一起加油');
    await tester.tap(find.byKey(const Key('room-chat-send')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('一起加油'), findsOneWidget);
    expect(appState.studyRooms.single.messages.first.text, '一起加油');
  });

  testWidgets('sticker chips send a sticker message', (tester) async {
    final room = StudyRoomData(
      id: 'room-1',
      name: '期末衝刺房',
      description: '',
      accentColor: const Color(0xFF7C6AE6),
      members: const [],
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
    await tester.tap(find.text('一起衝'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final sent = appState.studyRooms.single.messages.first;
    expect(sent.type, StudyRoomMessageType.sticker);
    expect(sent.text, '一起衝');
  });
}
