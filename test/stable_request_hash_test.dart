import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/stable_request_hash.dart';

void main() {
  test('stable request hash preserves legacy FNV-1a output', () {
    expect(stableRequestHash('Nudge'), '2fb30900ca892138');
    expect(stableRequestHash('{"stage":1}'), '71300848e1ad76ac');
    expect(stableRequestHash('角色🌱'), '5f9fa563a56c61be');
  });

  test('stable request hash changes with the canonical payload', () {
    expect(
      stableRequestHash('{"stage":1}'),
      isNot(stableRequestHash('{"stage":2}')),
    );
  });
}
