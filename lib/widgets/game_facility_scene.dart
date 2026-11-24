import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../theme/game_ui.dart';
import 'npc_dialog.dart';
import 'sprite_animation.dart';

/// A facility opens on its room; the existing feature stays behind its object.
class GameFacilityScene extends StatefulWidget {
  const GameFacilityScene({
    super.key,
    required this.child,
    required this.title,
    required this.background,
    this.objectLabel = '翻開紀錄簿',
    this.objectIcon = Icons.auto_stories,
    this.guide = 'inky',
    this.guideLine = '每一筆真實的紀錄，都有自己的位置。點開桌上的物件看看吧。',
  });
  final Widget child;
  final String title, background, objectLabel, guide, guideLine;
  final IconData objectIcon;
  @override
  State<GameFacilityScene> createState() => _GameFacilitySceneState();
}

class _GameFacilitySceneState extends State<GameFacilityScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  final _objectFocus = FocusNode(), _npcFocus = FocusNode();
  bool _open = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    final play =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        !_open;
    if (play) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncAnimation();
  }

  void _setOpen(bool value) {
    setState(() => _open = value);
    _syncAnimation();
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _objectFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambient.dispose();
    _objectFocus.dispose();
    _npcFocus.dispose();
    super.dispose();
  }

  Future<void> _talk() async {
    final character = GameCharacters.byId(widget.guide);
    await NpcDialog.show(
      context,
      speaker: character,
      lines: [widget.guideLine],
    );
    if (mounted) _npcFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context),
        reduced = MediaQuery.disableAnimationsOf(context);
    return GameBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _open,
            child: LayoutBuilder(
              builder: (context, size) => Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    child: Image.asset(
                      widget.background,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: p.backgroundBottom),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambient,
                      builder: (_, _) => CustomPaint(
                        painter: _RoomLifePainter(
                          frame: reduced ? 0 : (_ambient.value * 120).floor(),
                          palette: p,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: GamePanel(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cubic11',
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: math.max(8, size.maxWidth * .08),
                    top: size.maxHeight * .45,
                    child: Semantics(
                      label: '與${(GameCharacters.byId(widget.guide)).name}交談',
                      button: true,
                      excludeSemantics: true,
                      onTap: _talk,
                      child: Tooltip(
                        message: '點我聽聽這裡的故事',
                        excludeFromSemantics: true,
                        child: InkWell(
                          focusNode: _npcFocus,
                          onTap: _talk,
                          child: SizedBox(
                            width: 128,
                            height: 176,
                            child: Column(
                              children: [
                                TickerMode(
                                  enabled: _foreground && !_open,
                                  child: CharacterSprite(
                                    character: GameCharacters.byId(
                                      widget.guide,
                                    ),
                                    size: 128,
                                  ),
                                ),
                                Text(
                                  (GameCharacters.byId(widget.guide)).name,
                                  style: TextStyle(
                                    fontFamily: 'Cubic11',
                                    fontSize: 14,
                                    color: GamePalette.gold,
                                    backgroundColor: GamePalette.woodDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: size.maxWidth * .30,
                    right: 12,
                    bottom: math.max(24, size.maxHeight * .12),
                    child: Semantics(
                      label: widget.objectLabel,
                      button: true,
                      child: Tooltip(
                        message: widget.objectLabel,
                        child: TextButton(
                          focusNode: _objectFocus,
                          onPressed: () => _setOpen(true),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(88, 64),
                            foregroundColor: GamePalette.gold,
                            backgroundColor: GamePalette.woodDeep,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: BorderSide(color: p.wood, width: 3),
                            padding: const EdgeInsets.all(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.objectIcon, size: 36),
                              const SizedBox(height: 4),
                              Text(
                                widget.objectLabel,
                                style: const TextStyle(
                                  fontFamily: 'Cubic11',
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Offstage(
            offstage: !_open,
            child: Column(
              children: [
                GamePanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'Cubic11',
                            fontSize: 18,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _setOpen(false),
                        child: const Text(
                          '闔上，回到場景',
                          style: TextStyle(fontFamily: 'Cubic11', fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: p.ink, fontSize: 14),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomLifePainter extends CustomPainter {
  const _RoomLifePainter({required this.frame, required this.palette});
  final int frame;
  final GamePalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    final dust = Paint()..color = GamePalette.gold.withValues(alpha: .45);
    for (var i = 0; i < 12; i++) {
      final x = ((i * .173 + frame * .0009) % 1) * size.width,
          y = ((i * .137 - frame * .0011) % 1) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 2, 2),
        dust,
      );
    }
    final candle = Paint()
      ..color = GamePalette.gold.withValues(alpha: .45 + (frame % 3) * .12);
    for (final x in [.17, .83]) {
      canvas.drawRect(
        Rect.fromLTWH(
          (size.width * x).floorToDouble(),
          size.height * .18,
          4 + (frame % 2) * 2,
          8,
        ),
        candle,
      );
    }
    final bird = Paint()..color = palette.wood;
    final x = (size.width * .37 + frame % 60), y = size.height * .23;
    canvas.drawRect(Rect.fromLTWH(x, y, 6, 2), bird);
    canvas.drawRect(Rect.fromLTWH(x + 6, y + 2, 6, 2), bird);
  }

  @override
  bool shouldRepaint(covariant _RoomLifePainter old) =>
      old.frame != frame || old.palette != palette;
}

/// Parchment sections replace Material cards without changing their contents.
class GameArtifact extends StatelessWidget {
  const GameArtifact({
    super.key,
    required this.child,
    this.margin,
    this.color,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.shadowColor,
    this.surfaceTintColor,
    this.borderOnForeground = true,
    this.semanticContainer = true,
  });
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color, shadowColor, surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final bool borderOnForeground, semanticContainer;
  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: 6),
      child: GamePanel(
        padding: EdgeInsets.zero,
        child: Semantics(
          container: semanticContainer,
          child: ColoredBox(
            color: p.backgroundTop,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: p.ink, fontSize: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A sand-filled hourglass, with the exact underlying ratio retained in semantics.
class GameMetricGauge extends StatelessWidget {
  const GameMetricGauge({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.minHeight,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  });
  final double? value, minHeight;
  final Color? color, backgroundColor;
  final Animation<Color?>? valueColor;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel, semanticsValue;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel ?? '紀錄沙漏',
    value:
        semanticsValue ??
        (value == null || !value!.isFinite
            ? '確認中'
            : '${(value! * 100).round()}%'),
    child: SizedBox(
      width: double.infinity,
      height: math.max(minHeight ?? 44, 44),
      child: CustomPaint(
        painter: _SandPainter(value: value, palette: GamePalette.of(context)),
      ),
    ),
  );
}

class _SandPainter extends CustomPainter {
  const _SandPainter({required this.value, required this.palette});
  final double? value;
  final GamePalette palette;
  @override
  void paint(Canvas c, Size s) {
    final x = s.width / 2,
        w = math.min(s.width * .32, 28.0),
        h = s.height - 6,
        p = Paint()
          ..color = palette.wood
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final path = Path()
      ..moveTo(x - w, 3)
      ..lineTo(x + w, 3)
      ..lineTo(x, h + 3)
      ..lineTo(x - w, h + 3)
      ..lineTo(x + w, 3)
      ..moveTo(x - w, h + 3)
      ..lineTo(x + w, h + 3)
      ..lineTo(x - w, 3);
    c.drawPath(path, p);
    if (value != null) {
      final fill = (value!.isFinite ? value!.clamp(0, 1) : 0).toDouble();
      p
        ..style = PaintingStyle.fill
        ..color = GamePalette.gold;
      c.drawRect(
        Rect.fromLTWH(
          x - w + 4,
          h + 1 - h * fill * .4,
          w * 2 - 8,
          h * fill * .4,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SandPainter old) =>
      old.value != value || old.palette != palette;
}

/// Decorations for documents opened inside a facility.
class GameRecordStyle {
  const GameRecordStyle._();
  static BoxDecoration hero([Color? accent]) => BoxDecoration(
    color: GamePalette.woodDark,
    border: Border.all(color: GamePalette.goldDeep, width: 3),
    borderRadius: BorderRadius.circular(8),
  );
  static BoxDecoration inset(BuildContext context, Color accent) =>
      BoxDecoration(
        color: GamePalette.of(context).backgroundTop,
        border: Border.all(
          color: GamePalette.of(context).panelBorder,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      );
}
