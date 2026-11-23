import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RoomChatReadState {
  static String storageKey(String userId, String roomId) =>
      'room_chat_seen_v1_${jsonEncode([userId, roomId])}';

  static Future<DateTime?> load(String userId, String roomId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey(userId, roomId));
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  static Future<void> save(
    String userId,
    String roomId,
    DateTime latestMessageAt,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey(userId, roomId),
      latestMessageAt.toUtc().toIso8601String(),
    );
  }

  static int unreadCount(Iterable<DateTime> messageTimes, DateTime? seenAt) =>
      messageTimes
          .where((time) => seenAt == null || time.isAfter(seenAt))
          .length;
}
