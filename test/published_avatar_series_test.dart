import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_catalog.dart';

void main() {
  tearDown(() {
    AvatarCatalog.replacePublishedSeries(const []);
  });

  test(
    'published shop document becomes a complete catalog evolution chain',
    () {
      final series = PublishedAvatarSeries.tryParseShopDocument(
        documentId: 'night-shadow-release',
        fallbackIndex: 18,
        data: {
          'type': 'event_character',
          'status': 'published',
          'series_key': 'night-shadow',
          'series_name': '夜影學院',
          'series_theme': '深度專注',
          'codex_description': '在安靜專注中逐步成長的夜影角色。',
          'price': 120,
          'character_stages': [
            {
              'stage': 1,
              'catalog_index': 18,
              'name': '夜影見習生',
              'required_level': 1,
              'required_experience': 0,
              'description': '系列起點。',
              'character_asset': 'https://cdn.example.com/night-1.png',
              'icon_asset': 'https://cdn.example.com/night-1-icon.png',
              'coin_price': 120,
              'shop_eligible': true,
              'evolves_from_stage': null,
            },
            {
              'stage': 2,
              'catalog_index': 19,
              'name': '夜輪行者',
              'required_level': 30,
              'required_experience': 10000,
              'description': '第二階段。',
              'character_asset': 'https://cdn.example.com/night-2.png',
              'icon_asset': 'https://cdn.example.com/night-2-icon.png',
              'coin_price': 999,
              'shop_eligible': true,
              'evolves_from_stage': 1,
            },
            {
              'stage': 3,
              'catalog_index': 20,
              'name': '夜曜守護者',
              'required_level': 60,
              'required_experience': 30000,
              'description': '最終階段。',
              'character_asset': 'https://cdn.example.com/night-3.png',
              'icon_asset': 'https://cdn.example.com/night-3-icon.png',
              'coin_price': 999,
              'shop_eligible': true,
              'evolves_from_stage': 2,
            },
          ],
        },
      );

      expect(series, isNotNull);
      expect(series!.key, 'night-shadow');
      expect(series.name, '夜影學院');
      expect(series.theme, '深度專注');
      expect(series.codexDescription, '在安靜專注中逐步成長的夜影角色。');
      expect(series.stages.map((stage) => stage.stage), [1, 2, 3]);
      expect(series.shopStages.map((stage) => stage.stage), [1]);
      expect(series.stages.map((stage) => stage.coinPrice), [120, 0, 0]);
      expect(series.stages.map((stage) => stage.evolvesFromStage), [
        null,
        1,
        2,
      ]);
    },
  );

  test('draft or incomplete character series never enters the app catalog', () {
    final draft = PublishedAvatarSeries.tryParseShopDocument(
      documentId: 'draft',
      fallbackIndex: 18,
      data: {
        'type': 'event_character',
        'status': 'draft',
        'series_name': '未發布角色',
        'character_stages': const [],
      },
    );
    final incomplete = PublishedAvatarSeries.tryParseShopDocument(
      documentId: 'incomplete',
      fallbackIndex: 18,
      data: {
        'type': 'event_character',
        'status': 'published',
        'series_name': '缺少最終型',
        'character_stages': [
          {
            'stage': 1,
            'name': '初始型',
            'character_asset': 'https://cdn.example.com/one.png',
            'icon_asset': 'https://cdn.example.com/one-icon.png',
          },
          {
            'stage': 2,
            'name': '進化型',
            'character_asset': 'https://cdn.example.com/two.png',
            'icon_asset': 'https://cdn.example.com/two-icon.png',
          },
        ],
      },
    );

    expect(draft, isNull);
    expect(incomplete, isNull);
  });

  test('non-increasing evolution requirements are rejected by the app', () {
    final invalid = PublishedAvatarSeries.tryParseShopDocument(
      documentId: 'invalid-requirements',
      fallbackIndex: 18,
      data: {
        'type': 'avatar_series',
        'status': 'published',
        'series_name': '錯誤進化鏈',
        'codex_description': '錯誤的門檻。',
        'character_stages': List.generate(3, (index) {
          final stage = index + 1;
          return {
            'stage': stage,
            'catalog_index': 18 + index,
            'name': '第 $stage 階',
            'required_level': 1,
            'required_experience': 0,
            'description': '第 $stage 階描述',
            'character_asset': 'https://cdn.example.com/$stage.png',
            'icon_asset': 'https://cdn.example.com/$stage-icon.png',
            'evolves_from_stage': stage == 1 ? null : stage - 1,
          };
        }),
      },
    );

    expect(invalid, isNull);
  });

  test('catalog shop policy exposes starter stages only', () {
    final series = PublishedAvatarSeries.tryParseShopDocument(
      documentId: 'shop-policy',
      fallbackIndex: 18,
      data: {
        'type': 'event_character',
        'status': 'published',
        'series_name': '商城測試角色',
        'codex_description': '商城測試角色的圖鑑介紹。',
        'price': 90,
        'character_stages': List.generate(3, (index) {
          final stage = index + 1;
          return {
            'stage': stage,
            'catalog_index': 18 + index,
            'name': '第 $stage 階',
            'required_level': stage == 1 ? 1 : stage * 30,
            'required_experience': (stage - 1) * 10000,
            'description': '第 $stage 階描述',
            'character_asset': 'https://cdn.example.com/$stage.png',
            'icon_asset': 'https://cdn.example.com/$stage-icon.png',
            'evolves_from_stage': stage == 1 ? null : stage - 1,
          };
        }),
      },
    );

    AvatarCatalog.replacePublishedSeries([series!]);

    final dynamicShopStages = AvatarCatalog.shopStages
        .where((stage) => stage.index >= 18)
        .toList();
    expect(dynamicShopStages.map((stage) => stage.stage), [1]);
    expect(
      AvatarCatalog.evolutionStages
          .where((stage) => stage.index >= 18)
          .map((stage) => stage.stage),
      [1, 2, 3],
    );
  });

  test('catalog rejects dynamic index collisions across published series', () {
    PublishedAvatarSeries makeSeries(String id, String name) {
      return PublishedAvatarSeries.tryParseShopDocument(
        documentId: id,
        fallbackIndex: 18,
        data: {
          'type': 'avatar_series',
          'status': 'published',
          'series_name': name,
          'codex_description': '$name 的圖鑑介紹。',
          'character_stages': List.generate(3, (index) {
            final stage = index + 1;
            return {
              'stage': stage,
              'catalog_index': 18 + index,
              'name': '$name $stage',
              'required_level': stage == 1 ? 1 : stage * 30,
              'required_experience': (stage - 1) * 10000,
              'description': '$name 第 $stage 階描述',
              'character_asset': 'https://cdn.example.com/$id-$stage.png',
              'icon_asset': 'https://cdn.example.com/$id-$stage-icon.png',
              'evolves_from_stage': stage == 1 ? null : stage - 1,
            };
          }),
        },
      )!;
    }

    AvatarCatalog.replacePublishedSeries([
      makeSeries('first', '第一系列'),
      makeSeries('second', '碰撞系列'),
    ]);

    expect(
      AvatarCatalog.series
          .where((series) => series.stages.any((stage) => stage.index >= 18))
          .map((series) => series.name),
      ['第一系列'],
    );
  });
}
