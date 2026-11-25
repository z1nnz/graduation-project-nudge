import '../theme/game_ui.dart';
import '../widgets/game_facility_scene.dart';
import '../widgets/game_scene_life.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

class FutureLetterPage extends StatefulWidget {
  const FutureLetterPage({super.key});

  @override
  State<FutureLetterPage> createState() => _FutureLetterPageState();
}

class _FutureLetterPageState extends State<FutureLetterPage> {
  String _selectedState = '穩定但有點累';
  final _actionController = TextEditingController(text: '完成 25 分鐘期中報告專注');
  final _noteController = TextEditingController(
    text: '不要把今天想成要全部完成，只要先把第一段做完。',
  );

  final _actionFocus = FocusNode();
  final _noteFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _actionFocus.addListener(_writingChanged);
    _noteFocus.addListener(_writingChanged);
  }

  void _writingChanged() {
    if (mounted) setState(() {});
  }

  String? _generatedLetterText;
  bool _isGenerating = false;
  bool _savingLetter = false;

  @override
  void dispose() {
    _actionFocus.dispose();
    _noteFocus.dispose();
    _actionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _generateLetter() {
    setState(() {
      _isGenerating = true;
    });

    // Simulate AI / template calculation
    Future.delayed(const Duration(milliseconds: 600), () {
      final state = _selectedState;
      final action = _actionController.text.trim();
      final note = _noteController.text.trim();

      if (mounted) {
        setState(() {
          _generatedLetterText =
              '我知道你現在是「$state」。但你不用今天就解決全部事情。\n\n先做「$action」，讓自己重新回到軌道。\n\n你留給自己的提醒：$note\n\n謝謝你今天沒有放棄。先完成這一小步，剩下的事情就會比較不巨大。';
          _isGenerating = false;
        });
      }
    });
  }

  Future<void> _saveLetter(AppState appState) async {
    if (_savingLetter) return;
    if (appState.currentUser == null || appState.isGuestMode) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先登入帳號後再保存。')));
      return;
    }
    setState(() => _savingLetter = true);
    try {
      await appState.saveFutureLetter(
        _selectedState,
        _actionController.text.trim(),
        _noteController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存請求已送出，請重新開啟後核對雲端紀錄。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('這次沒有完成保存，寫信草稿已保留。')));
      }
    } finally {
      if (mounted) {
        setState(() => _savingLetter = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    const accentColor = GamePalette.goldDeep;
    final letterData = appState.futureLetter;

    return Scaffold(
      appBar: AppBar(title: const Text('未來的信')),
      body: GameFacilityScene(
        title: '時光寫信桌',
        background: 'assets/scenes/journal/letter_garden.webp',
        guide: 'letty',
        guideLine: '寫下現在的心情和下一步。草稿與保存仍沿用原來的流程。',
        objectLabel: '坐到寫信桌',
        objectIcon: Icons.edit_note_outlined,
        foreground: Positioned.fill(
          child: IgnorePointer(
            child: GameSceneLife(
              kind: 'letter',
              writing:
                  _actionFocus.hasFocus || _noteFocus.hasFocus || _isGenerating,
              seal: letterData != null,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppUI.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: GameRecordStyle.hero(accentColor),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        color: GamePalette.inkLight,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        '未來的信',
                        style: TextStyle(
                          color: GamePalette.inkLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '感到迷茫或勞累時，看一封一週後的自己寄來的信。讓自律數據富含情感與情緒記憶。',
                    style: TextStyle(
                      color: GamePalette.inkLight,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.sectionGap),

            // ─── 寫信表單 ──────────────────────────────────────────────
            GameArtifact(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 64,
                      child: GameSceneLife(
                        kind: 'letter',
                        writing:
                            _actionFocus.hasFocus ||
                            _noteFocus.hasFocus ||
                            _isGenerating,
                        seal: letterData != null,
                      ),
                    ),
                    Text('選擇今天需要的陪伴', style: AppUI.sectionTitleOf(context)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedState,
                      decoration: const InputDecoration(labelText: '目前狀態'),
                      items: const [
                        DropdownMenuItem(
                          value: '穩定但有點累',
                          child: Text('穩定但有點累'),
                        ),
                        DropdownMenuItem(
                          value: '截止日壓力偏高',
                          child: Text('截止日壓力偏高'),
                        ),
                        DropdownMenuItem(
                          value: '專注啟動困難',
                          child: Text('專注啟動困難'),
                        ),
                        DropdownMenuItem(value: '睡眠不足', child: Text('睡眠不足')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedState = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _actionController,
                      focusNode: _actionFocus,
                      decoration: const InputDecoration(
                        labelText: '下一步任務',
                        hintText: '例如：完成 25 分鐘專注',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      focusNode: _noteFocus,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '想提醒自己的話',
                        hintText: '給自己最溫馨的備忘錄...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generateLetter,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        GamePalette.inkLight,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              _isGenerating ? '信紙整理中...' : '產生未來的信',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamePalette.woodDark,
                              foregroundColor: GamePalette.inkLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppUI.sectionGap),

            // ─── 產出的信件 ────────────────────────────────────────────
            if (_generatedLetterText != null) ...[
              _buildLetterPaper(
                context,
                title: '一週後的你想說',
                content: _generatedLetterText!,
                accentColor: accentColor,
                onSave: () => _saveLetter(appState),
              ),
              const SizedBox(height: AppUI.sectionGap),
            ],

            // ─── 雲端同步信件 ──────────────────────────────────────────
            if (letterData != null) ...[
              Text('雲端同步信件', style: AppUI.sectionTitleOf(context)),
              const SizedBox(height: AppUI.cardGap),
              _buildLetterPaper(
                context,
                title: '同步自 Web 平台的信',
                content:
                    '我知道你現在是「${letterData['state']}」。先做「${letterData['action']}」，你會感覺事情開始變小。\n\n你留給自己的提醒：${letterData['note']}\n\n這封信會存檔於每週/每月報告中，幫助你記錄如何度過卡關的日子。',
                accentColor: accentColor,
                isSaved: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLetterPaper(
    BuildContext context, {
    required String title,
    required String content,
    required Color accentColor,
    VoidCallback? onSave,
    bool isSaved = false,
  }) {
    final primaryText = GamePalette.of(context).ink;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppUI.isDark(context)
            ? const Color(0xFF252932)
            : const Color(0xFFFFFDF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.drafts_outlined, color: GamePalette.goldDeep),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: primaryText,
              height: 1.6,
              letterSpacing: 0.5,
            ),
          ),
          if (onSave != null && !isSaved) ...[
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(_savingLetter ? '送出中...' : '保存並同步到雲端'),
                style: TextButton.styleFrom(foregroundColor: primaryText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
