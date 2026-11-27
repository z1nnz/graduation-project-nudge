import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the friend page is a cabin the companion can walk around', () {
    final page = File(
      'lib/screens/friend_public_profile_page.dart',
    ).readAsStringSync();
    expect(page, contains('LivingSceneBanner('));
    expect(page, contains("'assets/scenes/friend_cabin.webp'"));
    expect(page, isNot(contains('SocialPlazaStage(')));
    final art = File('assets/scenes/friend_cabin.webp');
    expect(art.existsSync(), isTrue);
    expect(art.lengthSync(), lessThanOrEqualTo(300 * 1024));
  });
}