import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_room_models.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';

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

/// The room chat as a cosy wooden message board: replies, @mentions and the
/// fixed encouragement stickers.
class StudyRoomChatPage extends StatefulWidget {
  const StudyRoomChatPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<StudyRoomChatPage> createState() => _StudyRoomChatPageState();
}

class _StudyRoomChatPageState extends State<StudyRoomChatPage> {
  final _controller = TextEditingController();
  bool _sending = false;
  StudyRoomMessage? _replyTo;
  StudyMemberData? _mention;

  String _myId(AppState appState) => appState.currentUser?.id ?? 'local_user';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _nick(StudyMemberData m) =>
      m.roomNickname.isEmpty ? m.name : m.roomNickname;

  Future<void> _send(
    AppState appState,
    String text, {
    StudyRoomMessageType type = StudyRoomMessageType.text,
  }) async {
    if (text.trim().isEmpty || _sending) return;
    final isText = type == StudyRoomMessageType.text;
    final replyTo = _replyTo;
    final mention = _mention;
    setState(() {
      _sending = true;
      if (isText) {
        _replyTo = null;
        _mention = null;
      }
    });
    if (isText) _controller.clear();
    try {
      await appState.addStudyRoomMessage(
        roomId: widget.roomId,
        text: text,
        type: type,
        replyTo: isText ? replyTo?.id : null,
        mentionUid: isText ? mention?.memberId : null,
      );
      await appState.addStudyRoomEvent(
        roomId: widget.roomId,
        text: isText
            ? '${appState.profileNickname} 傳送了一則訊息'
            : '${appState.profileNickname} 送出鼓勵貼圖 $text',
        type: isText ? StudyRoomEventType.message : StudyRoomEventType.sticker,
      );
    } catch (error) {
      if (!mounted) return;
      if (isText) {
        _controller.text = text;
        setState(() {
          _replyTo = replyTo;
          _mention = mention;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('訊息沒有送出：$error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickMention(List<StudyMemberData> others) async {
    final picked = await showModalBottomSheet<StudyMemberData>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GamePanel(
            title: '要提及誰？',
            child: others.isEmpty
                ? const Text('房間裡還沒有其他夥伴。')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in others)
                        GameButton(
                          label: '@${_nick(m)}',
                          primary: false,
                          onPressed: () => Navigator.pop(context, m),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _mention = picked);
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
    final messages = room?.messages ?? const <StudyRoomMessage>[];
    final byId = {for (final m in messages) m.id: m};
    final ordered = messages.reversed.toList(growable: false);
    final approved = (room?.members ?? const <StudyMemberData>[])
        .where((m) => m.isApproved)
        .toList();
    final names = {for (final m in approved) m.memberId: _nick(m)};
    final others = approved.where((m) => m.memberId != myId).toList();
    final p = GamePalette.of(context);

    String? mentionName(StudyRoomMessage m) {
      final uid = m.mentionUid;
      if (uid == null) return null;
      if (uid == myId) return '你';
      return names[uid] ?? '已離開的成員';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A3826),
        foregroundColor: const Color(0xFFFFE6A3),
        surfaceTintColor: Colors.transparent,
        title: Text(
          room?.name ?? '房間聊天',
          style: const TextStyle(fontFamily: 'Cubic11', fontSize: 22),
        ),
      ),
      body: GameBackground(
        child: Column(
          children: [
            Expanded(
              child: ordered.isEmpty
                  ? Center(
                      child: Text(
                        '還沒有訊息，送出第一句鼓勵吧。',
                        style: TextStyle(color: p.inkMuted, fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: ordered.length,
                      itemBuilder: (context, i) {
                        final m = ordered[i];
                        return _Bubble(
                          message: m,
                          mine: m.senderId == myId,
                          mentionsMe: m.mentionUid == myId,
                          quoted: m.replyTo == null ? null : byId[m.replyTo],
                          mentionName: mentionName(m),
                          onReply: () => setState(() => _replyTo = m),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: p.panel,
                  border: Border(
                    top: BorderSide(color: p.panelBorder, width: 3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_replyTo case final reply?)
                      _ComposerNote(
                        key: const Key('chat-reply-bar'),
                        icon: Icons.reply_rounded,
                        text: '回覆 ${reply.senderName}：${reply.text}',
                        onClear: () => setState(() => _replyTo = null),
                      ),
                    if (_mention case final mention?)
                      _ComposerNote(
                        key: const Key('chat-mention-chip'),
                        icon: Icons.alternate_email_rounded,
                        text: '提及 @${_nick(mention)}',
                        onClear: () => setState(() => _mention = null),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in roomChatStickers)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(s),
                                backgroundColor: GamePalette.gold.withValues(
                                  alpha: 0.35,
                                ),
                                side: BorderSide(color: p.panelBorder),
                                labelStyle: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w900,
                                ),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          key: const Key('chat-mention'),
                          tooltip: '提及夥伴',
                          onPressed: () => _pickMention(others),
                          icon: Icon(
                            Icons.alternate_email_rounded,
                            color: p.wood,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLength: 500,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (v) => _send(appState, v),
                            decoration: InputDecoration(
                              hintText: '傳一句鼓勵或進度',
                              counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.panelBorder),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          key: const Key('room-chat-send'),
                          tooltip: '送出',
                          style: IconButton.styleFrom(
                            backgroundColor: GamePalette.gold,
                            foregroundColor: const Color(0xFF2A1600),
                          ),
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
      ),
    );
  }
}

class _ComposerNote extends StatelessWidget {
  const _ComposerNote({
    super.key,
    required this.icon,
    required this.text,
    required this.onClear,
  });

  final IconData icon;
  final String text;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: GamePalette.gold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.wood),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: '取消',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.mentionsMe,
    required this.quoted,
    required this.mentionName,
    required this.onReply,
  });

  final StudyRoomMessage message;
  final bool mine;
  final bool mentionsMe;
  final StudyRoomMessage? quoted;
  final String? mentionName;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final sticker = message.type == StudyRoomMessageType.sticker;
    final t = message.createdAt.toLocal();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final quote = quoted;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReply,
        child: Container(
          key: Key(
            mentionsMe
                ? 'chat-bubble-${message.id}-mentioned'
                : 'chat-bubble-${message.id}',
          ),
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 290),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFFFE6A3) : p.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mentionsMe ? GamePalette.goldDeep : p.panelBorder,
              width: mentionsMe ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: p.wood.withValues(alpha: 0.35),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: p.wood,
                  ),
                ),
              if (message.replyTo != null)
                Container(
                  key: Key('chat-quote-${message.replyTo}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: p.wood.withValues(alpha: 0.12),
                    border: Border(left: BorderSide(color: p.wood, width: 3)),
                  ),
                  child: Text(
                    quote == null
                        ? '原訊息已不在'
                        : '${quote.senderName}：${quote.text}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.inkMuted),
                  ),
                ),
              if (mentionName != null)
                Text(
                  '@$mentionName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: GamePalette.violet,
                  ),
                ),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: sticker ? 19 : 15,
                  height: 1.4,
                  color: p.ink,
                  fontWeight: sticker ? FontWeight.w900 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  time,
                  style: TextStyle(fontSize: 11, color: p.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
