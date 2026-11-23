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

/// A glowing, tappable room object.
class CabinHotspot extends StatelessWidget {
  const CabinHotspot({
    super.key,
    required this.label,
    required this.onTap,
    this.showSpark = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool showSpark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: showSpark
            ? Align(
                alignment: Alignment.topCenter,
                child: _Spark(label: label),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFFFF7C2), Color(0xFFFFCF5A), Color(0x00FFCF5A)],
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB3201008),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x4DFFDCAA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
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
    return Material(
      color: const Color(0xB3201008),
      shape: const CircleBorder(side: BorderSide(color: Color(0x4DFFDCAA))),
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8A5A34), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF3A1D0C),
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
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
    required this.onOpenBackpack,
    this.confirmedActivityLabel,
    this.now,
  });

  final CabinLayout layout;
  final CabinPresentation presentation;
  final AvatarProfile profile;
  final int level;
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
  final VoidCallback onOpenBackpack;
  final String? confirmedActivityLabel;
  final DateTime? now;

  @override
  State<ImmersiveHome> createState() => _ImmersiveHomeState();
}

class _ImmersiveHomeState extends State<ImmersiveHome>
    with SingleTickerProviderStateMixin {
  static const _pokeLines = [
    '嘿嘿，被你發現了！',
    '今天也一起加油！',
    '做一件小事就很棒了',
    '我會陪著你的～',
    '要不要去書桌前坐一下？',
  ];

  late final CabinCompanionBrain _brain = CabinCompanionBrain();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  String? _pokeLine;
  int _pokeCount = 0;
  bool _still = false;

  bool get _night {
    final hour = (widget.now ?? DateTime.now()).hour;
    return hour >= 22 || hour < 6;
  }

  @override
  void initState() {
    super.initState();
    if (_night) _brain.setActivity(CompanionActivity.rest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(ImmersiveHome old) {
    super.didUpdateWidget(old);
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
    setState(() => _brain.tick(math.min(dt, 0.05)));
  }

  @override
  void dispose() {
    _ticker.dispose();
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
        for (var i = 0; i < 200 && _brain.pose == CompanionPose.walk; i++) {
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

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    return Scaffold(
      body: CabinStage(
        layout: layout,
        presentation: widget.presentation,
        builder: (context, box) {
          final charHeight = layout.character.height * box.height;
          final feet = Offset(
            box.left + _brain.position.dx * box.width,
            box.top + _brain.position.dy * box.height,
          );
          final bubble =
              _pokeLine ??
              (_brain.activity == CompanionActivity.rest
                  ? '呼……晚安'
                  : widget.presentation.bubbleText);
          return [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _onFloorTap(d, box),
              ),
            ),
            Positioned.fromRect(
              rect: _inBox(box, layout.questBoard),
              child: CabinHotspot(
                key: const Key('cabin-quest-board'),
                label: '委託 ${widget.presentation.questCount}',
                onTap: widget.onOpenQuests,
              ),
            ),
            Positioned.fromRect(
              rect: _inBox(box, const CabinRect(0.39, 0.45, 0.45, 0.14)),
              child: CabinHotspot(
                key: const Key('cabin-desk'),
                label: '書桌・專注',
                onTap: widget.onOpenDesk,
              ),
            ),
            Positioned.fromRect(
              rect: _inBox(box, const CabinRect(0.11, 0.28, 0.24, 0.29)),
              child: CabinHotspot(
                key: const Key('cabin-shelf'),
                label: '紀錄',
                onTap: widget.onOpenRecords,
              ),
            ),
            Positioned.fromRect(
              rect: _inBox(box, const CabinRect(0.67, 0.3, 0.2, 0.08)),
              child: CabinHotspot(
                key: const Key('cabin-badges'),
                label: '徽章',
                onTap: widget.onOpenBadges,
              ),
            ),
            if (layout.doors['family'] case final r?)
              Positioned.fromRect(
                rect: _inBox(box, r),
                child: CabinHotspot(
                  key: const Key('cabin-door-family'),
                  label: '同伴',
                  onTap: widget.onOpenCompanions,
                ),
              ),
            if (layout.doors['group'] case final r?)
              Positioned.fromRect(
                rect: _inBox(box, r),
                child: CabinHotspot(
                  key: const Key('cabin-door-group'),
                  label: '自律房',
                  onTap: widget.onOpenRooms,
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
            Positioned(
              left: 0,
              right: 0,
              top: feet.dy - charHeight - 34,
              child: IgnorePointer(
                child: Center(child: _SpeechBubble(text: bubble)),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.paddingOf(context).top + 10,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD76A), Color(0xFFFF8F3A)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${widget.level}',
                      style: const TextStyle(
                        color: Color(0xFF3A1D00),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HudChip(text: '◎ ${widget.coins}'),
                  const SizedBox(width: 6),
                  _HudChip(text: '🔥 ${widget.streak}'),
                  const Spacer(),
                  _HudButton(
                    key: const Key('cabin-decor'),
                    icon: Icons.chair_outlined,
                    label: '家具',
                    onTap: widget.onOpenDecor,
                  ),
                  const SizedBox(width: 6),
                  _HudButton(
                    key: const Key('cabin-backpack'),
                    icon: Icons.backpack_outlined,
                    label: '背包',
                    onTap: widget.onOpenBackpack,
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }
}
