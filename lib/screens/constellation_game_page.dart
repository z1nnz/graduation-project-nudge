import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/game_ui.dart';
import '../widgets/player_avatar.dart';
import 'firefly_game_page.dart';

/// Constellation (J6), played inside the App: watch the stars light up in
/// order, then tap them back; one more star each night; two slips end it.
/// Same rules as the Web's arcade_more_core.js; shares the three free plays
/// a day with Firefly lanterns.
class ConstellationGame {
  ConstellationGame([int seed = 7]) : _r = math.Random(seed) {
    _nextRound();
  }

  static const width = 320.0, height = 180.0;
  static const start = 3, maxStars = 10, slipsAllowed = 2;
  static const showMs = 600.0, durationMs = 90000.0;

  final math.Random _r;
  int round = 0, pos = 0, score = 0, slips = 0;
  List<Offset> stars = [];
  List<int> order = [];
  bool showing = true;
  double showT = 0, t = 0;
  bool done = false;

  void _nextRound() {
    round++;
    final n = math.min(maxStars, start + round - 1);
    stars = [];
    var guard = 0;
    while (stars.length < n && guard++ < 500) {
      final p = Offset(24 + _r.nextDouble() * 272, 22 + _r.nextDouble() * 136);
      if (stars.every((q) => (q - p).distance > 30)) stars.add(p);
    }
    order = List.generate(stars.length, (i) => i)..shuffle(_r);
    pos = 0;
    showing = true;
    showT = 0;
  }

  /// The star lit while the order is shown, or -1.
  int get lit {
    if (!showing) return -1;
    final k = (showT / showMs).floor();
    return k < order.length ? order[k] : -1;
  }

  void step(double dtMs) {
    if (done) return;
    t += dtMs;
    if (t >= durationMs) {
      done = true;
      return;
    }
    if (showing) {
      showT += dtMs;
      if (showT >= showMs * (order.length + 0.5)) showing = false;
    }
  }

  /// 'link', 'complete', 'slip', 'over' or 'wait'.
  String pick(int i) {
    if (done || showing) return 'wait';
    if (order[pos] == i) {
      pos++;
      score++;
      if (pos >= order.length) {
        score += order.length;
        _nextRound();
        return 'complete';
      }
      return 'link';
    }
    slips++;
    if (slips >= slipsAllowed) {
      done = true;
      return 'over';
    }
    pos = 0;
    showing = true;
    showT = 0;
    return 'slip';
  }

  int starAt(Offset p, [double reach = 14]) {
    var best = -1;
    var d = reach;
    for (var i = 0; i < stars.length; i++) {
      final k = (stars[i] - p).distance;
      if (k <= d) {
        d = k;
        best = i;
      }
    }
    return best;
  }

  static String grade(int score) => score >= 45
      ? 'S'
      : score >= 28
      ? 'A'
      : score >= 14
      ? 'B'
      : 'C';
}

class ConstellationGamePage extends StatefulWidget {
  const ConstellationGamePage({super.key, this.seed, this.now});
  final int? seed;
  final DateTime? now;

  @override
  State<ConstellationGamePage> createState() => _ConstellationGamePageState();
}

class _ConstellationGamePageState extends State<ConstellationGamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  ConstellationGame? _game;
  Duration _last = Duration.zero;
  int? _left;
  int _bad = -1;
  PlayerAnimation _anim = PlayerAnimation.idle;
  String _say = '先看清楚星星亮起的順序。';

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
      _game = ConstellationGame(
        widget.seed ?? DateTime.now().millisecondsSinceEpoch % 100000,
      );
      _say = '先看清楚星星亮起的順序。';
      _last = Duration.zero;
    });
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final g = _game;
    if (g == null) return;
    final dt = (elapsed - _last).inMicroseconds / 1000;
    _last = elapsed;
    final was = g.showing;
    setState(() {
      g.step(dt);
      if (was && !g.showing) _say = '換你了！照順序點星星。';
      if (g.done) {
        _ticker.stop();
        _anim = ConstellationGame.grade(g.score) == 'C'
            ? PlayerAnimation.think
            : PlayerAnimation.happy;
      }
    });
  }

  void _tap(Offset local, Size size) {
    final g = _game;
    if (g == null || g.done) return;
    final i = g.starAt(
      Offset(
        local.dx / size.width * ConstellationGame.width,
        local.dy / size.height * ConstellationGame.height,
      ),
    );
    if (i < 0) return;
    final e = g.pick(i);
    setState(() {
      switch (e) {
        case 'link':
          _anim = PlayerAnimation.happy;
        case 'complete':
          _anim = PlayerAnimation.happy;
          _say = '星座完成！下一夜多一顆星。';
        case 'slip':
          _bad = i;
          _anim = PlayerAnimation.think;
          _say = '順序不對，再看一次！';
        case 'over':
          _bad = i;
          _say = '星星躲進雲裡了。';
          _ticker.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFF160F2E),
      appBar: AppBar(
        title: const Text('星座連線'),
        actions: [
          if (g != null && !g.done)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '第 ${g.round} 夜 · 連線 ${g.score} · 失誤 ${g.slips}/${ConstellationGame.slipsAllowed}',
                  key: const Key('constellation-hud'),
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
                      key: const Key('constellation-sky'),
                      onTapDown: (d) => _tap(d.localPosition, box.biggest),
                      child: CustomPaint(
                        size: box.biggest,
                        painter: _SkyPainter(g, _bad, still),
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
            if (g != null && g.done)
              Container(
                key: const Key('constellation-result'),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamePalette.parchment,
                  border: Border.all(color: GamePalette.woodDeep, width: 3),
                ),
                child: Column(
                  children: [
                    Text(
                      '評級 ${ConstellationGame.grade(g.score)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: GamePalette.inkDark,
                      ),
                    ),
                    Text(
                      '連到第 ${g.round} 夜 · 連線 ${g.score} 條',
                      style: const TextStyle(color: GamePalette.inkDark),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: g == null || g.done
                  ? FilledButton(
                      key: const Key('constellation-start'),
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

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.game, this.bad, this.still);
  final ConstellationGame? game;
  final int bad;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 180);
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
    for (var i = 0; i < 40; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          ((i * 73) % 320).toDouble(),
          ((i * 37) % 110).toDouble(),
          1,
          1,
        ),
        p..color = const Color(0x99F6F0FF),
      );
    }
    p.color = const Color(0xFF2B2050);
    for (var x = 0; x < 320; x++) {
      final y = 140 - (6 + 4 * math.sin(x / 23) + 2 * math.sin(x / 7)).round();
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 60), p);
    }
    final g = game;
    if (g != null) {
      final linked = g.order.take(g.pos).toList();
      final line = Paint()
        ..color = const Color(0xFFBFE3FF)
        ..strokeWidth = 1
        ..isAntiAlias = false;
      for (var k = 1; k < linked.length; k++) {
        canvas.drawLine(g.stars[linked[k - 1]], g.stars[linked[k]], line);
      }
      for (var i = 0; i < g.stars.length; i++) {
        final s = g.stars[i];
        final on = i == g.lit || linked.contains(i);
        final c = i == bad && !g.showing
            ? const Color(0xFFD8452E)
            : on
            ? const Color(0xFFFFE7A8)
            : const Color(0xFF8A7AB8);
        canvas.drawRect(
          Rect.fromCenter(center: s, width: 5, height: 5),
          p..color = c,
        );
        canvas.drawRect(Rect.fromCenter(center: s, width: 9, height: 1), p);
        canvas.drawRect(Rect.fromCenter(center: s, width: 1, height: 9), p);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
