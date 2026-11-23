import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/cabin_tour_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the tour is shown until it has been finished once', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await CabinTourMemory.seen(), isFalse);
    await CabinTourMemory.markSeen();
    expect(await CabinTourMemory.seen(), isTrue);
  });
}
