import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/nudge_device_coordinator.dart';
import '../theme/game_ui.dart';

Color deviceWorkbenchLight(NudgeDeviceCoordinatorState state) =>
    switch (state.status) {
      NudgeDeviceConnectionStatus.error => GamePalette.red,
      NudgeDeviceConnectionStatus.scanning => GamePalette.gold,
      NudgeDeviceConnectionStatus.connected =>
        state.phase == 'focus' ? GamePalette.violet : GamePalette.green,
      _ => GamePalette.inkSoft,
    };

class GameDeviceWorkbench extends StatefulWidget {
  const GameDeviceWorkbench({
    super.key,
    required this.state,
    required this.label,
  });
  final NudgeDeviceCoordinatorState state;
  final String label;
  @override
  State<GameDeviceWorkbench> createState() => _GameDeviceWorkbenchState();
}

class _GameDeviceWorkbenchState extends State<GameDeviceWorkbench>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
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

  @override
  void didUpdateWidget(covariant GameDeviceWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving =
        widget.state.status == NudgeDeviceConnectionStatus.scanning ||
        widget.state.status == NudgeDeviceConnectionStatus.connected &&
            widget.state.phase == 'focus';
    if (_active &&
        moving &&
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
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '連線燈：${widget.label}',
    child: Align(
      alignment: const Alignment(.45, -.15),
      child: SizedBox(
        width: 176,
        height: 220,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final frame = MediaQuery.disableAnimationsOf(context)
                ? 0
                : (_clock.value * 20).floor();
            return Column(
              children: [
                SizedBox(
                  height: 144,
                  width: 160,
                  child: CustomPaint(
                    key: const ValueKey('device-connection-led'),
                    painter: _DevicePainter(
                      color: deviceWorkbenchLight(widget.state),
                      frame: frame,
                      scanning:
                          widget.state.status ==
                          NudgeDeviceConnectionStatus.scanning,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamePalette.woodDeep,
                    border: Border.all(
                      color: GamePalette.of(context).wood,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cubic11',
                          fontSize: 14,
                          color: GamePalette.inkLight,
                        ),
                      ),
                      if (widget.state.status ==
                          NudgeDeviceConnectionStatus.connected)
                        Text(
                          '裝置回報 ${widget.state.remainingSeconds} 秒',
                          style: const TextStyle(
                            fontSize: 14,
                            color: GamePalette.inkLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({
    required this.color,
    required this.frame,
    required this.scanning,
  });
  final Color color;
  final int frame;
  final bool scanning;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..isAntiAlias = false
      ..color = GamePalette.woodDeep;
    final x = s.width / 2;
    c.drawRect(Rect.fromLTWH(x - 66, 35, 132, 94), p);
    p.color = GamePalette.woodDark;
    c.drawRect(Rect.fromLTWH(x - 60, 29, 120, 94), p);
    p.color = GamePalette.woodDeep;
    c.drawRect(Rect.fromLTWH(x - 47, 40, 94, 66), p);
    p.color = color;
    c.drawRect(Rect.fromLTWH(x - 42, 45, 84, 5), p);
    c.drawRect(Rect.fromLTWH(x - 42, 95, 84, 5), p);
    c.drawRect(Rect.fromLTWH(x - 42, 45, 5, 55), p);
    c.drawRect(Rect.fromLTWH(x + 37, 45, 5, 55), p);
    p.color = GamePalette.gold;
    c.drawRect(Rect.fromLTWH(x - 10, 111, 20, 8), p);
    p.color = color;
    if (scanning) {
      for (var i = 0; i < 3; i++) {
        p.color = color.withValues(alpha: .35 + ((frame + i) % 3) * .25);
        final h = 5 + i * 5.0;
        c.drawRect(Rect.fromLTWH(x - 22 + i * 16, 24 - h, 8, h), p);
      }
    } else {
      c.drawRect(Rect.fromLTWH(x - 5, 65, 10, 10), p);
    }
    p.color = GamePalette.gold.withValues(
      alpha: .6 + math.sin(frame / 3) * .15,
    );
    c.drawRect(Rect.fromLTWH(x - 54, 132, 108, 5), p);
  }

  @override
  bool shouldRepaint(covariant _DevicePainter old) =>
      old.color != color || old.frame != frame || old.scanning != scanning;
}
