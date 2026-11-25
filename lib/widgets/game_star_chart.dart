import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/badge_record.dart';
import '../theme/game_ui.dart';

class GameStarChart extends StatefulWidget {
  const GameStarChart({
    super.key,
    required this.records,
    required this.confirmed,
    required this.onSelect,
  });
  final List<BadgeRecord> records;
  final bool confirmed;
  final ValueChanged<BadgeRecord> onSelect;
  @override
  State<GameStarChart> createState() => _GameStarChartState();
}

class _GameStarChartState extends State<GameStarChart>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  bool _foreground = true;
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
    if (_foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_time.isAnimating) {
        _time.repeat();
      }
    } else {
      _time.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => AnimatedBuilder(
      animation: _time,
      builder: (context, _) {
        final reduced = MediaQuery.disableAnimationsOf(context),
            frame = reduced ? 0 : (_time.value * 200).floor(),
            p = GamePalette.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StarLines(
                    records: widget.records,
                    confirmed: widget.confirmed,
                    frame: frame,
                    palette: p,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < widget.records.length; i++)
              Positioned(
                left: (i % 4 + .5) * size.maxWidth / 4 - 24,
                top: 96 + (i ~/ 4 + .5) * 56 - 24,
                width: 48,
                height: 48,
                child: Semantics(
                  button: true,
                  enabled: widget.confirmed,
                  label:
                      '${widget.records[i].badgeName}，${!widget.confirmed
                          ? '雲端確認中'
                          : widget.records[i].isUnlocked
                          ? '已點亮'
                          : '尚未解鎖'}',
                  excludeSemantics: true,
                  onTap: widget.confirmed
                      ? () => widget.onSelect(widget.records[i])
                      : null,
                  child: Tooltip(
                    message: widget.records[i].badgeName,
                    decoration: BoxDecoration(
                      color: GamePalette.woodDark,
                      border: Border.all(color: GamePalette.goldDeep, width: 2),
                    ),
                    textStyle: const TextStyle(
                      color: GamePalette.inkLight,
                      fontFamily: 'Cubic11',
                      fontSize: 14,
                    ),
                    child: IconButton(
                      onPressed: widget.confirmed
                          ? () => widget.onSelect(widget.records[i])
                          : null,
                      icon: Icon(
                        widget.confirmed && widget.records[i].isUnlocked
                            ? Icons.star
                            : Icons.star_border,
                        size: 36,
                        color: widget.confirmed && widget.records[i].isUnlocked
                            ? GamePalette.gold.withValues(
                                alpha: reduced ? 1 : .8 + (frame + i) % 3 * .1,
                              )
                            : GamePalette.inkLight,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              bottom: size.maxHeight * .24,
              width: 168,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: reduced ? 0 : math.sin(frame / 50) * .025,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/scenes/observatory/telescope.webp',
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _StarLines extends CustomPainter {
  const _StarLines({
    required this.records,
    required this.confirmed,
    required this.frame,
    required this.palette,
  });
  final List<BadgeRecord> records;
  final bool confirmed;
  final int frame;
  final GamePalette palette;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = GamePalette.gold.withValues(alpha: .45)
      ..strokeWidth = 2;
    Offset? previous;
    for (var i = 0; i < records.length; i++) {
      if (!confirmed || !records[i].isUnlocked) {
        continue;
      }
      final point = Offset((i % 4 + .5) * s.width / 4, 96 + (i ~/ 4 + .5) * 56);
      if (previous != null) {
        c.drawLine(previous, point, paint);
      }
      previous = point;
    }
    if (frame > 0 && frame % 200 < 10) {
      final t = (frame % 200) / 10,
          x = s.width * (.1 + .7 * t),
          y = 74 + 36 * t;
      paint
        ..color = GamePalette.inkLight
        ..strokeWidth = 2;
      c.drawLine(Offset(x, y), Offset(x - 24, y - 12), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarLines old) =>
      old.frame != frame ||
      old.records != records ||
      old.confirmed != confirmed ||
      old.palette != palette;
}
