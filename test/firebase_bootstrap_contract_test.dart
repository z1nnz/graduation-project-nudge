import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app bootstrap always supplies generated Firebase options', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("import 'firebase_options.dart';"));
    expect(
      source,
      contains(
        'Firebase.initializeApp(\n'
        '      options: DefaultFirebaseOptions.currentPlatform,\n'
        '    )',
      ),
    );
    expect(
      source.indexOf('Firebase.initializeApp('),
      lessThan(source.indexOf('FirebaseAppCheckService.activate()')),
    );
  });
}
