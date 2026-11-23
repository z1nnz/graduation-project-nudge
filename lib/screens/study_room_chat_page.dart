import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_room_models.dart';
import '../state/app_state.dart';

/// Per-device "last read" marker for a room's chat, scoped to the account.
class RoomChatReadState {
  static String _key(String roomId, String userId) =>
      'room_chat_read_${userId}_$roomId';

  static int unreadCount(
    List<StudyRoomMessage> messages, {
    required DateTime? lastRead,
    required String myId,
  }) {
    return messages
        .where((m) => m.senderId != myId)
        .where((m) => lastRead == null || m.createdAt.isAfter(lastRead))
        .length;
  }

  static Future<DateTime?> lastRead(String roomId, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(roomId, userId));
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markRead(
    String roomId,
    String userId,
    DateTime at,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(roomId, userId), at.toUtc().toIso8601String());
    } catch (_) {}
  }
}

const roomChatStickers = ['加油', '穩住', '太強了', '一起衝', '休息一下'];

/// The room chat, moved out of the room page so the room itself can be a
/// scene. Text and the fixed encouragement stickers only.
class StudyRoomChatPage extends StatefulWidget {
  const StudyRoomChatPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<StudyRoomChatPage> createState() => _StudyRoomChatPageState();
}

class _StudyRoomChatPageState extends State<StudyRoomChatPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  String _myId(AppState appState) => appState.currentUser?.id ?? 'local_user';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(
    AppState appState,
    String text, {
    StudyRoomMessageType type = StudyRoomMessageType.text,
  }) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    if (type == StudyRoomMessageType.text) _controller.clear();
    try {
      await appState.addStudyRoomMessage(
        roomId: widget.roomId,
        text: text,
        type: type,
      );
      await appState.addStudyRoomEvent(
        roomId: widget.roomId,
        text: type == StudyRoomMessageType.sticker
            ? '${appState.profileNickname} 送出鼓勵貼圖 $text'
            : '${appState.profileNickname} 傳送了一則訊息',
        type: type == StudyRoomMessageType.sticker
            ? StudyRoomEventType.sticker
            : StudyRoomEventType.message,
      );
    } catch (error) {
      if (!mounted) return;
      if (type == StudyRoomMessageType.text) _controller.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('訊息沒有送出：$error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final room = appState.studyRooms
        .where((r) => r.id == widget.roomId)
        .firstOrNull;
    final myId = _myId(appState);
    if (room != null && room.messages.isNotEmpty) {
      RoomChatReadState.markRead(room.id, myId, room.messages.first.createdAt);
    }
    final ordered = (room?.messages ?? const <StudyRoomMessage>[]).reversed
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(room?.name ?? '房間聊天')),
      body: Column(
        children: [
          Expanded(
            child: ordered.isEmpty
                ? const Center(child: Text('還沒有訊息，送出第一句鼓勵吧。'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: ordered.length,
                    itemBuilder: (context, i) {
                      final m = ordered[i];
                      final mine = m.senderId == myId;
                      final sticker = m.type == StudyRoomMessageType.sticker;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  m.senderName,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              Text(
                                m.text,
                                style: TextStyle(
                                  fontSize: sticker ? 18 : 14,
                                  fontWeight: sticker
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in roomChatStickers)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(s),
                              onPressed: _sending
                                  ? null
                                  : () => _send(
                                      appState,
                                      s,
                                      type: StudyRoomMessageType.sticker,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (v) => _send(appState, v),
                          decoration: const InputDecoration(
                            hintText: '傳一句鼓勵或進度',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const Key('room-chat-send'),
                        tooltip: '送出',
                        onPressed: _sending
                            ? null
                            : () => _send(appState, _controller.text),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
