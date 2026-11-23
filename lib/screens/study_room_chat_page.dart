import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_room_models.dart';
import '../state/app_state.dart';

class StudyRoomChatPage extends StatefulWidget {
  final String roomId;

  const StudyRoomChatPage({super.key, required this.roomId});

  @override
  State<StudyRoomChatPage> createState() => _StudyRoomChatPageState();
}

class _StudyRoomChatPageState extends State<StudyRoomChatPage> {
  static const _ink = Color(0xFF1C1730);
  static const _gold = Color(0xFFF5C969);
  static const _cream = Color(0xFFFFF4DA);
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(
    AppState appState, {
    StudyRoomMessageType type = StudyRoomMessageType.text,
    String? sticker,
  }) async {
    if (_sending) return;
    final text = (sticker ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    if (sticker == null) _controller.clear();
    try {
      await appState.addStudyRoomMessage(
        roomId: widget.roomId,
        text: text,
        type: type,
      );
    } catch (error) {
      if (!mounted) return;
      if (sticker == null) _controller.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('訊息同步失敗：$error')));
      return;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    try {
      await appState.addStudyRoomEvent(
        roomId: widget.roomId,
        text: sticker == null
            ? '${appState.profileNickname} 傳送了一則訊息'
            : '${appState.profileNickname} 送出鼓勵貼圖 $sticker',
        type: sticker == null
            ? StudyRoomEventType.message
            : StudyRoomEventType.sticker,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('訊息已同步，但房間動態紀錄失敗：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final room = appState.getStudyRoomById(widget.roomId);
        final userId = appState.currentUser?.id ?? 'local_user';
        final canChat =
            room != null &&
            room.members.any(
              (member) => member.memberId == userId && member.isApproved,
            );
        return Scaffold(
          backgroundColor: _ink,
          appBar: AppBar(
            backgroundColor: _ink,
            foregroundColor: _cream,
            title: Text(room == null ? '房內聊天' : room.name),
            centerTitle: true,
          ),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF302449), Color(0xFF17152A)],
              ),
            ),
            child: !canChat
                ? const Center(
                    child: Text(
                      '加入房間並通過審核後才能查看聊天。',
                      style: TextStyle(color: _cream),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B3565),
                            border: Border.all(color: _gold, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: _gold),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '房內聊天',
                                      style: TextStyle(
                                        color: _cream,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      '${room.messages.length} 則房間訊息 · 彼此鼓勵，一起前進',
                                      style: const TextStyle(
                                        color: Color(0xFFE0CBA8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: room.messages.isEmpty
                            ? const Center(
                                child: Text(
                                  '還沒有訊息，送出第一句鼓勵吧。',
                                  style: TextStyle(color: _cream),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 20,
                                ),
                                itemCount: room.messages.length,
                                itemBuilder: (context, index) => _MessageBubble(
                                  message: room.messages[index],
                                  isMe: room.messages[index].senderId == userId,
                                ),
                              ),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF241C39),
                            border: Border(
                              top: BorderSide(color: Color(0xFF6B517B)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final sticker in const [
                                      '加油',
                                      '穩住',
                                      '太強了',
                                      '一起衝',
                                      '休息一下',
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ActionChip(
                                          label: Text(sticker),
                                          backgroundColor: const Color(
                                            0xFF4A365F,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF9476A8),
                                          ),
                                          labelStyle: const TextStyle(
                                            color: _cream,
                                          ),
                                          onPressed: _sending
                                              ? null
                                              : () => _send(
                                                  appState,
                                                  type: StudyRoomMessageType
                                                      .sticker,
                                                  sticker: sticker,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      style: const TextStyle(color: _cream),
                                      decoration: const InputDecoration(
                                        hintText: '傳一句鼓勵或進度',
                                        hintStyle: TextStyle(
                                          color: Color(0xFFC8B9D6),
                                        ),
                                        filled: true,
                                        fillColor: Color(0xFF3A2D51),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(12),
                                          ),
                                        ),
                                      ),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: _sending
                                          ? null
                                          : (_) => _send(appState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    tooltip: '傳送訊息',
                                    style: IconButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: _ink,
                                    ),
                                    onPressed: _sending
                                        ? null
                                        : () => _send(appState),
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
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final StudyRoomMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = isMe ? const Color(0xFF75529B) : const Color(0xFF393452);
    final isSticker = message.type == StudyRoomMessageType.sticker;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isMe ? const Color(0xFFE8BE69) : const Color(0xFF6A6582),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName,
              style: TextStyle(
                color: isMe ? const Color(0xFFFFD782) : const Color(0xFFCEC2E2),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(
                color: const Color(0xFFFFF4DA),
                fontSize: isSticker ? 17 : 14,
                height: 1.35,
                fontWeight: isSticker ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
