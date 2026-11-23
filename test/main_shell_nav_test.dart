import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/main.dart';

void main() {
  test('bottom navigation follows the game world sections', () {
    expect(
      MainShell.destinations.map((d) => d.label),
      ['小屋', '委託', '專注', '自律房', '同伴'],
    );
  });
}
