import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/utils/client_ids.dart';

void main() {
  test('client ids stay unique within one clock tick and match Cloud', () {
    final at = DateTime.utc(2026, 11, 23, 2);
    final ids = List<String>.generate(
      1000,
      (_) => newClientId('privacy', at: at),
    );

    expect(ids.toSet(), hasLength(ids.length));
    final cloudRequestPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
    for (final id in ids) {
      expect(id, matches(cloudRequestPattern));
      expect(id, startsWith('privacy_${at.microsecondsSinceEpoch}_'));
    }
  });
}
