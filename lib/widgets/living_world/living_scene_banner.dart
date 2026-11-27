import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    this.tallRect,
    this.change = LivingChange.pulse,
    this.onArrive,
    this.line,
    this.revealsBelow = false,
  });

  final String id, label;
  final Rect rect;

  /// The same object in the portrait art (fractions of that art).
  final Rect? tallRect;
  final LivingChange change;
  final VoidCallback? onArrive;
  final String? line;

  /// On phones the page content sits under the full-screen scene: scroll down
  /// to it after arriving (for spots whose feature opens below the scene).
  final bool revealsBelow;
}

/// Same rule as the Web rooms: landscape art only on big landscape screens.
bool livingUsesTall(Size screen) =>
    !(screen.width >= 860 && screen.width / math.max(1, screen.height) >= 1.05);

/// How much page content peeks under a full-screen phone scene.
const livingPeek = 72.0;

/// Where portrait art of [aspect] sits in a [box]: cover when the crop is
/// small, otherwise contain at the top (a blurred copy fills the rest).
Rect livingArtRect(Size box, double aspect) {
  final ratio = (box.width / box.height) / aspect;
  final cover = ratio >= 0.76 && ratio <= 1.19;
  final fitHeight = cover ? ratio < 1 : ratio > 1;
  final w = fitHeight ? box.height * aspect : box.width;
  final h = fitHeight ? box.height : box.width / aspect;
  return Rect.fromLTWH(
    (box.width - w) / 2,
    cover ? (box.height - h) / 2 : 0,
    w,
    h,
  );
}

/// A fraction rect of the art in box pixels, kept inside the box.
Rect livingPlace(Rect fraction, Rect art, Size box) {
  final drawn = Rect.fromLTRB(
    art.left + fraction.left * art.width,
    art.top + fraction.top * art.height,
    art.left + fraction.right * art.width,
    art.top + fraction.bottom * art.height,
  );
  // At least a 44 px tap target, grown around the drawn object.
  final r = Rect.fromCenter(
    center: drawn.center,
    width: math.max(44, drawn.width),
    height: math.max(44, drawn.height),
  );
  return Rect.fromLTRB(
    r.left.clamp(0, box.width - 44),
    r.top.clamp(0, box.height - 44),
    r.right.clamp(44, box.width),
    r.bottom.clamp(44, box.height),
  );
}

/// Phone scene height: the whole scroll viewport below the scene's top,
/// minus a strip where the page content peeks in.
double livingFullHeight(double viewport, double top) =>
    math.max(320, viewport - top - livingPeek);

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
    this.tallArt,
    this.tallAspect = 2 / 3,
    this.tallNpcAt = const Offset(0.82, 0.8),
    this.tallHome = const Offset(0.5, 0.78),
  });

  final String art, title;
  final List<LivingSpot> spots;
  final GameCharacter? npc;
  final String? npcLine;
  final Offset npcAt, home;
  final double height;

  /// Portrait art for phones. On a phone the banner fills its scroll
  /// viewport with it, as the Web rooms do; the page content follows below.
  final String? tallArt;
  final double tallAspect;
  final Offset tallNpcAt, tallHome;

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
  bool? _tall;
  double? _full, _sceneHeight;
  Size? _measuredFor;
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

  /// Walk to the spot, change it, then run its action.
  void _use(LivingSpot spot, _Geo geo) {
    if (_going != null) return;
    final target = livingStandPoint(geo.fraction(spot));
    final pixels = (geo.px(target) - geo.px(_at)).distance;
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
      if (spot.revealsBelow && _tall == true) _revealBelow();
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

  /// First-frame guess at the viewport: screen minus bars (and tabs).
  double _estimateFull(Size screen) {
    final pad = MediaQuery.paddingOf(context);
    final tabs = DefaultTabController.maybeOf(context) != null
        ? kTextTabBarHeight
        : 0.0;
    return livingFullHeight(
      screen.height - pad.vertical - kToolbarHeight - tabs,
      16,
    );
  }

  /// Exact height once laid out: the real viewport and our offset in it.
  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (box == null || position == null || !position.hasViewportDimension) {
      return;
    }
    final top = RenderAbstractViewport.maybeOf(
      box,
    )?.getOffsetToReveal(box, 0).offset;
    if (top == null) return;
    final full = livingFullHeight(position.viewportDimension, top);
    if (_full == null || (full - _full!).abs() > 1) {
      setState(() => _full = full);
    }
  }

  /// Phone layout: scroll the page so the content under the scene shows.
  void _revealBelow() {
    final position = Scrollable.maybeOf(context)?.position;
    final box = context.findRenderObject();
    final scene = _sceneHeight;
    if (position == null || box == null || scene == null) return;
    final top =
        RenderAbstractViewport.maybeOf(box)?.getOffsetToReveal(box, 0).offset ??
        0;
    final to = math.min(position.maxScrollExtent, top + scene - 8);
    if (to <= position.pixels) return;
    if (_reduced) {
      position.jumpTo(to);
    } else {
      position.animateTo(
        to,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
      );
    }
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

  Widget _spot(LivingSpot spot, _Geo geo) {
    final on = _changed == spot.id;
    final glow = switch (spot.change) {
      LivingChange.lit => GamePalette.gold,
      LivingChange.flutter => const Color(0xFFF7A8C4),
      _ => GamePalette.gold.withValues(alpha: 0.8),
    };
    return Positioned.fromRect(
      rect: geo.rect(spot),
      child: Semantics(
        button: true,
        label: spot.label,
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('living-spot-${spot.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _use(spot, geo),
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
            final screen = MediaQuery.sizeOf(context);
            final tall = widget.tallArt != null && livingUsesTall(screen);
            final fullHeight = tall ? _full ?? _estimateFull(screen) : null;
            if (tall && _measuredFor != screen) {
              _measuredFor = screen;
              WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
            }
            if (_tall != null && _tall != tall && _going == null) {
              _at = tall ? widget.tallHome : widget.home;
            }
            if (_tall == null && tall) _at = widget.tallHome;
            _tall = tall;
            final box = Size(
              c.maxWidth,
              tall
                  ? fullHeight!
                  : livingBannerHeight(
                      c.maxWidth,
                      widget.aspect,
                      widget.height,
                    ),
            );
            _sceneHeight = box.height;
            final geo = _Geo(
              box,
              tall ? livingArtRect(box, widget.tallAspect) : Offset.zero & box,
              tall,
            );
            final npcAt = geo.px(tall ? widget.tallNpcAt : widget.npcAt);
            final at = geo.px(_at);
            final art = tall ? widget.tallArt! : widget.art;
            return SizedBox(
              key: ValueKey(tall ? 'living-scene-tall' : 'living-scene-wide'),
              height: box.height,
              child: ClipRect(
                child: Stack(
                  children: [
                    if (tall)
                      Positioned.fill(
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 14,
                            sigmaY: 14,
                          ),
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0x8C000000),
                              BlendMode.darken,
                            ),
                            child: Image.asset(
                              art,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fromRect(
                      rect: geo.art,
                      child: Image.asset(
                        art,
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
                    for (final spot in widget.spots) _spot(spot, geo),
                    if (widget.npc != null)
                      Positioned(
                        left: npcAt.dx - size / 2,
                        top: npcAt.dy - size,
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
                      left: at.dx - size / 2,
                      top: at.dy - size,
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
                    if (tall)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: '往下看更多',
                            excludeSemantics: true,
                            child: GestureDetector(
                              key: const ValueKey('living-more'),
                              onTap: _revealBelow,
                              child: _tag('▼ 往下看更多'),
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

/// One layout of the banner: the box, where the art sits in it, and how
/// art fractions map to pixels.
class _Geo {
  const _Geo(this.box, this.art, this.tall);
  final Size box;
  final Rect art;
  final bool tall;

  Rect fraction(LivingSpot spot) =>
      tall ? (spot.tallRect ?? spot.rect) : spot.rect;
  Rect rect(LivingSpot spot) => livingPlace(fraction(spot), art, box);
  Offset px(Offset f) => Offset(
    (art.left + f.dx * art.width).clamp(28, math.max(28, box.width - 28)),
    (art.top + f.dy * art.height).clamp(56, box.height),
  );
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
