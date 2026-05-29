import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text': '你好！我是你的 AI 自律導師。我能為你診斷自律狀況、提供微調行動建議（Nudge）或給予自律陪伴與溫暖鼓勵。🌸\n\n你今天想聊聊什麼呢？',
      'timestamp': DateTime.now(),
    }
  ];

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = false;

  final List<String> _suggestions = [
    '📊 診斷我今天的自律數據',
    '💡 給我具體行動建議',
    '✨ 想要一些溫暖鼓勵',
    '📅 幫我規劃明天的學習任務',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': trimmedText,
        'timestamp': DateTime.now(),
      });
      _isGenerating = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final appState = Provider.of<AppState>(context, listen: false);
    final response = await appState.chatWithAICoach(trimmedText, _messages);

    if (mounted) {
      setState(() {
        _messages.add({
          'isUser': false,
          'text': response,
          'timestamp': DateTime.now(),
        });
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.12),
              radius: 18,
              child: Icon(Icons.psychology_alt_outlined, color: accentColor, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI 自律導師',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── 聊天記錄 ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                final text = msg['text'] as String;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? accentColor
                          : (isDark ? const Color(0xFF1E2330) : const Color(0xFFECEBFA)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isUser ? Colors.white : primaryText,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── 輸入區域與推薦 ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161922) : Colors.white,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 推薦列表
                if (!_isGenerating && _messages.length == 1) ...[
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _sendMessage(suggestion),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                ),
                                borderRadius: BorderRadius.circular(20),
                                color: accentColor.withValues(alpha: 0.05),
                              ),
                              child: Center(
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 正在產生指示器
                if (_isGenerating) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI 自律導師正在思考中...',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 輸入框
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: primaryText),
                        decoration: InputDecoration(
                          hintText: '向 AI 導師詢問任何關於自律的事...',
                          hintStyle: TextStyle(color: secondaryText),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF222736) : const Color(0xFFF3F4F6),
                        ),
                        onSubmitted: (val) => _sendMessage(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isGenerating
                          ? null
                          : () => _sendMessage(_messageController.text),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
