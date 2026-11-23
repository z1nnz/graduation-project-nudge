import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_chat_read_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('read markers stay separate for each account and room', () async {
    final readAt = DateTime.utc(2026, 11, 23, 5);
    await RoomChatReadState.save('user-a', 'room-1', readAt);

    expect(await RoomChatReadState.load('user-a', 'room-1'), readAt);
    expect(await RoomChatReadState.load('user-b', 'room-1'), isNull);
    expect(await RoomChatReadState.load('user-a', 'room-2'), isNull);
    expect(
      RoomChatReadState.storageKey('user_a', 'room'),
      isNot(RoomChatReadState.storageKey('user', 'a_room')),
    );
  });

  test('only messages newer than the read marker count as unread', () {
    final readAt = DateTime.utc(2026, 11, 23, 5);
    final messages = [
      readAt.subtract(const Duration(seconds: 1)),
      readAt,
      readAt.add(const Duration(seconds: 1)),
    ];

    expect(RoomChatReadState.unreadCount(messages, readAt), 1);
    expect(RoomChatReadState.unreadCount(messages, null), 3);
  });
}
