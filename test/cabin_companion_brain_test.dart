import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/cabin_companion_brain.dart';
import 'package:nudge/models/companion_pose.dart';

CabinCompanionBrain _brain() =>
    CabinCompanionBrain(random: Random(7), start: const Offset(0.5, 0.7));

void _run(CabinCompanionBrain b, double seconds) {
  for (var t = 0.0; t < seconds; t += 0.05) {
    b.tick(0.05);
  }
}

void main() {
  test('walks to a tapped floor spot, facing the way it goes', () {
    final b = _brain();
    expect(b.walkTo(const Offset(0.2, 0.75)), isTrue);
    b.tick(0.1);
    expect(b.pose, CompanionPose.walk);
    expect(b.facingLeft, isTrue);
    _run(b, 2.2); // 0.3 floor widths at 0.16/s, then a short pause
    expect((b.position - const Offset(0.2, 0.75)).distance, lessThan(0.01));
    expect(b.pose, CompanionPose.idle);
  });

  test('taps outside the floor are clamped onto it', () {
    final b = _brain();
    b.walkTo(const Offset(0.5, 0.1));
    _run(b, 8);
    expect(b.position.dy, greaterThanOrEqualTo(CabinCompanionBrain.floor.top));
  });

  test('focus sends it to the desk to read and ignores floor taps', () {
    final b = _brain();
    b.setActivity(CompanionActivity.focus);
    expect(b.walkTo(const Offset(0.2, 0.8)), isFalse);
    _run(b, 8);
    expect((b.position - CabinCompanionBrain.desk).distance, lessThan(0.01));
    expect(b.pose, CompanionPose.read);
  });

  test('rest walks to the rug and sleeps', () {
    final b = _brain();
    b.setActivity(CompanionActivity.rest);
    _run(b, 8);
    expect((b.position - CabinCompanionBrain.rug).distance, lessThan(0.01));
    expect(b.pose, CompanionPose.sleep);
  });

  test('idle wanders to another spot after a pause', () {
    final b = _brain();
    final start = b.position;
    var farthest = 0.0;
    for (var t = 0.0; t < 20; t += 0.05) {
      b.tick(0.05);
      farthest = max(farthest, (b.position - start).distance);
    }
    expect(farthest, greaterThan(0.05));
  });

  test('a poke cheers briefly and then returns to its activity', () {
    final b = _brain();
    b.setActivity(CompanionActivity.focus);
    _run(b, 8);
    b.poke();
    expect(b.pose, CompanionPose.cheer);
    _run(b, 2);
    expect(b.pose, CompanionPose.read);
  });
}
