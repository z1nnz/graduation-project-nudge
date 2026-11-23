import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/avatar_profile.dart';
import '../models/companion_celebration.dart';
import '../models/companion_pose.dart';
import 'companion_sprite.dart';

const _font = 'Cubic11';

/// Full-screen show for a level-up or an evolution: turning light rays, a
/// white flash for evolutions, the companion cheering and a big banner.
/// Tap anywhere to continue.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.profile,
    required this.onDone,
  });

  final CompanionCelebration celebration;
  final AvatarProfile profile;
  final VoidCallback onDone;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _intro.value = 1;
      _rays.stop();
    } else {
      if (_intro.value == 0) _intro.forward();
      if (!_rays.isAnimating) _rays.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _rays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evolution = widget.celebration.kind == CelebrationKind.evolution;
    return Semantics(
      liveRegion: true,
      label: '${widget.celebration.title} ${widget.celebration.detail}，點一下繼續',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _rays]),
          builder: (context, _) {
            final t = _intro.value;
            final pop = Curves.easeOutBack.transform(
              ((t - 0.25) / 0.75).clamp(0.0, 1.0),
            );
            // Evolutions flash white in the first third.
            final flash = evolution
                ? (1 - (t * 3 - 1).abs()).clamp(0.0, 1.0)
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Color.fromRGBO(20, 10, 5, 0.85 * t.clamp(0, 1)),
                ),
                Opacity(
                  opacity: t,
                  child: CustomPaint(
                    painter: _RaysPainter(
                      _rays.value * 2 * math.pi,
                      evolution
                          ? const Color(0x66B79CFF)
                          : const Color(0x66FFD76A),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: evolution
                                  ? const [Color(0xFFD6C6FF), Color(0xFF8C6AE6)]
                                  : const [
                                      Color(0xFFFFD76A),
                                      Color(0xFFFF8F3A),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3A1D00),
                              width: 3,
                            ),
                          ),
                          child: Text(
                            widget.celebration.title,
                            style: const TextStyle(
                              fontFamily: _font,
                              fontSize: 40,
                              color: Color(0xFF2A1600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Transform.scale(
                        scale: 0.6 + 0.4 * pop,
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: CompanionSprite(
                            profile: widget.profile,
                            pose: CompanionPose.cheer,
                            size: 200,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: pop.clamp(0.0, 1.0),
                        child: Text(
                          widget.celebration.detail,
                          style: const TextStyle(
                            fontFamily: _font,
                            fontSize: 28,
                            color: Color(0xFFFFF3D6),
                            shadows: [
                              Shadow(color: Colors.black, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: t,
                        child: const Text(
                          '點一下繼續',
                          style: TextStyle(
                            fontFamily: _font,
                            fontSize: 14,
                            color: Color(0xCCFFE6A3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (flash > 0)
                  IgnorePointer(
                    child: ColoredBox(
                      color: Color.fromRGBO(255, 255, 255, flash * 0.9),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.angle, this.color);

  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    final paint = Paint()..color = color;
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = angle + i * 2 * math.pi / rays;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(a - 0.09),
          center.dy + radius * math.sin(a - 0.09),
        )
        ..lineTo(
          center.dx + radius * math.cos(a + 0.09),
          center.dy + radius * math.sin(a + 0.09),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.angle != angle || old.color != color;
}
