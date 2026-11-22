import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_catalog.dart';

Map<String, dynamic> fixture() => {
  'type': 'avatar_series',
  'status': 'published',
  'series_key': 'strict-series',
  'series_name': '正式角色',
  'codex_description': '完整三階圖鑑',
  'price': 10,
  'character_stages': List.generate(
    3,
    (i) => <String, dynamic>{
      'stage': i + 1,
      'catalog_index': 18 + i,
      'name': '角色 $i',
      'description': '介紹 $i',
      'character_asset': 'https://example.com/$i.png',
      'icon_asset': 'https://example.com/icon-$i.png',
      'required_level': i == 0 ? 1 : i * 30,
      'required_experience': i * 10000,
      'coin_price': i == 0 ? 10 : 0,
      'evolves_from_stage': i == 0 ? null : i,
    },
  ),
};

PublishedAvatarSeries? parse(Map<String, dynamic> data) =>
    PublishedAvatarSeries.tryParseShopDocument(
      documentId: 'strict-document',
      data: data,
    );

void main() {
  test('published identity requires explicit integral Cloud indexes', () {
    expect(parse(fixture()), isNotNull);
    for (final invalid in [
      null,
      18.5,
      -1,
      0,
      double.nan,
      double.infinity,
      '18',
    ]) {
      final data = fixture();
      (data['character_stages'] as List).first['catalog_index'] = invalid;
      expect(parse(data), isNull, reason: 'index $invalid');
    }
  });
  test('published requirements and price never truncate invalid numbers', () {
    for (final field in [
      'stage',
      'required_level',
      'required_experience',
      'coin_price',
    ]) {
      final data = fixture();
      (data['character_stages'] as List)[1][field] = 1.5;
      expect(parse(data), isNull, reason: field);
    }
    final data = fixture()..['price'] = -1;
    expect(parse(data), isNull);
  });
  test('published stages preserve ordered contiguous Cloud identity', () {
    final data = fixture();
    (data['character_stages'] as List)[2]['catalog_index'] = 99;
    expect(parse(data), isNull);
  });
}
