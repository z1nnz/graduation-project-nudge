import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_catalog.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

PublishedAvatarSeries _series({
  required String documentId,
  required String key,
  required String name,
  required int baseIndex,
}) {
  return PublishedAvatarSeries.tryParseShopDocument(
    documentId: documentId,
    data: {
      'type': 'avatar_series',
      'status': 'published',
      'series_key': key,
      'series_name': name,
      'codex_description': '$name 的完整角色圖鑑。',
      'price': 0,
      'character_stages': List.generate(3, (index) {
        final stage = index + 1;
        return {
          'stage': stage,
          'catalog_index': baseIndex + index,
          'name': '$name $stage',
          'required_level': stage == 1
              ? 1
              : stage == 2
              ? 30
              : 60,
          'required_experience': stage == 1
              ? 0
              : stage == 2
              ? 10000
              : 30000,
          'description': '$name 第 $stage 階描述',
          'character_asset': 'https://cdn.example.com/$key-$stage.png',
          'icon_asset': 'https://cdn.example.com/$key-$stage-icon.png',
          'evolves_from_stage': stage == 1 ? null : stage - 1,
        };
      }),
    },
  )!;
}

void main() {
  tearDown(() {
    AvatarCatalog.replacePublishedSeries(const []);
  });

  test(
    'dynamic series use stable keys so display names cannot merge or erase EXP',
    () async {
      final first = _series(
        documentId: 'series-one-document',
        key: 'series-one',
        name: '同名角色',
        baseIndex: 18,
      );
      final second = _series(
        documentId: 'series-two-document',
        key: 'series-two',
        name: '同名角色',
        baseIndex: 21,
      );
      AvatarCatalog.replacePublishedSeries([first, second]);
      SharedPreferences.setMockInitialValues({
        'avatar_experience_ledger_setting': jsonEncode({
          '2026-11-22': {'series-one': 10000},
        }),
      });

      final appState = AppState();
      await appState.loadAllLocalData();

      expect(AvatarCatalog.stageForIndex(19).progressKey, 'series-one');
      expect(AvatarCatalog.stageForIndex(22).progressKey, 'series-two');
      expect(appState.isAvatarEvolutionStageUnlocked(19), isTrue);
      expect(appState.isAvatarEvolutionStageUnlocked(22), isFalse);

      final renamed = _series(
        documentId: 'series-one-document',
        key: 'series-one',
        name: '重新命名角色',
        baseIndex: 18,
      );
      AvatarCatalog.replacePublishedSeries([renamed, second]);

      expect(AvatarCatalog.stageForIndex(19).series, '重新命名角色');
      expect(appState.isAvatarEvolutionStageUnlocked(19), isTrue);
    },
  );
}
