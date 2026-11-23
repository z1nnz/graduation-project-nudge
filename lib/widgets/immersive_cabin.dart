import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/avatar_profile.dart';
import '../models/cabin_companion_brain.dart';
import '../models/cabin_layout.dart';
import '../models/cabin_presentation.dart';
import '../models/companion_pose.dart';
import 'companion_cabin_view.dart';
import 'companion_sprite.dart';
import 'cabin_tour.dart';
import '../models/companion_celebration.dart';
import 'celebration_overlay.dart';

/// Pixel font for in-world text (HUD, signs, bubbles).
const pixelFont = 'Cubic11';

/// Where the 9:16 cabin sits on a taller phone screen: full width,
/// vertically centred; wood tones extend above and below.
Rect cabinBoxFor(Size screen, double aspect) {
  final width = screen.width;
  final height = width / aspect;
  if (height <= screen.height) {
    return Rect.fromLTWH(0, (screen.height - height) / 2, width, height);
  }
  final h = screen.height;
  final w = h * aspect;
  return Rect.fromLTWH((screen.width - w) / 2, 0, w, h);
}

Rect _inBox(Rect box, CabinRect r) => Rect.fromLTWH(
  box.left + r.left * box.width,
  box.top + r.top * box.height,
  r.width * box.width,
  r.height * box.height,
);

/// Full-screen cabin: the backdrop shared by the home and desk-focus modes.
class CabinStage extends StatelessWidget {
  const CabinStage({
    super.key,
    required this.layout,
    required this.presentation,
    required this.builder,
  });

  final CabinLayout layout;
  final CabinPresentation presentation;

  /// Builds everything that sits in or over the room, given the cabin box.
  final List<Widget> Function(BuildContext context, Rect box) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = cabinBoxFor(constraints.biggest, layout.aspect);
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B2418), Color(0xFF4A2D22), Color(0xFF6D4527)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: box,
                child: CabinRoom(layout: layout, presentation: presentation),
              ),
              ...builder(context, box),
            ],
          ),
        );
      },
    );
  }
}

/// A room object you can tap. At rest it only glows softly; while pressed a
/// wooden sign names it.
class CabinHotspot extends StatefulWidget {
  const CabinHotspot({
    super.key,
    required this.label,
    required this.onTap,
    this.glow,
  });

  final String label;
  final VoidCallback onTap;

  /// Shared pulse (0..1); null shows a static glow.
  final Animation<double>? glow;

  @override
  State<CabinHotspot> createState() => _CabinHotspotState();
}

class _CabinHotspotState extends State<CabinHotspot> {
  bool _pressed = false;
  Timer? _release;

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glow;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) {
          _release?.cancel();
          _release = Timer(
            const Duration(milliseconds: 160),
            () => mounted ? _press(false) : null,
          );
        },
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: glow == null
                    ? const _Glow(t: 0.5)
                    : AnimatedBuilder(
                        animation: glow,
                        builder: (_, _) => _Glow(t: glow.value),
                      ),
              ),
            ),
            Positioned(
              top: -30,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: _pressed ? 1 : 0.6,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _pressed ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: _pressed
                        ? _WoodSign(text: widget.label)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft golden rim light around a room object.
class _Glow extends StatelessWidget {
  const _Glow({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFCF5A).withValues(alpha: 0.10 + 0.18 * t),
            blurRadius: 10 + 8 * t,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
}

class _WoodSign extends StatelessWidget {
  const _WoodSign({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB98552), Color(0xFF8A5A34)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4A2D22), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: pixelFont,
          color: Color(0xFFFFF3D6),
          fontSize: 16,
          shadows: [Shadow(color: Color(0xFF3B2418), offset: Offset(1, 1))],
        ),
      ),
    );
  }
}

/// Wooden HUD plate.
class _Plate extends StatelessWidget {
  const _Plate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 3, 10, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A34), Color(0xFF5A3826)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC9934F), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 3)),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: pixelFont,
          color: Color(0xFFFFF3D6),
          fontSize: 17,
        ),
        child: child,
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8A5A34), Color(0xFF5A3826)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC9934F), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: const Color(0xFFFFE6A3), size: 22),
        ),
      ),
    );
  }
}

/// Level badge with an experience ring.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              backgroundColor: const Color(0x66000000),
              color: const Color(0xFF7CF7C4),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD76A), Color(0xFFFF8F3A)],
              ),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF8A4A10), width: 2),
            ),
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: pixelFont,
                color: Color(0xFF3A1D00),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Speech bubble that pops in and types its line out.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.instant});

  final String text;
  final bool instant;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: instant ? 0 : 220),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Container(
        key: ValueKey(text),
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.fromLTRB(11, 5, 11, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A5A34), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
          ],
        ),
        child: instant
            ? _bubbleText(text)
            : TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: text.characters.length),
                duration: Duration(milliseconds: 45 * text.characters.length),
                builder: (_, shown, _) =>
                    _bubbleText(text.characters.take(shown).toString()),
              ),
      ),
    );
  }

  static Widget _bubbleText(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamily: pixelFont,
      color: Color(0xFF3A1D0C),
      fontSize: 16,
    ),
  );
}

class _Dust {
  _Dust(this.at, this.drift);

  final Offset at;
  final double drift;
  double age = 0;
}

/// The home screen: the whole cabin, a companion who lives in it, and room
/// objects as the menu. No cards, no tab bar.
class ImmersiveHome extends StatefulWidget {
  const ImmersiveHome({
    super.key,
    required this.layout,
    required this.presentation,
    required this.profile,
    required this.level,
    required this.coins,
    required this.streak,
    required this.onOpenQuests,
    required this.onOpenDesk,
    required this.onOpenRecords,
    required this.onOpenBadges,
    required this.onOpenCompanions,
    required this.onOpenRooms,
    required this.onOpenCharacter,
    required this.onOpenDecor,
    required this.onOpenMenu,
    required this.onOpenShop,
    required this.onOpenDevice,
    this.showTour = false,
    this.accountKey,
    this.socialUnread = 0,
    this.onTourDone,
    this.levelProgress = 0,
    this.confirmedActivityLabel,
    this.now,
  });

  final CabinLayout layout;
  final CabinPresentation presentation;
  final AvatarProfile profile;
  final int level;
  final double levelProgress;
  final int coins;
  final int streak;
  final VoidCallback onOpenQuests;
  final VoidCallback onOpenDesk;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenBadges;
  final VoidCallback onOpenCompanions;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenCharacter;
  final VoidCallback onOpenDecor;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenDevice;

  /// Show the first-visit tour; [onTourDone] runs when it is finished or
  /// skipped so the caller can remember it.
  final bool showTour;

  /// Who is signed in; level and stage changes only celebrate within one
  /// account, never when switching to another one.
  final String? accountKey;

  /// Unread notifications (invites, encouragement); lights the social slot.
  final int socialUnread;
  final VoidCallback? onTourDone;
  final String? confirmedActivityLabel;
  final DateTime? now;

  @override
  State<ImmersiveHome> createState() => _ImmersiveHomeState();
}

class _ImmersiveHomeState extends State<ImmersiveHome>
    with TickerProviderStateMixin {
  static const _pokeLines = [
    '嘿嘿，被你發現了！',
    '今天也一起加油！',
    '做一件小事就很棒了',
    '我會陪著你的～',
    '要不要去書桌前坐一下？',
  ];

  late final CabinCompanionBrain _brain = CabinCompanionBrain();
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final List<_Dust> _dust = [];
  final _random = math.Random();
  Duration _last = Duration.zero;
  double _dustClock = 0;
  String? _pokeLine;
  int _pokeCount = 0;
  bool _still = false;
  late bool _touring = widget.showTour;
  CompanionCelebration? _celebration;
  final _questKey = GlobalKey();
  final _companionKey = GlobalKey();
  final _focusKey = GlobalKey();
  final _roomsKey = GlobalKey();
  final _menuKey = GlobalKey();

  void _endTour() {
    setState(() => _touring = false);
    widget.onTourDone?.call();
  }

  bool get _night {
    final hour = (widget.now ?? DateTime.now()).hour;
    return hour >= 22 || hour < 6;
  }

  static const _deviceLine = '桌上的我也在專注，一起加油！';

  /// The desk device focusing wins over the night: the cabin companion keeps
  /// the device company at the desk.
  CompanionActivity get _wantedActivity => widget.presentation.globeGlowing
      ? CompanionActivity.focus
      : _night
      ? CompanionActivity.rest
      : CompanionActivity.wander;

  @override
  void initState() {
    super.initState();
    _brain.setActivity(_wantedActivity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _pulse
        ..stop()
        ..value = 0.5;
    } else {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ImmersiveHome old) {
    super.didUpdateWidget(old);
    final grew = CompanionCelebration.between(
      oldLevel: old.level,
      newLevel: widget.level,
      oldStageIndex: old.profile.faceShapeIndex,
      newStageIndex: widget.profile.faceShapeIndex,
    );
    if (grew != null && old.accountKey == widget.accountKey) {
      _celebration = grew;
    }
    _brain.setActivity(_wantedActivity);
    final before = old.confirmedActivityLabel;
    final after = widget.confirmedActivityLabel;
    if (before != null && after != null && before != after) {
      _brain.poke();
      _pokeLine = '$after！';
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    setState(() {
      final step = math.min(dt, 0.05);
      // The companion stands still while the tour points at things.
      if (!_touring) _brain.tick(step);
      for (final d in _dust) {
        d.age += step;
      }
      _dust.removeWhere((d) => d.age > 0.6);
      if (_brain.pose == CompanionPose.walk) {
        _dustClock += step;
        if (_dustClock > 0.18) {
          _dustClock = 0;
          _dust.add(_Dust(_brain.position, _random.nextDouble() - 0.5));
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onFloorTap(TapUpDetails details, Rect box) {
    final p = details.localPosition;
    final normalized = Offset(
      (p.dx - box.left) / box.width,
      (p.dy - box.top) / box.height,
    );
    if (_brain.walkTo(normalized)) {
      _pokeLine = null;
      if (_still) {
        // No walking animation: the companion appears at the spot.
        for (var i = 0; i < 400 && _brain.pose == CompanionPose.walk; i++) {
          _brain.tick(0.05);
        }
        setState(() {});
      }
    }
  }

  void _onPoke() {
    setState(() {
      _brain.poke();
      _pokeLine = _pokeLines[_pokeCount++ % _pokeLines.length];
    });
  }

  Widget _hotspot(
    Rect box,
    CabinRect rect,
    String key,
    String label,
    VoidCallback onTap, {
    GlobalKey? tourKey,
  }) {
    return Positioned.fromRect(
      rect: _inBox(box, rect),
      child: KeyedSubtree(
        key: tourKey,
        child: CabinHotspot(
          key: Key(key),
          label: label,
          onTap: onTap,
          glow: _still ? null : _pulse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Scaffold(
      body: CabinStage(
        layout: layout,
        presentation: widget.presentation,
        builder: (context, box) {
          final charHeight = layout.character.height * box.height;
          Offset toScreen(Offset p) =>
              Offset(box.left + p.dx * box.width, box.top + p.dy * box.height);
          final feet = toScreen(_brain.position);
          final bubble =
              _pokeLine ??
              (widget.presentation.globeGlowing
                  ? _deviceLine
                  : _brain.activity == CompanionActivity.rest
                  ? '呼……晚安'
                  : widget.presentation.bubbleText);
          return [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _onFloorTap(d, box),
              ),
            ),
            _hotspot(
              box,
              layout.questBoard,
              'cabin-quest-board',
              '委託 ${widget.presentation.questCount}',
              widget.onOpenQuests,
              tourKey: _questKey,
            ),
            _hotspot(
              box,
              const CabinRect(0.39, 0.45, 0.45, 0.14),
              'cabin-desk',
              '書桌・專注',
              widget.onOpenDesk,
            ),
            _hotspot(
              box,
              const CabinRect(0.11, 0.28, 0.24, 0.29),
              'cabin-shelf',
              '冒險日誌',
              widget.onOpenRecords,
            ),
            _hotspot(
              box,
              const CabinRect(0.67, 0.3, 0.2, 0.08),
              'cabin-badges',
              '徽章',
              widget.onOpenBadges,
            ),
            if (widget.presentation.showGlobe)
              if (layout.layers['globe'] case final globe?)
                _hotspot(
                  box,
                  globe.rect,
                  'cabin-globe',
                  widget.presentation.globeGlowing ? '裝置・專注中' : '裝置',
                  widget.onOpenDevice,
                ),
            if (layout.doors['family'] case final r?)
              _hotspot(
                box,
                r,
                'cabin-door-family',
                '社交',
                widget.onOpenCompanions,
              ),
            if (layout.doors['group'] case final r?)
              _hotspot(box, r, 'cabin-door-group', '自律房', widget.onOpenRooms),
            for (final d in _dust)
              Positioned(
                key: ObjectKey(d),
                left: toScreen(d.at).dx - 5 + d.drift * 24 * d.age,
                top: toScreen(d.at).dy - 8 - 14 * d.age,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - d.age / 0.6).clamp(0, 1) * 0.7,
                    child: Container(
                      key: const Key('cabin-dust'),
                      width: 8 + 10 * d.age,
                      height: 8 + 10 * d.age,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8D5B5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: feet.dx - charHeight / 2,
              top: feet.dy - charHeight,
              width: charHeight,
              height: charHeight,
              child: Semantics(
                button: true,
                label: '你的夥伴，點一下打招呼，長按開啟角色',
                child: GestureDetector(
                  key: const Key('cabin-companion'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _onPoke,
                  onLongPress: widget.onOpenCharacter,
                  child: KeyedSubtree(
                    key: _companionKey,
                    child: CompanionSprite(
                      profile: widget.profile,
                      pose: _brain.pose,
                      size: charHeight,
                      facingLeft: _brain.facingLeft,
                      stepPhase: _brain.stepPhase,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: feet.dy - charHeight - 36,
              child: IgnorePointer(
                child: Center(
                  child: _SpeechBubble(text: bubble, instant: _still),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 10,
              child: Row(
                children: [
                  _LevelBadge(
                    level: widget.level,
                    progress: widget.levelProgress,
                  ),
                  const SizedBox(width: 6),
                  _Plate(
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(end: widget.coins),
                      duration: Duration(milliseconds: _still ? 0 : 700),
                      builder: (_, value, _) => Text('◎ $value'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Plate(
                    child: _still
                        ? Text('🔥 ${widget.streak}')
                        : AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, child) => Transform.scale(
                              scale: 1 + 0.06 * _pulse.value,
                              child: child,
                            ),
                            child: Text('🔥 ${widget.streak}'),
                          ),
                  ),
                  const Spacer(),
                  _HudButton(
                    key: const Key('cabin-decor'),
                    icon: Icons.chair_outlined,
                    label: '家具',
                    onTap: widget.onOpenDecor,
                  ),
                  const SizedBox(width: 6),
                  KeyedSubtree(
                    key: _menuKey,
                    child: _HudButton(
                      key: const Key('cabin-menu'),
                      icon: Icons.menu_rounded,
                      label: '選單',
                      onTap: widget.onOpenMenu,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
              child: _Hotbar(
                questCount: widget.presentation.questCount,
                glow: _still ? null : _pulse,
                onOpenQuests: widget.onOpenQuests,
                onOpenRooms: widget.onOpenRooms,
                onOpenFocus: widget.onOpenDesk,
                onOpenSocial: widget.onOpenCompanions,
                onOpenShop: widget.onOpenShop,
                socialUnread: widget.socialUnread,
                focusKey: _focusKey,
                roomsKey: _roomsKey,
              ),
            ),
            if (_celebration case final c?)
              Positioned.fill(
                child: CelebrationOverlay(
                  key: const Key('cabin-celebration'),
                  celebration: c,
                  profile: widget.profile,
                  onDone: () => setState(() => _celebration = null),
                ),
              ),
            if (_touring)
              Positioned.fill(
                child: CabinTour(
                  steps: [
                    CabinTourStep(
                      '嗨！我是你的夥伴，以後就住在這間小屋。點我會打招呼，點地板我會走過去喔。',
                      target: _companionKey,
                    ),
                    CabinTourStep(
                      '這是委託板。今天要做的事都貼在這裡，完成會蓋上「達成」章。',
                      target: _questKey,
                    ),
                    CabinTourStep('按「專注」就會到書桌前，我會陪你一起讀書。', target: _focusKey),
                    CabinTourStep('自律房裡有一起專注的夥伴，人越多房間越亮。', target: _roomsKey),
                    CabinTourStep('日曆、健康、設定這些功能都收在選單裡。', target: _menuKey),
                    const CabinTourStep(
                      '專注完成、經雲端確認後就能拿到金幣，用來布置我們的小屋！要不要現在就來第一次專注？',
                    ),
                  ],
                  onSkip: _endTour,
                  onStart: () {
                    _endTour();
                    widget.onOpenDesk();
                  },
                ),
              ),
          ];
        },
      ),
    );
  }
}

/// Game-style hotbar along the bottom: the five main features, with focus
/// as the big glowing centre slot. Room objects open the same pages.
class _Hotbar extends StatelessWidget {
  const _Hotbar({
    required this.questCount,
    required this.glow,
    required this.onOpenQuests,
    required this.onOpenRooms,
    required this.onOpenFocus,
    required this.onOpenSocial,
    required this.onOpenShop,
    this.focusKey,
    this.roomsKey,
    this.socialUnread = 0,
  });

  final GlobalKey? focusKey;
  final GlobalKey? roomsKey;
  final int socialUnread;
  final int questCount;
  final Animation<double>? glow;
  final VoidCallback onOpenQuests;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenFocus;
  final VoidCallback onOpenSocial;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 86,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xEE8A5A34), Color(0xEE4A2D1E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9934F), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HotbarSlot(
                key: const Key('hotbar-quests'),
                label: '委託',
                icon: 'assets/ui/icons/icon_quest.png',
                fallback: Icons.receipt_long,
                count: questCount,
                onTap: onOpenQuests,
              ),
              _HotbarSlot(
                key: const Key('hotbar-rooms'),
                tourKey: roomsKey,
                label: '自律房',
                icon: 'assets/ui/icons/icon_room.png',
                fallback: Icons.groups,
                onTap: onOpenRooms,
              ),
              _HotbarSlot(
                key: const Key('hotbar-focus'),
                tourKey: focusKey,
                label: '專注',
                icon: 'assets/ui/icons/icon_focus.png',
                fallback: Icons.hourglass_bottom,
                big: true,
                glow: glow,
                onTap: onOpenFocus,
              ),
              _HotbarSlot(
                key: const Key('hotbar-social'),
                label: '社交',
                dot: socialUnread > 0,
                icon: 'assets/ui/icons/icon_social.png',
                fallback: Icons.favorite,
                onTap: onOpenSocial,
              ),
              _HotbarSlot(
                key: const Key('hotbar-shop'),
                label: '商城',
                icon: 'assets/ui/icons/icon_shop.png',
                fallback: Icons.storefront,
                onTap: onOpenShop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HotbarSlot extends StatelessWidget {
  const _HotbarSlot({
    super.key,
    required this.label,
    required this.icon,
    required this.fallback,
    required this.onTap,
    this.count = 0,
    this.big = false,
    this.glow,
    this.tourKey,
    this.dot = false,
  });

  final GlobalKey? tourKey;

  /// A plain red dot: something new waits behind this slot.
  final bool dot;

  final String label;
  final String icon;
  final IconData fallback;
  final VoidCallback onTap;
  final int count;
  final bool big;
  final Animation<double>? glow;

  /// The focus slot: a round gold medallion with a violet ribbon, rising
  /// above the bar and glowing softly.
  Widget _focusMedallion(BuildContext context) {
    Widget medal = Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFFE6A3),
            Color(0xFFE0A84A),
            Color(0xFFFFF3C4),
            Color(0xFFC4710B),
            Color(0xFFFFE6A3),
          ],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFF4A2410), width: 3),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFFF6D0), Color(0xFFFFC54D), Color(0xFFE07A1F)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: const Color(0xFFFFF3C4), width: 2),
        ),
        padding: const EdgeInsets.all(9),
        child: Image.asset(
          icon,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) =>
              Icon(fallback, size: 40, color: const Color(0xFF8A4A10)),
        ),
      ),
    );
    if (glow case final g?) {
      medal = AnimatedBuilder(
        animation: g,
        child: medal,
        builder: (_, child) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(255, 200, 90, 0.35 + 0.4 * g.value),
                blurRadius: 12 + 12 * g.value,
                spreadRadius: 1 + 3 * g.value,
              ),
            ],
          ),
          child: child,
        ),
      );
    }
    return Expanded(
      flex: 6,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: KeyedSubtree(
            key: tourKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                medal,
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9C7BEF), Color(0xFF6A4FC8)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2E1A5C),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: pixelFont,
                        fontSize: 18,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0xFF2E1A5C),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (big) return _focusMedallion(context);
    const size = 36.0;
    Widget face = Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: big
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE6A3), Color(0xFFE0A84A)],
              )
            : null,
        color: big ? null : const Color(0xFFF6E7C8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: big ? const Color(0xFF8A4A10) : const Color(0xFF4A2D22),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              icon,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) => Icon(
                fallback,
                size: size * 0.8,
                color: const Color(0xFF8A5A34),
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: pixelFont,
              fontSize: 15,
              color: const Color(0xFF3A1D0C),
            ),
          ),
        ],
      ),
    );
    if (glow case final g?) {
      face = AnimatedBuilder(
        animation: g,
        child: face,
        builder: (_, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(255, 210, 110, 0.25 + 0.35 * g.value),
                blurRadius: 10 + 8 * g.value,
              ),
            ],
          ),
          child: child,
        ),
      );
    }
    return Expanded(
      flex: big ? 6 : 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: count > 0
              ? '$label，$count 件未完成'
              : dot
              ? '$label，有新消息'
              : label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                KeyedSubtree(key: tourKey, child: face),
                if (dot && count == 0)
                  Positioned(
                    key: Key(
                      '${(key as ValueKey<String>?)?.value ?? 'hotbar'}-dot',
                    ),
                    top: -4,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8452E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFF3D6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (count > 0)
                  Positioned(
                    top: -6,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8452E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFF3D6),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontFamily: pixelFont,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
