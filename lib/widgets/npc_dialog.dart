import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../theme/game_ui.dart';
import 'sprite_animation.dart';

/// A button shown under the last line, e.g. 「去委託所」.
class NpcDialogAction {
  const NpcDialogAction(this.label, this.onSelected);

  final String label;
  final VoidCallback onSelected;
}

/// Pixel speech box: portrait, name plate, typewriter text.
///
/// ```dart
/// await NpcDialog.show(context,
///   speaker: GameCharacters.chestnut,
///   lines: ['歡迎光臨！', '貨架上的東西都可以拿起來看看。'],
/// );
/// ```
///
/// Tap: finish the line being typed, then the next line, then close.
/// With `MediaQuery.disableAnimations` each line appears at once.
class NpcDialog extends StatefulWidget {
  const NpcDialog({
    super.key,
    required this.speaker,
    required this.lines,
    this.actions = const [],
    this.onClose,
    this.charsPerSecond = 40,
  }) : assert(lines.length > 0);

  final GameCharacter speaker;
  final List<String> lines;
  final List<NpcDialogAction> actions;
  final VoidCallback? onClose;
  final double charsPerSecond;

  /// Shows the box at the bottom of the screen until it is closed.
  static Future<void> show(
    BuildContext context, {
    required GameCharacter speaker,
    required List<String> lines,
    List<NpcDialogAction> actions = const [],
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉對話',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: NpcDialog(
              speaker: speaker,
              lines: lines,
              onClose: () => Navigator.of(ctx).pop(),
              actions: [
                for (final a in actions)
                  NpcDialogAction(a.label, () {
                    Navigator.of(ctx).pop();
                    a.onSelected();
                  }),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(anim),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  @override
  State<NpcDialog> createState() => NpcDialogState();
}

class NpcDialogState extends State<NpcDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _typer = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  int _line = 0;
  bool _still = false;

  int get line => _line;
  List<String> get _chars => widget.lines[_line].characters.toList();

  /// Characters shown of the current line.
  int get shown => _still
      ? _chars.length
      : (_typer.value * _chars.length).floor().clamp(0, _chars.length);
  bool get typing => shown < _chars.length;
  bool get _last => _line == widget.lines.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _typer.value = 1;
    } else if (_typer.value == 0 && !_typer.isAnimating) {
      _type();
    }
  }

  void _type() {
    _typer.duration = Duration(
      milliseconds: (_chars.length * 1000 / widget.charsPerSecond)
          .round()
          .clamp(1, 1 << 30),
    );
    _typer.forward(from: 0);
  }

  /// Finish the line, else go on, else close.
  void next() {
    if (typing) {
      _typer.value = 1;
    } else if (!_last) {
      setState(() => _line++);
      if (_still) {
        _typer.value = 1;
      } else {
        _type();
      }
    } else if (widget.actions.isEmpty) {
      widget.onClose?.call();
    }
  }

  @override
  void dispose() {
    _typer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final text = _chars.take(shown).join();
    final done = !typing;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, minHeight: 120),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          container: true,
          liveRegion: true,
          button: true,
          label: '${widget.speaker.name}：${widget.lines[_line]}',
          hint: _last ? null : '點一下繼續',
          onTap: next,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: next,
            child: Container(
              key: const ValueKey('npc-dialog-box'),
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 12),
              decoration: BoxDecoration(
                color: p.panel,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: p.panelBorder, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: p.wood.withValues(alpha: 0.55),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: p.wood, width: 3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRect(
                      child: CharacterSprite(
                        character: widget.speaker,
                        animation: done
                            ? CharacterAnimation.idle
                            : CharacterAnimation.talk,
                        size: 78,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.wood,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.speaker.name,
                              style: const TextStyle(
                                fontFamily: 'Cubic11',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              // Reserve the full line so the box does not grow while typing.
                              Opacity(
                                opacity: 0,
                                child: Text(
                                  widget.lines[_line],
                                  style: _body(p),
                                ),
                              ),
                              Text(text, style: _body(p)),
                            ],
                          ),
                          if (done && !_last)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '▼',
                                style: TextStyle(
                                  color: GamePalette.goldDeep,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Semantics(
                      button: true,
                      label: '關閉對話',
                      child: InkResponse(
                        onTap: widget.onClose,
                        child: Icon(Icons.close, color: p.inkMuted, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).withActions(done && _last ? widget.actions : const []);
  }

  TextStyle _body(GamePalette p) =>
      TextStyle(fontSize: 16, height: 1.5, color: p.ink);
}

extension on Widget {
  /// Puts the action buttons under the box once the last line is shown.
  Widget withActions(List<NpcDialogAction> actions) {
    if (actions.isEmpty) return this;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        this,
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            for (final a in actions)
              GameButton(label: a.label, onPressed: a.onSelected),
          ],
        ),
      ],
    );
  }
}
