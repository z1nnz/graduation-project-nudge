import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/immersive_cabin.dart';

const _aspect = 0.5629;

void main() {
  test('a 9:16 screen is filled exactly', () {
    final box = cabinBoxFor(const Size(360, 360 / _aspect), _aspect);
    expect(box.left, closeTo(0, 1e-9));
    expect(box.top, closeTo(0, 1e-9));
    expect(box.width, closeTo(360, 1e-9));
  });

  test('a slightly taller phone is covered completely', () {
    const screen = Size(400, 750);
    final box = cabinBoxFor(screen, _aspect);
    expect(box.top, lessThanOrEqualTo(0));
    expect(box.bottom, greaterThanOrEqualTo(750));
    expect(box.left, lessThan(0));
  });

  test('tall phones crop at most 3% per side so the side doors stay', () {
    const screen = Size(412, 915);
    final box = cabinBoxFor(screen, _aspect);
    expect(-box.left / box.width, closeTo(0.03, 1e-9));
    expect(box.width, closeTo(412 / 0.94, 1e-9));
    expect(box.top, greaterThan(0));
    expect(box.center.dy, closeTo(915 / 2, 1e-9));
    // Remaining strips are far smaller than the old letterbox.
    expect(box.top, lessThan((915 - 412 / _aspect) / 2));
  });

  test('wide screens keep the whole room by height', () {
    const screen = Size(1000, 800);
    final box = cabinBoxFor(screen, _aspect);
    expect(box.height, 800);
    expect(box.left, greaterThan(0));
  });
}
