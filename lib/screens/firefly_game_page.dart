import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/game_ui.dart';
import '../widgets/player_avatar.dart';

/// Firefly lanterns (J6), played inside the App: tap fireflies while they
/// glow to fill the lantern; quick catches chain a combo; 45 seconds. Same
/// rules as the Web's arcade_more_core.js. Three free plays a day, counted on
/// this device (the day starts at 05:00 like the Web arcade).
class FireflyGame {
  FireflyGame([int seed = 1]) : _r = math.Random(seed) {
    flies = List.generate(count, (i) => _spawn(i));
  }

  static const width = 320.0, height = 180.0;
  static const durationMs = 45000.0, count = 7, radius = 12.0;
  static const comboMs = 1200.0, glowMs = 1300.0, darkMs = 900.0;

  final math.Random _r;
  late List<Firefly> flies;
  double t = 0;
  int score = 0, caught = 0, combo = 0, best = 0;
  double _last = -1e9;
  bool get done => t >= durationMs;

  Firefly _spawn(int i) => Firefly(
    30 + _r.nextDouble() * 260,
    30 + _r.nextDouble() * 110,
    _r.nextDouble() * 6.28,
    0.4 + _r.nextDouble() * 0.6,
    _r.nextDouble() * (glowMs + darkMs),
  );

  ({Offset at, bool lit}) flyAt(Firefly f) {
    final a = f.phase + t / 1000 * f.speed;
    final cycle = (t + f.offset) % (glowMs + darkMs);
    return (
      at: Offset(f.ax + math.sin(a) * 24, f.ay + math.sin(a * 1.7) * 14),
      lit: cycle < glowMs,
    );
  }

  void step(double dtMs) {
    if (!done) t = math.min(durationMs, t + dtMs);
  }

  /// 'catch', 'dark' (it was not glowing) or 'miss'; points scored.
  (String, int) catchAt(Offset p) {
    if (done) return ('miss', 0);
    var dark = false;
    for (var i = 0; i < flies.length; i++) {
      final s = flyAt(flies[i]);
      if ((s.at - p).distance > radius) continue;
      if (!s.lit) {
        dark = true;
        continue;
      }
      combo = t - _last <= comboMs ? combo + 1 : 1;
      best = math.max(best, combo);
      _last = t;
      final pts = 10 + math.min(5, combo - 1) * 2;
      score += pts;
      caught++;
      flies[i] = _spawn(i);
      return ('catch', pts);
    }
    combo = 0;
    return (dark ? 'dark' : 'miss', 0);
  }

  static String grade(int score) => score >= 300
      ? 'S'
      : score >= 200
      ? 'A'
      : score >= 120
      ? 'B'
      : 'C';
}

class Firefly {
  Firefly(this.ax, this.ay, this.phase, this.speed, this.offset);
  final double ax, ay, phase, speed, offset;
}

/// Free plays a day, kept on this device.
abstract final class AppArcadePlays {
  static const perDay = 3;
  static String dayKey(DateTime now) {
    final d = now.subtract(const Duration(hours: 5));
    return 'nudge.arcade.app.plays.${d.year}-${d.month}-${d.day}';
  }

  static Future<int> left(DateTime now) async {
    try {
      final p = await SharedPreferences.getInstance();
      return math.max(0, perDay - (p.getInt(dayKey(now)) ?? 0));
    } catch (_) {
      return perDay;
    }
  }

  static Future<void> spend(DateTime now) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(dayKey(now), (p.getInt(dayKey(now)) ?? 0) + 1);
  }
}

class FireflyGamePage extends StatefulWidget {
  const FireflyGamePage({super.key, this.seed, this.now});
  final int? seed;
  final DateTime? now;

  @override
  State<FireflyGamePage> createState() => _FireflyGamePageState();
}

class _FireflyGamePageState extends State<FireflyGamePage>
    with SingleTickerProviderStateMixin {
  FireflyGame? _game;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  int? _left;
  final _sparks = <_Spark>[];
  PlayerAnimation _anim = PlayerAnimation.idle;
  String _say = '等螢火蟲亮起來再點牠！';
  bool _over = false;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    AppArcadePlays.left(
      _now,
    ).then((v) => mounted ? setState(() => _left = v) : null);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if ((_left ?? 0) <= 0) return;
    await AppArcadePlays.spend(_now);
    setState(() {
      _left = (_left ?? 1) - 1;
      _game = FireflyGame(
        widget.seed ?? DateTime.now().millisecondsSinceEpoch % 100000,
      );
      _over = false;
      _lastTick = Duration.zero;
    });
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final g = _game;
    if (g == null) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1000;
    _lastTick = elapsed;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    setState(() {
      g.step(dt);
      if (!still) {
        for (final s in _sparks) {
          s.age += dt;
        }
        _sparks.removeWhere((s) => s.age > 420);
      } else {
        _sparks.clear();
      }
      if (g.done) {
        _ticker.stop();
        _over = true;
        _anim = FireflyGame.grade(g.score) == 'C'
            ? PlayerAnimation.think
            : PlayerAnimation.happy;
      }
    });
  }

  void _tap(Offset local, Size size) {
    final g = _game;
    if (g == null || g.done) return;
    final p = Offset(
      local.dx / size.width * FireflyGame.width,
      local.dy / size.height * FireflyGame.height,
    );
    final (event, pts) = g.catchAt(p);
    setState(() {
      if (event == 'catch') {
        _sparks.add(_Spark(p, pts, g.combo));
        _anim = PlayerAnimation.happy;
        _say = g.combo > 1 ? '連擊 ×${g.combo}！' : '抓到了！';
      } else {
        _anim = PlayerAnimation.think;
        _say = event == 'dark' ? '牠現在沒發光，等牠亮起來再抓！' : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      backgroundColor: const Color(0xFF160F2E),
      appBar: AppBar(
        title: const Text('螢火蟲燈籠'),
        actions: [
          if (g != null && !g.done)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '光點 ${g.score} · ${((FireflyGame.durationMs - g.t) / 1000).ceil()} 秒',
                  key: const Key('firefly-hud'),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      key: const Key('firefly-field'),
                      onTapDown: (d) => _tap(d.localPosition, box.biggest),
                      child: CustomPaint(
                        painter: _FieldPainter(
                          g,
                          _sparks,
                          MediaQuery.maybeDisableAnimationsOf(context) ?? false,
                        ),
                        size: box.biggest,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerAvatar(
                  key: const Key('firefly-buddy'),
                  animation: _anim,
                  scale: 2,
                  onEnd: () => setState(() => _anim = PlayerAnimation.idle),
                  fallback: const Icon(
                    Icons.face,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _say,
                    style: const TextStyle(color: Color(0xFFFFE6A3)),
                  ),
                ),
              ],
            ),
            if (_over && g != null)
              _Result(
                key: const Key('firefly-result'),
                grade: FireflyGame.grade(g.score),
                lines: [
                  '收進燈籠 ${g.caught} 隻',
                  '光點 ${g.score}',
                  '最長連擊 ${g.best}',
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: g == null || g.done
                  ? FilledButton(
                      key: const Key('firefly-start'),
                      onPressed: (_left ?? 0) > 0 ? _start : null,
                      child: Text(
                        _left == null
                            ? '確認今天的次數…'
                            : (_left! > 0
                                  ? '開始（今天還能免費玩 $_left 次）'
                                  : '今天的 ${AppArcadePlays.perDay} 次免費遊玩用完了，明天早上 5 點補滿'),
                      ),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spark {
  _Spark(this.at, this.points, this.combo);
  final Offset at;
  final int points, combo;
  double age = 0;
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.game, this.sparks, this.still);
  final FireflyGame? game;
  final List<_Spark> sparks;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / FireflyGame.width,
      size.height / FireflyGame.height,
    );
    final p = Paint()..isAntiAlias = false;
    const bands = [
      Color(0xFF160F2E),
      Color(0xFF2A1D52),
      Color(0xFF3A2766),
      Color(0xFF4A2F6E),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(Rect.fromLTWH(0, i * 30.0, 320, 31), p..color = bands[i]);
    }
    final t = game?.t ?? 0;
    for (var i = 0; i < 40; i++) {
      if (!still && ((t / 400).floor() + i) % 11 == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          ((i * 73) % 320).toDouble(),
          ((i * 37) % 110).toDouble(),
          1,
          1,
        ),
        p..color = const Color(0xFFF6F0FF),
      );
    }
    p.color = const Color(0xFF2B2050);
    for (var x = 0; x < 320; x++) {
      final y = 120 - (6 + 4 * math.sin(x / 23) + 2 * math.sin(x / 7)).round();
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 60), p);
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 150, 320, 30),
      p..color = const Color(0xFF1F3A2A),
    );
    final g = game;
    if (g != null) {
      final fill = math.min(1.0, g.caught / 30);
      canvas.drawRect(
        const Rect.fromLTWH(292, 40, 20, 70),
        p..color = const Color(0xFF3A2216),
      );
      canvas.drawRect(
        Rect.fromLTWH(294, 108 - 66 * fill, 16, 66 * fill),
        p..color = const Color(0xFFFFD56B),
      );
      for (final f in g.flies) {
        final s = g.flyAt(f);
        if (s.lit) {
          canvas.drawRect(
            Rect.fromCenter(center: s.at, width: 9, height: 9),
            p..color = const Color(0x40E9FF8A),
          );
          canvas.drawRect(
            Rect.fromCenter(center: s.at, width: 3, height: 3),
            p..color = const Color(0xFFE9FF8A),
          );
        } else {
          canvas.drawRect(
            Rect.fromCenter(center: s.at, width: 2, height: 2),
            p..color = const Color(0xFF5A5A3A),
          );
        }
      }
      for (final s in sparks) {
        final k = s.age / 420;
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawRect(
            Rect.fromLTWH(
              s.at.dx + math.cos(a) * 14 * k,
              s.at.dy + math.sin(a) * 14 * k,
              2,
              2,
            ),
            p..color = const Color(0xFFFFE36B),
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FieldPainter old) => true;
}

class _Result extends StatelessWidget {
  const _Result({super.key, required this.grade, required this.lines});
  final String grade;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final stars = const {'S': 3, 'A': 2, 'B': 1}[grade] ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GamePalette.parchment,
        border: Border.all(color: GamePalette.woodDeep, width: 3),
      ),
      child: Column(
        children: [
          Text(
            '評級 $grade',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: GamePalette.inkDark,
            ),
          ),
          Text(
            '★' * stars + '☆' * (3 - stars),
            style: const TextStyle(fontSize: 24, color: GamePalette.goldDeep),
          ),
          for (final l in lines)
            Text(l, style: const TextStyle(color: GamePalette.inkDark)),
        ],
      ),
    );
  }
}
