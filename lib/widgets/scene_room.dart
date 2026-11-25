import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../models/character_catalog.dart';
import '../theme/game_ui.dart';
import 'npc_dialog.dart';
import 'sprite_animation.dart';

/// A clickable thing in a room. [rect] is in fractions of the art (0–1).
class SceneObject {
  const SceneObject({
    required this.id,
    required this.label,
    required this.rect,
    required this.onTap,
    this.hint,
    this.badge = 0,
  });

  final String id, label;
  final String? hint;
  final Rect rect;
  final int badge;
  final void Function(BuildContext context, SceneRoomController room) onTap;
}

enum SceneEffectKind { dust, glow, sparkle, fireflies, stars, flutter, steam }

/// Ambient life drawn over the art at 10 fps; [points] are art fractions.
class SceneEffect {
  const SceneEffect.dust({this.count = 16})
    : kind = SceneEffectKind.dust,
      points = const [],
      radius = 0,
      top = 0,
      band = 0;
  const SceneEffect.glow(this.points, {this.radius = 0.09})
    : kind = SceneEffectKind.glow,
      count = 0,
      top = 0,
      band = 0;
  const SceneEffect.sparkle(this.points)
    : kind = SceneEffectKind.sparkle,
      count = 0,
      radius = 0,
      top = 0,
      band = 0;
  const SceneEffect.fireflies({this.count = 14, this.top = 0.3, this.band = 0.5})
    : kind = SceneEffectKind.fireflies,
      points = const [],
      radius = 0;
  const SceneEffect.stars({this.count = 26, this.band = 0.25})
    : kind = SceneEffectKind.stars,
      points = const [],
      radius = 0,
      top = 0;
  const SceneEffect.flutter({this.count = 6, this.top = 0.2, this.band = 0.6})
    : kind = SceneEffectKind.flutter,
      points = const [],
      radius = 0;
  const SceneEffect.steam(this.points)
    : kind = SceneEffectKind.steam,
      count = 0,
      radius = 0,
      top = 0,
      band = 0;

  final SceneEffectKind kind;
  final List<Offset> points;
  final int count;
  final double radius, top, band;
}

enum BurstKind { coin, star, heart, seal, leaf }

/// What objects can do to their room.
abstract class SceneRoomController {
  Future<void> say(List<String> lines, {List<NpcDialogAction> actions});
  void burst(BurstKind kind, {required String from, String? to, int count, String? announce});
}

/// A facility room: generated art, glowing objects with wooden signs, an NPC
/// who talks, ambient life and reward bursts. The art is fitted whole (never
/// cropped) and a blurred copy fills the rest of the screen.
class SceneRoom extends StatefulWidget {
  const SceneRoom({
    super.key,
    required this.art,
    required this.title,
    required this.objects,
    this.aspect = 2 / 3,
    this.npc,
    this.npcAt = const Offset(0.28, 0.88),
    this.greeting,
    this.tips = const [],
    this.effects = const [],
    this.trailing,
    this.footer,
  });

  final String art, title;
  final double aspect;
  final GameCharacter? npc;
  final Offset npcAt;
  final List<String> Function()? greeting;
  final List<String> tips;
  final List<SceneObject> objects;
  final List<SceneEffect> effects;
  final Widget? trailing, footer;

  @override
  State<SceneRoom> createState() => SceneRoomState();
}

class _Burst {
  _Burst(this.kind, this.from, this.to, this.count, this.start);
  final BurstKind kind;
  final Offset from, to;
  final int count;
  final Duration start;
}

class SceneRoomState extends State<SceneRoom>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver
    implements SceneRoomController {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  final _clock = ValueNotifier<Duration>(Duration.zero);
  final List<_Burst> _bursts = [];
  Rect _artRect = Rect.zero;
  bool _talking = false, _resumed = true;
  int _tipIndex = 0;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  /// Whether the ambient clock is running (false under reduced motion).
  @visibleForTesting
  bool get animating => _ticker.isActive;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final run =
        _resumed && !_reduced && TickerMode.valuesOf(context).enabled;
    if (run && !_ticker.isActive) _ticker.start();
    if (!run && _ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    _clock.value = elapsed;
    final f = elapsed.inMilliseconds ~/ 100;
    if (f != _frame.value) _frame.value = f;
    _bursts.removeWhere(
      (b) => elapsed - b.start > const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _clock.dispose();
    super.dispose();
  }

  Offset _center(String id) {
    final o = widget.objects.where((o) => o.id == id).firstOrNull;
    final r = o?.rect ?? const Rect.fromLTWH(0.4, 0.4, 0.2, 0.2);
    return Offset(
      _artRect.left + r.center.dx * _artRect.width,
      _artRect.top + r.center.dy * _artRect.height,
    );
  }

  @override
  void burst(
    BurstKind kind, {
    required String from,
    String? to,
    int count = 8,
    String? announce,
  }) {
    if (announce != null) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        announce,
        Directionality.of(context),
      );
    }
    if (_reduced || !_ticker.isActive) return;
    final a = _center(from);
    final b = to == null ? a.translate(0, -140) : _center(to);
    setState(() => _bursts.add(_Burst(kind, a, b, count, _clock.value)));
  }

  @override
  Future<void> say(
    List<String> lines, {
    List<NpcDialogAction> actions = const [],
  }) async {
    final npc = widget.npc;
    if (npc == null || lines.isEmpty) return;
    setState(() => _talking = true);
    await NpcDialog.show(context, speaker: npc, lines: lines, actions: actions);
    if (mounted) setState(() => _talking = false);
  }

  Future<void> _talk() {
    final lines = [...?widget.greeting?.call()];
    if (widget.tips.isNotEmpty) {
      lines.add(widget.tips[_tipIndex++ % widget.tips.length]);
    }
    return say(lines.isEmpty ? const ['你好！'] : lines);
  }

  Rect _fit(Size box) {
    // Fit the whole art; leave room for the title bar on top.
    const top = 64.0;
    final avail = Size(box.width, math.max(1, box.height - top));
    var w = avail.width, h = w / widget.aspect;
    if (h > avail.height) {
      h = avail.height;
      w = h * widget.aspect;
    }
    return Rect.fromLTWH(
      (box.width - w) / 2,
      top + (avail.height - h) / 2,
      w,
      h,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return GameBackground(
      child: LayoutBuilder(
        builder: (context, box) {
          _artRect = _fit(box.biggest);
          final art = _artRect;
          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0x88140E22),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(
                        widget.art,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: p.backgroundBottom),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: art,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(color: GamePalette.woodDeep, width: 3),
                    ),
                    child: Image.asset(
                      widget.art,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: p.backgroundBottom),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: art,
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (_, f, _) => CustomPaint(
                      painter: _LifePainter(widget.effects, _reduced ? 0 : f),
                    ),
                  ),
                ),
              ),
              for (final o in widget.objects)
                Positioned(
                  left: art.left + o.rect.left * art.width,
                  top: art.top + o.rect.top * art.height,
                  width: math.max(44, o.rect.width * art.width),
                  height: math.max(44, o.rect.height * art.height),
                  child: _ObjectHotspot(
                    object: o,
                    frame: _frame,
                    reduced: _reduced,
                    onTap: () => o.onTap(context, this),
                  ),
                ),
              if (widget.npc != null)
                Positioned(
                  left: art.left + widget.npcAt.dx * art.width - 56,
                  top: art.top + widget.npcAt.dy * art.height - 132,
                  child: _Npc(
                    character: widget.npc!,
                    talking: _talking,
                    onTap: _talk,
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: _TitleBar(
                  title: widget.title,
                  trailing: widget.trailing,
                ),
              ),
              if (widget.footer != null)
                Positioned(left: 12, right: 12, bottom: 12, child: widget.footer!),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<Duration>(
                    valueListenable: _clock,
                    builder: (_, now, _) => CustomPaint(
                      painter: _BurstPainter(List.of(_bursts), now),
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
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A34), GamePalette.woodDark],
        ),
        border: Border.all(color: GamePalette.woodDeep, width: 3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: '回小鎮',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: GamePalette.inkLight),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cubic11',
                  fontSize: 20,
                  color: GamePalette.gold,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ObjectHotspot extends StatefulWidget {
  const _ObjectHotspot({
    required this.object,
    required this.frame,
    required this.reduced,
    required this.onTap,
  });
  final SceneObject object;
  final ValueListenable<int> frame;
  final bool reduced;
  final VoidCallback onTap;

  @override
  State<_ObjectHotspot> createState() => _ObjectHotspotState();
}

class _ObjectHotspotState extends State<_ObjectHotspot> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.object;
    return Semantics(
      key: ValueKey('scene-object-${o.id}'),
      button: true,
      label: o.hint == null ? o.label : '${o.label}：${o.hint}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hot = true),
        onExit: (_) => setState(() => _hot = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _hot = true),
          onTapCancel: () => setState(() => _hot = false),
          onTapUp: (_) => setState(() => _hot = false),
          child: ValueListenableBuilder<int>(
            valueListenable: widget.frame,
            builder: (context, f, _) {
              final pulse = widget.reduced
                  ? 0.35
                  : 0.1 + 0.5 * (0.5 + 0.5 * math.sin(f / 4 + o.id.length));
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            GamePalette.gold.withValues(
                              alpha: _hot ? 0.55 : pulse * 0.6,
                            ),
                            GamePalette.gold.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -14,
                    child: Center(child: _Sign(o.label, hot: _hot)),
                  ),
                  if (o.badge > 0)
                    Positioned(
                      right: -4,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: GamePalette.red,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: GamePalette.woodDeep,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '${o.badge}',
                          style: const TextStyle(
                            fontFamily: 'Cubic11',
                            fontSize: 13,
                            color: GamePalette.inkLight,
                          ),
                        ),
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
}

class _Sign extends StatelessWidget {
  const _Sign(this.text, {this.hot = false});
  final String text;
  final bool hot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8A5A34), GamePalette.woodDark],
      ),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: hot ? GamePalette.gold : GamePalette.woodDeep,
        width: 2,
      ),
      boxShadow: const [
        BoxShadow(color: GamePalette.woodDeep, offset: Offset(0, 2)),
      ],
    ),
    child: Text(
      text,
      maxLines: 1,
      style: const TextStyle(
        fontFamily: 'Cubic11',
        fontSize: 14,
        color: GamePalette.inkLight,
      ),
    ),
  );
}

class _Npc extends StatelessWidget {
  const _Npc({
    required this.character,
    required this.talking,
    required this.onTap,
  });
  final GameCharacter character;
  final bool talking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('scene-npc'),
    button: true,
    label: '和${character.name}說話',
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterSprite(
              character: character,
              animation: talking
                  ? CharacterAnimation.talk
                  : CharacterAnimation.idle,
              size: 112,
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: _Sign(character.name),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LifePainter extends CustomPainter {
  _LifePainter(this.effects, this.f);
  final List<SceneEffect> effects;
  final int f;

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint();
    for (final e in effects) {
      switch (e.kind) {
        case SceneEffectKind.dust:
          for (var i = 0; i < e.count; i++) {
            final x = ((i * 0.618 + f * 0.0007 * (1 + i % 3)) % 1) * s.width;
            final y = (1 - ((i * 0.377 + f * 0.0011) % 1)) * s.height;
            paint.color = const Color(0xFFFFE7A8).withValues(
              alpha: (0.25 + 0.25 * math.sin(f / 9 + i)).clamp(0, 1),
            );
            canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
          }
        case SceneEffectKind.glow:
          for (var i = 0; i < e.points.length; i++) {
            final c = Offset(
              e.points[i].dx * s.width,
              e.points[i].dy * s.height,
            );
            final r =
                e.radius *
                s.width *
                (1 + 0.08 * math.sin(f / 3 + i * 2) + 0.05 * math.sin(f / 1.7 + i));
            paint.shader = RadialGradient(
              colors: [const Color(0x73FFC85A), const Color(0x00FFC85A)],
            ).createShader(Rect.fromCircle(center: c, radius: r));
            canvas.drawCircle(c, r, paint);
            paint.shader = null;
          }
        case SceneEffectKind.sparkle:
          paint.color = const Color(0xE6FFF6C8);
          for (var i = 0; i < e.points.length; i++) {
            final phase = (f + i * 7) % 24;
            if (phase > 8) continue;
            final k = (phase < 4 ? phase : 8 - phase).toDouble();
            final x = e.points[i].dx * s.width, y = e.points[i].dy * s.height;
            canvas.drawRect(Rect.fromLTWH(x - k, y, k * 2 + 1, 1.5), paint);
            canvas.drawRect(Rect.fromLTWH(x, y - k, 1.5, k * 2 + 1), paint);
          }
        case SceneEffectKind.fireflies:
          for (var i = 0; i < e.count; i++) {
            final on = math.sin(f / 7 + i * 1.3);
            if (on < 0) continue;
            final x = (0.5 + 0.45 * math.sin(f / 70 + i * 1.7)) * s.width;
            final y =
                (e.top + (0.5 + 0.5 * math.sin(f / 53 + i * 2.3)) * e.band) *
                s.height;
            paint.color = const Color(0xFFD8FF8A).withValues(alpha: on * 0.25);
            canvas.drawRect(Rect.fromLTWH(x - 3, y - 3, 9, 9), paint);
            paint.color = const Color(0xFFD8FF8A).withValues(alpha: on);
            canvas.drawRect(Rect.fromLTWH(x, y, 3, 3), paint);
          }
        case SceneEffectKind.stars:
          for (var i = 0; i < e.count; i++) {
            final x = ((i * 0.733) % 1) * s.width;
            final y = ((i * 0.419) % 1) * e.band * s.height;
            paint.color = Colors.white.withValues(
              alpha: (0.3 + 0.7 * math.max(0, math.sin(f / 6 + i * 1.9))).clamp(0, 1),
            );
            canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
          }
        case SceneEffectKind.flutter:
          for (var i = 0; i < e.count; i++) {
            final t = (f * 0.004 + i / e.count) % 1;
            final x = (0.5 + 0.35 * math.sin(i * 2.1) + 0.05 * math.sin(f / 8 + i)) * s.width;
            final y = (e.top + t * e.band) * s.height;
            paint.color = const Color(0xFFF6E7C8).withValues(alpha: 0.8 * (1 - t));
            canvas.drawRect(
              Rect.fromLTWH(x, y, 5, (math.sin(f / 5 + i).abs() * 4 + 1)),
              paint,
            );
          }
        case SceneEffectKind.steam:
          for (var i = 0; i < e.points.length; i++) {
            for (var k = 0; k < 5; k++) {
              final t = (f * 0.02 + k / 5 + i * 0.3) % 1;
              paint.color = const Color(0xFFF3EEE8).withValues(alpha: 0.35 * (1 - t));
              canvas.drawRect(
                Rect.fromLTWH(
                  e.points[i].dx * s.width + math.sin(t * 6 + i) * 6,
                  e.points[i].dy * s.height - t * 0.08 * s.height,
                  4,
                  4,
                ),
                paint,
              );
            }
          }
      }
    }
  }

  @override
  bool shouldRepaint(_LifePainter old) => old.f != f || old.effects != effects;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.bursts, this.now);
  final List<_Burst> bursts;
  final Duration now;

  static const _colors = {
    BurstKind.coin: GamePalette.gold,
    BurstKind.star: Color(0xFFFFF1A8),
    BurstKind.heart: Color(0xFFFF7A9C),
    BurstKind.seal: GamePalette.red,
    BurstKind.leaf: Color(0xFF8FD96B),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint(), edge = Paint()..color = GamePalette.woodDeep;
    for (final b in bursts) {
      for (var i = 0; i < b.count; i++) {
        final t =
            ((now - b.start).inMilliseconds - i * 45) / 900.0;
        if (t <= 0 || t >= 1) continue;
        final spread = (i - (b.count - 1) / 2) * 14.0;
        final arc = -40.0 - (i % 3) * 22;
        final lift = math.sin(t * math.pi) * arc;
        final pos = Offset.lerp(b.from, b.to + Offset(b.to == b.from ? spread : 0, 0), t)!
            .translate(spread * (1 - t) * 0.4, lift);
        final r = 5.0 * (t < 0.15 ? t / 0.15 : 1.0);
        fill.color = _colors[b.kind]!.withValues(alpha: (1 - t * t).clamp(0, 1));
        canvas.drawRect(Rect.fromCenter(center: pos.translate(1.5, 1.5), width: r * 2, height: r * 2), edge);
        canvas.drawRect(Rect.fromCenter(center: pos, width: r * 2, height: r * 2), fill);
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => true;
}
