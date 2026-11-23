import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/avatar_profile.dart';
import '../models/companion_pose.dart';
import 'avatar_preview.dart';

/// The companion character doing an activity. First-stage characters use
/// generated pose art; other stages use their base sprite with code-drawn
/// motion and a small effect (book glints, Zzz, sweat, stars). Reduced
/// motion shows the still pose.
class CompanionSprite extends StatefulWidget {
  const CompanionSprite({
    super.key,
    required this.profile,
    required this.pose,
    required this.size,
    this.facingLeft = false,
    this.stepPhase = 0,
  });

  final AvatarProfile profile;
  final CompanionPose pose;
  final double size;

  /// Mirror the sprite while walking left.
  final bool facingLeft;

  /// 0..1 walk-cycle phase from the caller; picks the step frame.
  final double stepPhase;

  @override
  State<CompanionSprite> createState() => _CompanionSpriteState();
}

class _CompanionSpriteState extends State<CompanionSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _loop
        ..stop()
        ..value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Body motion per pose as (dx, dy, scaleY) for animation phase t in 0..1.
  (double, double, double) _motion(double t) {
    final wave = math.sin(t * 2 * math.pi);
    switch (widget.pose) {
      case CompanionPose.idle:
        return (0, -2 * wave.abs(), 1);
      case CompanionPose.walk:
        final step = math.sin(widget.stepPhase * 2 * math.pi);
        return (0, -4 * step.abs(), 1 - 0.02 * step.abs());
      case CompanionPose.read:
        return (0, -1.5 * wave, 1);
      case CompanionPose.sleep:
        return (0, 0, 1 + 0.025 * wave);
      case CompanionPose.exercise:
        return (0, -6 * wave.abs(), 1 - 0.03 * wave.abs());
      case CompanionPose.cheer:
        return (0, -14 * wave.abs(), 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final poseAsset = widget.pose.assetFor(widget.profile.faceShapeIndex);
    final walkFrames = widget.pose == CompanionPose.walk
        ? CompanionPose.walkFrames(widget.profile.faceShapeIndex)
        : null;
    final Widget body = walkFrames != null
        ? Image.asset(
            walkFrames[widget.stepPhase < 0.5 ? 0 : 1],
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          )
        : poseAsset != null
        ? Image.asset(
            poseAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          )
        : AvatarPreview(profile: widget.profile, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, child) {
          final (dx, dy, scaleY) = _motion(_loop.value);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.translationValues(dx, dy, 0)
                  ..scaleByDouble(widget.facingLeft ? -1 : 1, scaleY, 1, 1),
                child: child,
              ),
              if (widget.pose != CompanionPose.idle &&
                  widget.pose != CompanionPose.walk)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _PoseEffect(
                      key: Key('pose-effect-${widget.pose.name}'),
                      pose: widget.pose,
                      t: _loop.value,
                    ),
                  ),
                ),
            ],
          );
        },
        child: body,
      ),
    );
  }
}

/// Small code-drawn effect that makes the activity readable at a glance.
class _PoseEffect extends StatelessWidget {
  const _PoseEffect({super.key, required this.pose, required this.t});

  final CompanionPose pose;
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        Widget glyph(String text, Color color, double size) => Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const [
              Shadow(color: Colors.black54, offset: Offset(1, 1)),
            ],
          ),
        );
        switch (pose) {
          case CompanionPose.sleep:
            return Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: w * (0.66 + 0.07 * i),
                    top: h * (0.22 - 0.07 * i) - 10 * ((t + i / 3) % 1),
                    child: Opacity(
                      opacity: 1 - ((t + i / 3) % 1) * 0.8,
                      child: glyph(
                        'Z',
                        const Color(0xFFCDB8FF),
                        w * (0.09 + 0.02 * i),
                      ),
                    ),
                  ),
              ],
            );
          case CompanionPose.read:
            return Positioned(
              left: w * 0.62,
              top: h * 0.42,
              child: Opacity(
                opacity: 0.4 + 0.6 * ((math.sin(t * 2 * math.pi) + 1) / 2),
                child: glyph('✦', const Color(0xFFFFE07A), w * 0.08),
              ),
            ).wrapInStack();
          case CompanionPose.exercise:
            return Positioned(
              left: w * 0.68,
              top: h * 0.2 + 8 * t,
              child: Opacity(
                opacity: 1 - t,
                child: glyph('💧', const Color(0xFF8FD3FF), w * 0.08),
              ),
            ).wrapInStack();
          case CompanionPose.cheer:
            return Stack(
              children: [
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: w * (0.15 + 0.22 * i),
                    top: h * (0.1 + 0.05 * (i % 2)) - 12 * t,
                    child: Opacity(
                      opacity: 1 - t * 0.7,
                      child: glyph('★', const Color(0xFFFFCF5A), w * 0.09),
                    ),
                  ),
              ],
            );
          case CompanionPose.idle:
          case CompanionPose.walk:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

extension on Positioned {
  Widget wrapInStack() => Stack(children: [this]);
}
