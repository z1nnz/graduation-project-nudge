import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/character_catalog.dart';
import '../../theme/game_ui.dart';
import '../npc_dialog.dart';
import '../sprite_animation.dart';

/// How a spot reacts when the companion reaches it.
enum LivingChange { open, lit, flutter, shake, pulse, rise }

/// A place in the banner art the companion can walk to. [rect] is in
/// fractions of the banner (0–1). [onArrive] opens the page's existing
/// feature; [line] lets the NPC say something instead.
class LivingSpot {
  const LivingSpot({
    required this.id,
    required this.label,
    required this.rect,
    this.change = LivingChange.pulse,
    this.onArrive,
    this.line,
  });

  final String id, label;
  final Rect rect;
  final LivingChange change;
  final VoidCallback? onArrive;
  final String? line;
}

/// Where the companion stands in front of a spot (fractions).
Offset livingStandPoint(Rect rect) =>
    Offset(rect.center.dx, math.min(0.94, rect.bottom + 0.04));

/// Which walk cycle faces from [from] to [to].
CharacterAnimation livingWalkAnimation(Offset from, Offset to) {
  final d = to - from;
  if (d.dx.abs() >= d.dy.abs()) {
    return d.dx < 0
        ? CharacterAnimation.walkLeft
        : CharacterAnimation.walkRight;
  }
  return d.dy < 0 ? CharacterAnimation.walkUp : CharacterAnimation.walkDown;
}

/// Walk time for a distance in logical pixels; zero when motion is reduced.
Duration livingWalkDuration(double pixels, {required bool reduced}) {
  if (reduced) return Duration.zero;
  return Duration(milliseconds: (pixels * 4.5).clamp(280, 1300).round());
}

/// Banner height for a width: the art's own shape when [aspect] is known.
double livingBannerHeight(double width, double? aspect, double fallback) =>
    aspect == null ? fallback : (width / aspect).clamp(160.0, 340.0);

/// #200: a living version of the social/community stages. The companion walks
/// to a tapped spot, the spot changes, then the page's existing feature opens.
/// Kept in its own folder; 建議收進共用元件.
class LivingSceneBanner extends StatefulWidget {
  const LivingSceneBanner({
    super.key,
    required this.art,
    required this.title,
    required this.spots,
    this.npc,
    this.npcLine,
    this.npcAt = const Offset(0.16, 0.86),
    this.home = const Offset(0.5, 0.86),
    this.height = 220,
    this.aspect,
    this.objects = const [],
    this.night = false,
  });

  final String art, title;
  final List<LivingSpot> spots;
  final GameCharacter? npc;
  final String? npcLine;
  final Offset npcAt, home;
  final double height;

  /// Art width / height. When set, the banner keeps the art's shape (within
  /// 160–340 px) so spots stay on the drawn objects.
  final double? aspect;
  final List<Widget> objects;
  final bool night;

  @override
  State<LivingSceneBanner> createState() => LivingSceneBannerState();
}

class LivingSceneBannerState extends State<LivingSceneBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  late Offset _at = widget.home;
  CharacterAnimation _pose = CharacterAnimation.idle;
  Duration _walk = Duration.zero;
  String? _changed;
  String? _going;
  VoidCallback? _arrive;
  Timer? _settle;
  bool _motion = false, _foreground = true;

  bool get _reduced => !_motion;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_motion && _foreground) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settle?.cancel();
    _clock.dispose();
    super.dispose();
  }

  /// Walk to [spot], change it, then run its action.
  void use(LivingSpot spot, Size box) {
    if (_going != null) return;
    final target = livingStandPoint(spot.rect);
    final pixels = Offset(
      (target.dx - _at.dx) * box.width,
      (target.dy - _at.dy) * box.height,
    ).distance;
    setState(() {
      _going = spot.id;
      _pose = livingWalkAnimation(_at, target);
      _walk = livingWalkDuration(pixels, reduced: _reduced);
      _at = target;
      _arrive = () => _reach(spot);
    });
    if (_walk == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _arrived());
    }
  }

  void _arrived() {
    final arrive = _arrive;
    _arrive = null;
    arrive?.call();
  }

  void _reach(LivingSpot spot) {
    if (!mounted) return;
    setState(() {
      _pose = CharacterAnimation.happy;
      _changed = spot.id;
    });
    _settle?.cancel();
    _settle = Timer(Duration(milliseconds: _reduced ? 0 : 420), () {
      if (!mounted) return;
      setState(() {
        _going = null;
        _pose = CharacterAnimation.idle;
      });
      if (spot.onArrive != null) {
        spot.onArrive!();
      } else if (spot.line != null) {
        NpcDialog.show(
          context,
          speaker: widget.npc ?? GameCharacters.letty,
          lines: [spot.line!],
        );
      }
      Timer(const Duration(milliseconds: 900), () {
        if (mounted && _changed == spot.id) setState(() => _changed = null);
      });
    });
  }

  Widget _changeOf(LivingSpot spot, Widget child) {
    final on = _changed == spot.id;
    final ms = Duration(milliseconds: _reduced ? 0 : 260);
    return switch (spot.change) {
      LivingChange.open || LivingChange.rise => AnimatedSlide(
        offset: on ? const Offset(0, -0.08) : Offset.zero,
        duration: ms,
        child: child,
      ),
      LivingChange.shake => AnimatedRotation(
        turns: on ? 0.015 : 0,
        duration: ms,
        child: child,
      ),
      _ => AnimatedScale(scale: on ? 1.08 : 1, duration: ms, child: child),
    };
  }

  Widget _spot(LivingSpot spot, Size box) {
    final on = _changed == spot.id;
    final glow = switch (spot.change) {
      LivingChange.lit => GamePalette.gold,
      LivingChange.flutter => const Color(0xFFF7A8C4),
      _ => GamePalette.gold.withValues(alpha: 0.8),
    };
    return Positioned(
      left: spot.rect.left * box.width,
      top: spot.rect.top * box.height,
      width: spot.rect.width * box.width,
      height: spot.rect.height * box.height,
      child: Semantics(
        button: true,
        label: spot.label,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('living-spot-${spot.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => use(spot, box),
          child: _changeOf(
            spot,
            AnimatedContainer(
              duration: Duration(milliseconds: _reduced ? 0 : 220),
              decoration: BoxDecoration(
                border: Border.all(
                  color: on ? glow : glow.withValues(alpha: 0.0),
                  width: 2,
                ),
                color: on ? glow.withValues(alpha: 0.22) : Colors.transparent,
              ),
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _tag(spot.label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: GamePalette.dark.backgroundTop.withValues(alpha: 0.86),
      border: Border.all(color: GamePalette.gold.withValues(alpha: 0.7)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: GamePalette.gold,
          fontFamily: 'Cubic11',
          fontSize: 11,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final box = Size(
              c.maxWidth,
              livingBannerHeight(c.maxWidth, widget.aspect, widget.height),
            );
            return SizedBox(
              height: box.height,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        widget.art,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                        excludeFromSemantics: true,
                      ),
                    ),
                    if (widget.night)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: const Color(
                              0xFF2B2150,
                            ).withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _clock,
                          builder: (context, _) => CustomPaint(
                            painter: _MotesPainter(_clock.value, widget.night),
                          ),
                        ),
                      ),
                    ),
                    for (final spot in widget.spots) _spot(spot, box),
                    if (widget.npc != null)
                      Positioned(
                        left: widget.npcAt.dx * box.width - size / 2,
                        top: widget.npcAt.dy * box.height - size,
                        child: Semantics(
                          button: true,
                          label: '和${widget.npc!.name}說話',
                          child: GestureDetector(
                            onTap: () => NpcDialog.show(
                              context,
                              speaker: widget.npc!,
                              lines: [widget.npcLine ?? '歡迎來到${widget.title}。'],
                            ),
                            child: CharacterSprite(
                              character: widget.npc!,
                              size: size,
                              playing: _motion && _foreground,
                            ),
                          ),
                        ),
                      ),
                    AnimatedPositioned(
                      key: const ValueKey('living-companion'),
                      duration: _walk,
                      curve: Curves.linear,
                      left: _at.dx * box.width - size / 2,
                      top: _at.dy * box.height - size,
                      onEnd: () => WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _arrived(),
                      ),
                      child: IgnorePointer(
                        child: CharacterSprite(
                          character: GameCharacters.companion,
                          animation: _pose,
                          size: size,
                          playing: _motion && _foreground,
                          semanticLabel: '你的夥伴',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GamePalette.dark.backgroundTop,
                          border: Border.all(color: GamePalette.gold, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: GamePalette.gold,
                              fontFamily: 'Cubic11',
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.objects.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: widget.objects,
            ),
          ),
      ],
    );
  }
}

/// Drifting petals by day, fireflies by night; pixel squares only.
class _MotesPainter extends CustomPainter {
  _MotesPainter(this.t, this.night);
  final double t;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 9; i++) {
      final seed = (i * 97 % 41) / 41;
      final phase = (t + seed) % 1;
      final x = ((seed * 1.7 + phase * 0.35) % 1) * size.width;
      final y = night
          ? (0.25 +
                    0.5 * seed +
                    math.sin((phase + seed) * math.pi * 2) * 0.04) *
                size.height
          : phase * size.height;
      final a = night
          ? (0.4 + 0.6 * (math.sin(phase * math.pi * 2) + 1) / 2)
          : 0.75;
      paint.color = (night ? const Color(0xFFFFE08A) : const Color(0xFFF7B8CF))
          .withValues(alpha: a);
      canvas.drawRect(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), 3, 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) => old.t != t || old.night != night;
}
