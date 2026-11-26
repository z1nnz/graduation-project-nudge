import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

class GameSealDialog extends StatelessWidget {
  const GameSealDialog({super.key});
  static Future<bool> firstStep(
    BuildContext context, {
    ValueChanged<BuildContext>? onPresented,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          onPresented?.call(dialogContext);
          return const GameSealDialog();
        },
      ) ??
      false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: GamePalette.of(context).backgroundTop,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: GamePalette.of(context).wood, width: 3),
    ),
    title: const Text(
      '第一道封印・閱讀刪除說明',
      style: TextStyle(fontFamily: 'Cubic11', fontSize: 20),
    ),
    content: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SealPreview(),
        SizedBox(height: 12),
        Text(
          '這一步尚未送出申請。接著仍需在第二道確認送出正式申請；送出後有 7 天冷靜期，可以取消。',
          style: TextStyle(fontSize: 14),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('返回，保留帳號'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('閱讀完成，前往第二步'),
      ),
    ],
  );
}

class _SealPreview extends StatefulWidget {
  const _SealPreview();
  @override
  State<_SealPreview> createState() => _SealPreviewState();
}

class _SealPreviewState extends State<_SealPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _time.stop();
      _time.value = 0;
    } else if (!_active || !TickerMode.of(context)) {
      _time.stop();
    } else if (!_time.isAnimating && _time.value < 1) {
      _time.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '兩道確認封印，尚未送出',
    child: SizedBox(
      height: 72,
      width: 144,
      child: AnimatedBuilder(
        animation: _time,
        builder: (context, _) => CustomPaint(
          painter: _SealPainter(frame: (_time.value * 9).floor()),
        ),
      ),
    ),
  );
}

class _SealPainter extends CustomPainter {
  const _SealPainter({required this.frame});
  final int frame;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = GamePalette.woodDark;
    for (var i = 0; i < 2; i++) {
      final x = s.width * (.25 + .5 * i),
          y = 22 + (i == 0 ? 9 - frame : 0).toDouble();
      c.drawRect(Rect.fromLTWH(x - 22, y - 2, 44, 44), p);
      p.color = i == 0 ? GamePalette.red : GamePalette.woodDeep;
      c.drawRect(Rect.fromLTWH(x - 18, y + 2, 36, 36), p);
      p.color = GamePalette.gold;
      if (i == 0) {
        c.drawRect(Rect.fromLTWH(x - 8, y + 15, 16, 5), p);
      } else {
        c.drawRect(Rect.fromLTWH(x - 2, y + 11, 4, 18), p);
      }
      p.color = GamePalette.woodDark;
    }
  }

  @override
  bool shouldRepaint(covariant _SealPainter old) => old.frame != frame;
}

class GameDeletionReasonDialog extends StatefulWidget {
  const GameDeletionReasonDialog({super.key});
  @override
  State<GameDeletionReasonDialog> createState() =>
      _GameDeletionReasonDialogState();
}

class _GameDeletionReasonDialogState extends State<GameDeletionReasonDialog> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: GamePalette.of(context).backgroundTop,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: GamePalette.of(context).wood, width: 3),
    ),
    title: const Text(
      '提出帳號刪除申請？',
      style: TextStyle(fontFamily: 'Cubic11', fontSize: 20),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第二道封印・正式確認',
          style: TextStyle(fontFamily: 'Cubic11', fontSize: 16),
        ),
        const SizedBox(height: 12),
        const Text(
          '送出後會進入 7 天冷靜期，再由有權限的承辦者核對關係、Ledger 保留義務與刪除證明。冷靜期內可以取消；正式執行開始後帳號會停用，若作業失敗將由承辦者依案件編號安全重試。',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reason,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: '原因（選填）',
            hintText: '例如：不再使用 Nudge',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('返回'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: GamePalette.woodDark,
          foregroundColor: GamePalette.inkLight,
        ),
        onPressed: () => Navigator.pop(context, _reason.text.trim()),
        child: const Text('送出正式申請'),
      ),
    ],
  );
}
