import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_catalog.dart';
import 'package:nudge/state/app_state.dart';
import 'package:nudge/theme/app_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'premium avatar series requires self-discipline coin purchase',
    () async {
      SharedPreferences.setMockInitialValues({'discipline_coins_setting': 240});

      final appState = AppState();
      await appState.loadAllLocalData();

      const moonStageIndex = 12;
      const forestStageIndex = 15;
      final moonStage = AvatarCatalog.stageForIndex(moonStageIndex);
      final forestStage = AvatarCatalog.stageForIndex(forestStageIndex);

      expect(moonStage.series, '月影忍者');
      expect(moonStage.coinPrice, 120);
      expect(forestStage.series, '森語女神');
      expect(forestStage.coinPrice, 120);
      expect(appState.isAvatarEvolutionStageUnlocked(0), isTrue);
      expect(appState.isAvatarEvolutionStageUnlocked(3), isTrue);
      expect(appState.isAvatarEvolutionStageUnlocked(6), isTrue);
      expect(appState.isAvatarEvolutionStageUnlocked(9), isTrue);
      expect({
        0,
        3,
        6,
        9,
      }, contains(appState.avatarVariantForSeed(14).faceShapeIndex));
      expect(appState.isAvatarEvolutionStageUnlocked(moonStageIndex), isFalse);
      expect(
        appState.isAvatarEvolutionStageUnlocked(forestStageIndex),
        isFalse,
      );
      expect(
        appState.avatarEvolutionRequirementText(moonStageIndex),
        '120 自律幣購買',
      );
      expect(
        appState.avatarEvolutionRequirementText(forestStageIndex),
        '120 自律幣購買',
      );

      final purchased = await appState.purchaseAvatarItem(
        'faceShape',
        moonStageIndex,
      );

      expect(purchased, isTrue);
      expect(appState.disciplineCoins, 120);
      expect(appState.isAvatarEvolutionStageUnlocked(moonStageIndex), isTrue);
      expect(appState.isAvatarEvolutionStageUnlocked(13), isFalse);
      expect(
        appState.avatarEvolutionRequirementText(13),
        'Lv.30 / 10000 EXP 解鎖',
      );

      final forestPurchased = await appState.purchaseAvatarItem(
        'faceShape',
        forestStageIndex,
      );

      expect(forestPurchased, isTrue);
      expect(appState.disciplineCoins, 0);
      expect(appState.isAvatarEvolutionStageUnlocked(forestStageIndex), isTrue);
    },
  );

  test(
    'background themes can be purchased and applied from shop state',
    () async {
      SharedPreferences.setMockInitialValues({'discipline_coins_setting': 45});

      final appState = AppState();
      await appState.loadAllLocalData();

      final sakuraIndex = AppUI.backgroundThemeKeys.indexOf('sakuraWalk');

      expect(appState.isAvatarItemUnlocked('appBackground', 0), isTrue);
      expect(
        appState.isAvatarItemUnlocked('appBackground', sakuraIndex),
        isFalse,
      );
      expect(appState.avatarItemPrice('appBackground', sakuraIndex), 45);

      await appState.setBackgroundThemeSetting('sakuraWalk');
      expect(appState.backgroundThemeSetting, 'softGlow');

      final purchased = await appState.purchaseAvatarItem(
        'appBackground',
        sakuraIndex,
      );

      expect(purchased, isTrue);
      expect(appState.disciplineCoins, 0);
      expect(
        appState.isAvatarItemUnlocked('appBackground', sakuraIndex),
        isTrue,
      );

      await appState.setBackgroundThemeSetting('sakuraWalk');
      expect(appState.backgroundThemeSetting, 'sakuraWalk');
    },
  );
}
