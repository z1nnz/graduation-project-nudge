import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/theme/app_text_scale.dart';

void main() {
  test('small phones no longer shrink text below normal size', () {
    expect(appTextScale(width: 375, height: 667, system: 1.0), 1.0);
  });

  test('typical phones read a little larger than before', () {
    expect(appTextScale(width: 412, height: 915, system: 1.0), 1.04);
    expect(appTextScale(width: 430, height: 932, system: 1.0), 1.04);
  });

  test('large screens get the full gentle bump', () {
    expect(appTextScale(width: 800, height: 1200, system: 1.0), 1.08);
  });

  test('system font size still counts but stays within layout limits', () {
    expect(
      appTextScale(width: 412, height: 915, system: 2.0),
      closeTo(1.04 * 1.15, 1e-9),
    );
    expect(
      appTextScale(width: 412, height: 915, system: 0.5),
      closeTo(1.04 * 0.85, 1e-9),
    );
  });
}
