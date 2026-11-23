import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_catalog.dart';
import 'package:nudge/models/companion_celebration.dart';

void main() {
  final stages = AvatarCatalog.evolutionStages;
  final first = stages.firstWhere((s) => s.stage == 1);
  final second = stages.firstWhere(
    (s) => s.series == first.series && s.stage == 2,
  );
  final otherSeries = stages.firstWhere(
    (s) => s.series != first.series && s.stage == 2,
  );

  test('nothing to celebrate when nothing grew', () {
    expect(
      CompanionCelebration.between(
        oldLevel: 7,
        newLevel: 7,
        oldStageIndex: first.index,
        newStageIndex: first.index,
      ),
      isNull,
    );
    // Levels never celebrate going down (e.g. switching accounts).
    expect(
      CompanionCelebration.between(
        oldLevel: 9,
        newLevel: 3,
        oldStageIndex: first.index,
        newStageIndex: first.index,
      ),
      isNull,
    );
  });

  test('a higher level is a level-up', () {
    final c = CompanionCelebration.between(
      oldLevel: 7,
      newLevel: 8,
      oldStageIndex: first.index,
      newStageIndex: first.index,
    )!;
    expect(c.kind, CelebrationKind.levelUp);
    expect(c.title, '升級！');
    expect(c.detail, 'Lv 8');
  });

  test('the next stage of the same series is an evolution', () {
    final c = CompanionCelebration.between(
      oldLevel: 9,
      newLevel: 10,
      oldStageIndex: first.index,
      newStageIndex: second.index,
    )!;
    expect(c.kind, CelebrationKind.evolution);
    expect(c.title, '進化！');
    expect(c.detail, second.name);
  });

  test('changing to another series is not an evolution', () {
    expect(
      CompanionCelebration.between(
        oldLevel: 5,
        newLevel: 5,
        oldStageIndex: first.index,
        newStageIndex: otherSeries.index,
      ),
      isNull,
    );
  });
}
