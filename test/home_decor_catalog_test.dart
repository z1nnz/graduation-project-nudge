import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/home_decor_catalog.dart';

void main() {
  final catalog = HomeDecorCatalog.fromJson(
    jsonDecode(File('assets/home/home_decor_catalog.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('itemIndex maps slot order and variant', () {
    expect(catalog.itemIndex('rug', 0), 0);
    expect(catalog.itemIndex('curtain', 2), 102);
    expect(catalog.itemIndex('lamp', 1), 201);
    expect(catalog.variant('lamp', 9), isNull);
    expect(catalog.variant('curtain', 1)?.name, '星點紗簾');
  });
}
