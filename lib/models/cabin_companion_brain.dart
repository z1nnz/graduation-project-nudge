import 'dart:math';
import 'dart:ui';

import 'companion_pose.dart';

/// What the companion is doing in the cabin, driven by the user's real state.
enum CompanionActivity { wander, focus, rest }

/// Moves the companion around the cabin floor. Positions are 0-1 of the
/// cabin frame and mark where the feet touch the floor.
class CabinCompanionBrain {
  CabinCompanionBrain({Random? random, Offset start = rug})
    : _random = random ?? Random(),
      _position = start;

  static const floor = Rect.fromLTRB(0.12, 0.6, 0.88, 0.86);
  static const desk = Offset(0.62, 0.61);
  static const rug = Offset(0.5, 0.72);
  static const _wanderSpots = [
    Offset(0.5, 0.62), // window
    Offset(0.27, 0.64), // bookshelf
    Offset(0.5, 0.74), // rug
    Offset(0.7, 0.66), // desk side
    Offset(0.3, 0.78),
    Offset(0.72, 0.8),
  ];

  /// Top walking speed in floor widths per second, with easing in and out.
  static const speed = 0.18;
  static const _accel = 0.9;
  static const _glanceEvery = 1.4;
  static const _cheerSeconds = 1.2;

  final Random _random;
  Offset _position;
  Offset? _target;
  CompanionActivity _activity = CompanionActivity.wander;
  double _restTimer = 2;
  double _cheerTimer = 0;
  double _stepClock = 0;
  double _speed = 0;
  double _glanceTimer = _glanceEvery;
  bool _facingLeft = false;

  Offset get position => _position;
  bool get facingLeft => _facingLeft;
  CompanionActivity get activity => _activity;

  /// 0..1 phase of the walk cycle, for alternating step frames.
  double get stepPhase => (_stepClock * 2.2) % 1;

  CompanionPose get pose {
    if (_cheerTimer > 0) return CompanionPose.cheer;
    if (_target != null) return CompanionPose.walk;
    switch (_activity) {
      case CompanionActivity.focus:
        return (_position - desk).distance < 0.02
            ? CompanionPose.read
            : CompanionPose.idle;
      case CompanionActivity.rest:
        return (_position - rug).distance < 0.02
            ? CompanionPose.sleep
            : CompanionPose.idle;
      case CompanionActivity.wander:
        return CompanionPose.idle;
    }
  }

  static Offset _clamp(Offset p) => Offset(
    p.dx.clamp(floor.left, floor.right),
    p.dy.clamp(floor.top, floor.bottom),
  );

  void setActivity(CompanionActivity activity) {
    if (activity == _activity) return;
    _activity = activity;
    switch (activity) {
      case CompanionActivity.focus:
        _target = desk;
      case CompanionActivity.rest:
        _target = rug;
      case CompanionActivity.wander:
        _target = null;
        _restTimer = 1.5;
    }
  }

  /// Walk to a tapped spot. Busy companions (focusing or resting) stay put.
  bool walkTo(Offset point) {
    if (_activity != CompanionActivity.wander) return false;
    _target = _clamp(point);
    return true;
  }

  void poke() => _cheerTimer = _cheerSeconds;

  void tick(double dt) {
    if (_cheerTimer > 0) {
      _cheerTimer = max(0, _cheerTimer - dt);
      return;
    }
    final target = _target;
    if (target != null) {
      final delta = target - _position;
      final distance = delta.distance;
      // Ease in (accelerate) and ease out (brake so we stop on the spot).
      final brake = sqrt(2 * _accel * distance);
      _speed = min(min(speed, _speed + _accel * dt), max(brake, 0.02));
      final step = _speed * dt;
      if (distance <= max(step, 0.002)) {
        _position = target;
        _target = null;
        _speed = 0;
        _restTimer = 3 + _random.nextDouble() * 5;
        _glanceTimer = _glanceEvery;
      } else {
        _position += delta / distance * step;
        if (delta.dx.abs() > 0.002) _facingLeft = delta.dx < 0;
        _stepClock += dt * (_speed / speed);
      }
      return;
    }
    if (_activity != CompanionActivity.wander) return;
    _glanceTimer -= dt;
    if (_glanceTimer <= 0) {
      _facingLeft = !_facingLeft; // look around while waiting
      _glanceTimer = _glanceEvery + _random.nextDouble();
    }
    _restTimer -= dt;
    if (_restTimer <= 0) {
      final options = _wanderSpots
          .where((s) => (s - _position).distance > 0.08)
          .toList();
      _target = options[_random.nextInt(options.length)];
    }
  }
}
