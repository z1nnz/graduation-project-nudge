import 'avatar_catalog.dart';

enum CelebrationKind { levelUp, evolution }

/// A moment worth a full-screen show: the companion reached a new level or
/// evolved to the next stage of its series. Both only change through
/// Cloud-confirmed experience, so the show follows real progress.
class CompanionCelebration {
  const CompanionCelebration(this.kind, this.title, this.detail);

  final CelebrationKind kind;
  final String title;
  final String detail;

  /// What changed between two states, if anything. Evolution wins over a
  /// level-up that happens at the same time.
  static CompanionCelebration? between({
    required int oldLevel,
    required int newLevel,
    required int oldStageIndex,
    required int newStageIndex,
  }) {
    if (oldStageIndex != newStageIndex) {
      AvatarEvolutionStage? find(int index) {
        for (final s in AvatarCatalog.evolutionStages) {
          if (s.index == index) return s;
        }
        return null;
      }

      final before = find(oldStageIndex), after = find(newStageIndex);
      if (before != null &&
          after != null &&
          before.series == after.series &&
          after.stage > before.stage) {
        return CompanionCelebration(
          CelebrationKind.evolution,
          '進化！',
          after.name,
        );
      }
    }
    if (newLevel > oldLevel) {
      return CompanionCelebration(
        CelebrationKind.levelUp,
        '升級！',
        'Lv $newLevel',
      );
    }
    return null;
  }
}
