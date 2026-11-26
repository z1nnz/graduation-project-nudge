import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

/// Pixel props share one clock and pause with their room's lifecycle.
class GameSceneLife extends StatefulWidget {
  const GameSceneLife({
    super.key,
    required this.kind,
    this.ready = false,
    this.writing = false,
    this.seal = false,
  });
  final String kind;
  final bool ready, writing, seal;
  @override
  State<GameSceneLife> createState() => _GameSceneLifeState();
}

class _GameSceneLifeState extends State<GameSceneLife>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  bool _active = true;
  int _ticks = 0, _lastFrame = -1, _readyAt = 0, _stampAt = -20;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock.addListener(() {
      final frame = (_clock.value * 200).floor();
      if (frame != _lastFrame) {
        _lastFrame = frame;
        _ticks++;
      }
    });
  }

  @override
  void didUpdateWidget(covariant GameSceneLife oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _readyAt = _ticks;
    if (widget.seal && !oldWidget.seal) _stampAt = _ticks;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (_active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
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
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => CustomPaint(
      painter: _Life(
        kind: widget.kind,
        frame: MediaQuery.disableAnimationsOf(context)
            ? 0
            : (_clock.value * 200).floor(),
        ready: widget.ready,
        rise: MediaQuery.disableAnimationsOf(context)
            ? 12
            : math.min(12, _ticks - _readyAt).toDouble(),
        writing: widget.writing,
        seal: widget.seal,
        stampDrop: MediaQuery.disableAnimationsOf(context)
            ? 0
            : math.max(0, 12 - (_ticks - _stampAt)).toDouble(),
        palette: GamePalette.of(context),
      ),
    ),
  );
}

class _Life extends CustomPainter {
  const _Life({
    required this.kind,
    required this.frame,
    required this.ready,
    required this.rise,
    required this.writing,
    required this.seal,
    required this.stampDrop,
    required this.palette,
  });
  final String kind;
  final int frame;
  final bool ready, writing, seal;
  final double rise, stampDrop;
  final GamePalette palette;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = GamePalette.gold.withValues(alpha: .6);
    for (var i = 0; i < 9; i++) {
      final x = (s.width * (.69 + (i * .073) % .27)).floorToDouble(),
          y = (s.height * (.2 + (i * .13) % .43)).floorToDouble();
      c.drawRect(Rect.fromLTWH(x, y, 2 + (frame + i) % 2, 2), p);
    }
    if (kind == 'letter') {
      final dx = writing ? (math.sin(frame / 3) * 4).roundToDouble() : 0.0;
      c.save();
      c.translate(s.width * .44 + dx, s.height * .35);
      c.rotate(-.45);
      p.color = GamePalette.inkLight;
      for (var i = 0; i < 8; i++) {
        p.color = GamePalette.woodDeep;
        c.drawRect(
          Rect.fromLTWH(
            i * 2 - 1,
            -i * 4 - 1,
            math.max(4, 16 - i.toDouble()),
            6,
          ),
          p,
        );
        p.color = GamePalette.inkLight;
        c.drawRect(
          Rect.fromLTWH(i * 2, -i * 4, math.max(2, 14 - i.toDouble()), 4),
          p,
        );
      }
      p.color = palette.wood;
      c.drawRect(const Rect.fromLTWH(0, -2, 3, 23), p);
      c.restore();
      if (seal) {
        p.color = GamePalette.red;
        c.drawRect(
          Rect.fromLTWH(s.width * .53, s.height * .39 - stampDrop, 18, 14),
          p,
        );
        p.color = GamePalette.gold;
        c.drawRect(
          Rect.fromLTWH(
            s.width * .53 + 6,
            s.height * .39 + 4 - stampDrop,
            6,
            6,
          ),
          p,
        );
      }
    } else if (kind == 'capsule' && ready) {
      final y = s.height * .47 - rise;
      p.color = palette.wood;
      c.drawRect(Rect.fromLTWH(s.width * .80 - 2, y - 2, 32, 22), p);
      p.color = GamePalette.gold;
      c.drawRect(Rect.fromLTWH(s.width * .80, y, 28, 18), p);
      p.color = GamePalette.woodDeep;
      c.drawRect(Rect.fromLTWH(s.width * .80, y + 7, 28, 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Life old) =>
      old.frame != frame ||
      old.kind != kind ||
      old.ready != ready ||
      old.rise != rise ||
      old.writing != writing ||
      old.seal != seal ||
      old.stampDrop != stampDrop ||
      old.palette != palette;
}

/// A real metric with a physical moon, footprints or exercise bar.
class GameObjectGauge extends StatelessWidget {
  const GameObjectGauge({
    super.key,
    required this.value,
    required this.kind,
    this.backgroundColor,
  });
  final Color? backgroundColor;
  final double value;
  final String kind;
  @override
  Widget build(BuildContext context) => Semantics(
    label: kind,
    value: value.isFinite ? '${(value.clamp(0, 1) * 100).round()}%' : '確認中',
    child: SizedBox(
      width: double.infinity,
      height: 64,
      child: CustomPaint(
        painter: _ObjectGauge(
          value: value,
          kind: kind,
          palette: GamePalette.of(context),
          background: backgroundColor,
        ),
      ),
    ),
  );
}

class _ObjectGauge extends CustomPainter {
  const _ObjectGauge({
    required this.value,
    required this.kind,
    required this.palette,
    this.background,
  });
  final Color? background;
  final double value;
  final String kind;
  final GamePalette palette;
  @override
  void paint(Canvas c, Size s) {
    final ratio = value.isFinite ? value.clamp(0.0, 1.0) : 0.0,
        p = Paint()..color = GamePalette.gold,
        x = s.width / 2;
    if (kind == '睡眠') {
      c.drawCircle(Offset(x, 32), 24, p);
      p.color = background ?? palette.backgroundTop;
      c.drawCircle(Offset(x + ratio * 48, 32), 24, p);
      p
        ..color = palette.wood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      c.drawCircle(Offset(x, 32), 24, p);
    } else if (kind == '步數') {
      for (var i = 0; i < 8; i++) {
        p.color = GamePalette.gold.withValues(
          alpha: i < (ratio * 8).ceil() ? 1 : .15,
        );
        final px = x - 55 + i * 14.0, py = i.isEven ? 18.0 : 32.0;
        c.drawRect(Rect.fromLTWH(px, py, 8, 14), p);
        c.drawRect(Rect.fromLTWH(px + 2, py - 5, 5, 4), p);
      }
    } else {
      p.color = palette.wood;
      c.drawRect(Rect.fromLTWH(x - 35, 10, 5, 48), p);
      c.drawRect(Rect.fromLTWH(x + 30, 10, 5, 48), p);
      c.drawRect(Rect.fromLTWH(x - 30, 10, 60, 5), p);
      p.color = GamePalette.gold;
      for (var i = 0; i < 5; i++) {
        p.color = GamePalette.gold.withValues(
          alpha: i < (ratio * 5).ceil() ? 1 : .15,
        );
        c.drawRect(Rect.fromLTWH(x - 20, 50 - i * 7, 40, 5), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ObjectGauge old) =>
      old.value != value ||
      old.kind != kind ||
      old.palette != palette ||
      old.background != background;
}

class GameSceneProp {
  const GameSceneProp({
    required this.label,
    required this.icon,
    required this.x,
    required this.y,
    required this.onTap,
    this.value,
    this.progress,
    this.gaugeKind,
  });
  final double? progress;
  final String? gaugeKind;
  final String label;
  final IconData icon;
  final double x, y;
  final VoidCallback onTap;
  final String? value;
}

class GameSceneObjects extends StatefulWidget {
  const GameSceneObjects({super.key, required this.objects});
  final List<GameSceneProp> objects;
  @override
  State<GameSceneObjects> createState() => _GameSceneObjectsState();
}

class _GameSceneObjectsState extends State<GameSceneObjects>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
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
    if (_active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
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
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final frame = MediaQuery.disableAnimationsOf(context)
            ? 0
            : (_clock.value * 200).floor();
        return Stack(
          children: [
            for (final prop in widget.objects)
              Positioned(
                left: (size.maxWidth * prop.x - 58).clamp(
                  4.0,
                  math.max(4.0, size.maxWidth - 120),
                ),
                top: size.maxHeight * prop.y + math.sin(frame / 8).round(),
                width: 116,
                child: Semantics(
                  button: true,
                  label: '${prop.label} ${prop.value ?? ''}',
                  excludeSemantics: true,
                  onTap: prop.onTap,
                  child: Tooltip(
                    message: prop.label,
                    child: TextButton(
                      onPressed: prop.onTap,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 64),
                        backgroundColor: GamePalette.woodDeep,
                        foregroundColor: GamePalette.inkLight,
                        side: BorderSide(
                          color: GamePalette.of(context).wood,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(prop.icon, color: GamePalette.gold, size: 28),
                          Text(
                            prop.label,
                            style: const TextStyle(
                              fontFamily: 'Cubic11',
                              fontSize: 14,
                            ),
                          ),
                          if (prop.value != null)
                            Text(
                              prop.value!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: GamePalette.inkLight,
                              ),
                            ),
                          if (prop.progress != null && prop.gaugeKind != null)
                            SizedBox(
                              height: 32,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width: 100,
                                  height: 64,
                                  child: GameObjectGauge(
                                    value: prop.progress!,
                                    kind: prop.gaugeKind!,
                                    backgroundColor: GamePalette.woodDeep,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
