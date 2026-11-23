import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Page route used when leaving the cabin through an object or a door: the
/// next screen opens as a growing circle, like stepping through a doorway.
/// Respects reduced motion (no transition).
class CabinRoute<T> extends PageRouteBuilder<T> {
  CabinRoute({required WidgetBuilder builder, this.origin = Alignment.center})
    : super(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) => ClipPath(
              clipper: _IrisClipper(curved.value, origin),
              child: child,
            ),
          );
        },
      );

  /// Where the circle grows from.
  final Alignment origin;
}

class _IrisClipper extends CustomClipper<Path> {
  _IrisClipper(this.t, this.origin);

  final double t;
  final Alignment origin;

  @override
  Path getClip(Size size) {
    final center = origin.alongSize(size);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - center).distance).reduce(math.max);
    return Path()..addOval(Rect.fromCircle(center: center, radius: far * t));
  }

  @override
  bool shouldReclip(_IrisClipper old) => old.t != t || old.origin != origin;
}
